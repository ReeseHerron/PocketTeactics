# src/Bot.gd
# AI opponent. Operates in two planning steps matching the v4 turn structure:
#   choose_maneuver()  — picks retreat, shift, muster, or skip
#   choose_deploy()    — picks a unit to deploy (or skip), given projected board
# Draft bidding is prepared separately before the bidding phase opens.
class_name Bot
extends RefCounted


enum Difficulty { EASY, NORMAL, HARD }

var difficulty: Difficulty = Difficulty.NORMAL

# Stored choices, retrieved by RoundManager after each step
var _prepared_bids:   Dictionary = {}
var _chosen_maneuver: Dictionary = {}
var _chosen_deploy:   Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# DRAFT
# ═══════════════════════════════════════════════════════════════════════════════

func prepare_draft_bids(units: Array, player_id: int) -> void:
	_prepared_bids = {}
	var scored := []

	for i in range(units.size()):
		scored.append({
			"index": i,
			"score": _score_draft_unit(units[i], player_id),
			"unit":  units[i],
		})

	scored.sort_custom(func(a, b): return a.score > b.score)

	var budget : int = GameState.gold[player_id]
	var bids_placed := 0

	for entry in scored:
		if bids_placed >= 2:
			break
		var unit: UnitData = entry.unit
		if budget < unit.floor_cost:
			continue
		var bid := _calculate_bid(entry.score, unit.floor_cost, budget)
		_prepared_bids[entry.index] = bid
		budget -= bid
		bids_placed += 1


func get_draft_bids() -> Dictionary:
	return _prepared_bids


func _score_draft_unit(unit: UnitData, player_id: int) -> float:
	var opponent_id := 1 - player_id
	var score := 0.0

	# Fusion completion: same fusion_group_id and same tier already on bench
	for bench_unit in GameState.bench[player_id]:
		if (bench_unit.data.fusion_group_id == unit.fusion_group_id
				and bench_unit.data.tier == unit.tier):
			score += 10.0

	# Denial: block opponent's fusion
	if difficulty != Difficulty.EASY:
		for bench_unit in GameState.bench[opponent_id]:
			if (bench_unit.data.fusion_group_id == unit.fusion_group_id
					and bench_unit.data.tier == unit.tier):
				score += 6.0

	# Counter: type advantage against something on the opponent's board
	for lane in range(3):
		var opp_unit: UnitInstance = GameState.board[opponent_id][lane]
		if opp_unit != null and _has_advantage(unit.unit_type, opp_unit.data.unit_type):
			score += 4.0

	# Center vacancy bonus
	if GameState.board[player_id][1] == null:
		score += 2.0

	return _add_noise_value(score)


func _calculate_bid(score: float, min_bid: int, budget: int) -> int:
	var bid := min_bid
	if score >= 8.0 and budget >= min_bid + 2:
		bid = min_bid + 2
	elif score >= 4.0 and budget >= min_bid + 1:
		bid = min_bid + 1
	if budget >= 8 and bid == min_bid and score >= 3.0:
		bid = min_bid + 1
	if difficulty == Difficulty.HARD and score >= 5.0 and budget >= min_bid + 2:
		bid = min_bid + 2
	return min(bid, budget)


# ═══════════════════════════════════════════════════════════════════════════════
# PLANNING — MANEUVER STEP
# ═══════════════════════════════════════════════════════════════════════════════

func choose_maneuver(player_id: int) -> Dictionary:
	var opponent_id := 1 - player_id
	var candidates: Array = []

	# SKIP is always the baseline
	candidates.append({ "type": ActionExecutor.ManeuverType.SKIP, "score": 0.0 })

	# RETREAT: consider each damaged board unit
	for lane in range(3):
		var unit: UnitInstance = GameState.board[player_id][lane]
		if unit == null:
			continue
		var score := _score_retreat(unit, lane, player_id)
		if score > 0.0:
			candidates.append({
				"type": ActionExecutor.ManeuverType.RETREAT,
				"unit": unit,
				"score": score,
			})

	# SHIFT: move a board unit to an adjacent empty lane
	for lane in range(3):
		var unit: UnitInstance = GameState.board[player_id][lane]
		if unit == null:
			continue
		for adj in [lane - 1, lane + 1]:
			if adj < 0 or adj >= 3:
				continue
			if GameState.board[player_id][adj] != null:
				continue
			candidates.append({
				"type":        ActionExecutor.ManeuverType.SHIFT,
				"unit":        unit,
				"target_lane": adj,
				"score":       _score_shift(unit, lane, adj, player_id, opponent_id),
			})

	# MUSTER: emergency deploy if no board units
	if not GameState.has_any_board_unit(player_id):
		for unit in GameState.bench[player_id]:
			for lane in range(3):
				candidates.append({
					"type":        ActionExecutor.ManeuverType.MUSTER,
					"unit":        unit,
					"target_lane": lane,
					"score":       _score_muster(unit, lane, player_id, opponent_id),
				})

	_add_noise(candidates)
	candidates.sort_custom(func(a, b): return a.score > b.score)
	_chosen_maneuver = candidates[0]
	return _chosen_maneuver


func get_maneuver() -> Dictionary:
	return _chosen_maneuver


func _score_retreat(unit: UnitInstance, lane: int, player_id: int) -> float:
	var missing := unit.data.get_max_might() - unit.current_might
	if missing <= 0:
		return 0.0  # Never retreat a full-health unit

	var score := float(missing) * 2.0

	# Heavy penalty for retreating from Center (gives opponent free VP next round)
	if lane == 1:
		score -= 4.0

	# Penalty if this is our only board unit (leaves us board-empty)
	var board_count := 0
	for l in range(3):
		if GameState.board[player_id][l] != null:
			board_count += 1
	if board_count <= 1:
		score -= 3.0

	return score


func _score_shift(unit: UnitInstance, from_lane: int, to_lane: int,
		player_id: int, opponent_id: int) -> float:
	var score := 0.0

	if to_lane == 1:  # Moving to Center
		score += 4.0
		var opp_center: UnitInstance = GameState.board[opponent_id][1]
		if opp_center != null and _has_advantage(opp_center.data.unit_type, unit.data.unit_type):
			score -= 3.0  # Walking into a losing matchup
	else:  # Moving to a flank
		score += 1.5
		if GameState.board[opponent_id][to_lane] == null:
			score += 1.0  # Open lane
		# Big bonus if we'd complete both flanks
		var other_flank := 2 if to_lane == 0 else 0
		if GameState.board[player_id][other_flank] != null:
			score += 5.0

	# Matchup advantage at destination
	var opp_at_dest: UnitInstance = GameState.board[opponent_id][to_lane]
	if opp_at_dest != null and _has_advantage(unit.data.unit_type, opp_at_dest.data.unit_type):
		score += 3.0

	return score


func _score_muster(unit: UnitInstance, lane: int, _player_id: int, _opponent_id: int) -> float:
	# Any board presence is better than nothing; Center is most valuable
	return 5.0 if lane == 1 else 2.0


# ═══════════════════════════════════════════════════════════════════════════════
# PLANNING — DEPLOY STEP
# ═══════════════════════════════════════════════════════════════════════════════

func choose_deploy(player_id: int, projected_board: Array) -> Dictionary:
	var opponent_id := 1 - player_id
	var candidates: Array = []

	# SKIP is always an option
	candidates.append({ "type": ActionExecutor.DeployType.SKIP, "score": 0.0 })

	# Build available bench — exclude any unit already committed to Muster this turn.
	# Without this, the bot could plan Muster(unitA) + Deploy(unitA), which
	# resolves as Muster then silently fails the deploy.
	var available_bench: Array = GameState.bench[player_id].duplicate()
	if _chosen_maneuver.get("type") == ActionExecutor.ManeuverType.MUSTER:
		var mustered: UnitInstance = _chosen_maneuver.get("unit")
		if mustered != null:
			available_bench.erase(mustered)

	# DEPLOY: each available bench unit into each empty lane on the projected board
	for unit in available_bench:
		for lane in range(3):
			if projected_board[player_id][lane] != null:
				continue  # lane occupied after our maneuver
			candidates.append({
				"type":        ActionExecutor.DeployType.DEPLOY,
				"unit":        unit,
				"target_lane": lane,
				"score":       _score_deploy(unit, lane, player_id, opponent_id, projected_board),
			})

	_add_noise(candidates)
	candidates.sort_custom(func(a, b): return a.score > b.score)
	_chosen_deploy = candidates[0]
	return _chosen_deploy


func get_deploy() -> Dictionary:
	return _chosen_deploy


func _score_deploy(unit: UnitInstance, lane: int,
		player_id: int, opponent_id: int, projected_board: Array) -> float:
	var score := 0.0

	if lane == 1:  # Center
		score += 5.0
		var opp_center: UnitInstance = projected_board[opponent_id][1]
		if opp_center != null and _has_advantage(opp_center.data.unit_type, unit.data.unit_type):
			score -= 3.0
	else:  # Flank
		score += 2.0
		if GameState.gold[player_id] <= 2:
			score += 1.5  # Economy pressure: flank gold helps
		if projected_board[opponent_id][lane] == null:
			score += 1.0  # Uncontested flank
		# Both-flanks bonus
		var other_flank := 2 if lane == 0 else 0
		if projected_board[player_id][other_flank] != null:
			score += 6.0

	# Matchup advantage at target lane
	var opp_at_dest: UnitInstance = projected_board[opponent_id][lane]
	if opp_at_dest != null and _has_advantage(unit.data.unit_type, opp_at_dest.data.unit_type):
		score += 3.0

	return score


# ═══════════════════════════════════════════════════════════════════════════════
# SHARED HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _has_advantage(a: UnitData.UnitType, b: UnitData.UnitType) -> bool:
	return (
		(a == UnitData.UnitType.STRIKER   and b == UnitData.UnitType.TACTICIAN) or
		(a == UnitData.UnitType.TACTICIAN and b == UnitData.UnitType.BULWARK)   or
		(a == UnitData.UnitType.BULWARK   and b == UnitData.UnitType.STRIKER)
	)


func _add_noise(candidates: Array) -> void:
	for c in candidates:
		match difficulty:
			Difficulty.EASY:   c["score"] += randf_range(-5.0, 5.0)
			Difficulty.NORMAL: c["score"] += randf_range(-2.0, 2.0)
			# HARD: no noise — always picks the highest-scored option


func _add_noise_value(score: float) -> float:
	match difficulty:
		Difficulty.EASY:   return score + randf_range(-5.0, 5.0)
		Difficulty.NORMAL: return score + randf_range(-2.0, 2.0)
	return score
