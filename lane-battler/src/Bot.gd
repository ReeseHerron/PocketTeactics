# src/Bot.gd
class_name Bot
extends RefCounted

enum Difficulty { EASY, NORMAL, HARD }

var difficulty: Difficulty = Difficulty.NORMAL
var _prepared_bids: Dictionary = {}
var _prepared_action: Dictionary = {}

# --- Draft ---
func prepare_draft_bids_for_player(units: Array, player_id: int) -> void:
	_prepared_bids = {}
	var scored = []
	for i in range(units.size()):
		scored.append({ "index": i, "score": _score_draft_unit(units[i], player_id), "unit": units[i] })

	# Sort descending
	scored.sort_custom(func(a, b): return a.score > b.score)

	var budget = GameState.gold[player_id]
	var bids_placed = 0

	for entry in scored:
		if bids_placed >= 2:
			break
		var unit = entry.unit
		var min_bid = unit.floor_cost
		if budget < min_bid:
			continue
		# Difficulty adjusts overbid willingness
		var bid = _calculate_bid(entry.score, min_bid, budget)
		_prepared_bids[entry.index] = bid
		budget -= bid
		bids_placed += 1

func get_draft_bids() -> Dictionary:
	return _prepared_bids

func _score_draft_unit(unit: UnitData, player_id: int) -> float:
	var opponent_id = 1 - player_id
	var score = 0.0

	# Does this complete a fusion?
	for bench_unit in GameState.bench[player_id]:
		if bench_unit.data.display_name == unit.display_name:
			score += 10.0

	# Does this deny player's fusion?
	if difficulty != Difficulty.EASY:
		for bench_unit in GameState.bench[opponent_id]:
			if bench_unit.data.display_name == unit.display_name:
				score += 6.0

	# Does this counter the player's board?
	for lane in range(3):
		var opponent_unit = GameState.board[opponent_id][lane]
		if opponent_unit != null:
			if _has_advantage(unit.unit_type, opponent_unit.data.unit_type):
				score += 4.0

	# Center contest value
	if GameState.board[player_id][1] == null:
		score += 2.0

	# Noise for lower difficulties
	if difficulty == Difficulty.EASY:
		score += randf_range(-5.0, 5.0)
	elif difficulty == Difficulty.NORMAL:
		score += randf_range(-2.0, 2.0)

	return score

func _calculate_bid(score: float, min_bid: int, budget: int) -> int:
	var bid = min_bid

	if score >= 8.0 and budget >= min_bid + 2:
		bid = min_bid + 2
	elif score >= 4.0 and budget >= min_bid + 1:
		bid = min_bid + 1  # lowered threshold from 5.0 to 4.0
	
	# If sitting on large gold reserve, overbid more freely
	if budget >= 8 and bid == min_bid and score >= 3.0:
		bid = min_bid + 1

	# Hard difficulty overbids more aggressively
	if difficulty == Difficulty.HARD and score >= 5.0 and budget >= min_bid + 2:
		bid = min_bid + 2

	return min(bid, budget)

func _has_advantage(a: UnitData.UnitType, b: UnitData.UnitType) -> bool:
	return (
		(a == UnitData.UnitType.STRIKER and b == UnitData.UnitType.TACTICIAN) or
		(a == UnitData.UnitType.TACTICIAN   and b == UnitData.UnitType.BULWARK) or
		(a == UnitData.UnitType.BULWARK  and b == UnitData.UnitType.STRIKER)
	)

# --- Action ---
func prepare_action_for_player(player_id: int) -> void:
	_prepared_action = _choose_action_for(player_id)

func get_action() -> Dictionary:
	return _prepared_action

func _choose_action_for(player_id: int) -> Dictionary:
	var opponent_id = 1 - player_id
	var candidates = []

	candidates.append({ "type": 4, "score": 0.0 })

	for unit in GameState.bench[player_id]:
		for lane in range(3):
			if GameState.board[player_id][lane] == null:
				candidates.append({
					"type": 0,
					"unit": unit,
					"target_lane": lane,
					"score": _score_deploy_for(unit, lane, opponent_id)
				})

	for lane in range(3):
		var unit = GameState.board[player_id][lane]
		if unit != null:
			var score = _score_retreat(unit, lane)
			if score > 0:
				candidates.append({
					"type": 1,
					"unit": unit,
					"score": score
				})

	for lane in range(3):
		var unit = GameState.board[player_id][lane]
		if unit == null:
			continue
		for adj in [lane - 1, lane + 1]:
			if adj >= 0 and adj < 3 and GameState.board[player_id][adj] == null:
				candidates.append({
					"type": 2,
					"unit": unit,
					"target_lane": adj,
					"score": _score_shift_for(unit, lane, adj, opponent_id)
				})

	candidates.sort_custom(func(a, b): return a.score > b.score)
	return candidates[0]

func _score_deploy_for(unit: UnitInstance, lane: int, opponent_id: int) -> float:
	var score = 0.0
	var player_id = 1 - opponent_id

	if lane == 1:
		score += 5.0
		# Reduce center desire if opponent has advantage there
		var opponent_center = GameState.board[opponent_id][1]
		if opponent_center != null and _has_advantage(opponent_center.data.unit_type, unit.data.unit_type):
			score -= 3.0
	else:
		# Flank base value
		score += 2.0
		if GameState.gold[player_id] <= 2:
			score += 1.5
		if GameState.board[opponent_id][lane] == null:
			score += 1.0
		# Big bonus if we already hold the other flank — completing both = +1 VP
		var other_flank = 2 if lane == 0 else 0
		if GameState.board[player_id][other_flank] != null:
			score += 6.0  # completing double flank is worth more than center

	# Weapon advantage bonus in any lane
	var opponent = GameState.board[opponent_id][lane]
	if opponent != null and _has_advantage(unit.data.unit_type, opponent.data.unit_type):
		score += 3.0

	return score

func _score_retreat(unit: UnitInstance, _lane: int) -> float:
	# Retreat only worth it if significantly damaged
	var missing = unit.data.get_max_might() - unit.current_might
	if missing >= 1 and difficulty != Difficulty.EASY:
		return 3.0 * float(missing)
	return 0.0

func _score_shift_for(unit: UnitInstance, _from_lane: int, to_lane: int, opponent_id: int) -> float:
	var score = 0.0
	var player_id = 1 - opponent_id

	if to_lane == 1:
		score += 4.0
		var opponent_center = GameState.board[opponent_id][1]
		if opponent_center != null and _has_advantage(opponent_center.data.unit_type, unit.data.unit_type):
			score -= 3.0
	else:
		score += 1.5
		if GameState.gold[player_id] <= 2:
			score += 1.5
		if GameState.board[opponent_id][to_lane] == null:
			score += 1.0
		# Big bonus if we already hold the other flank — completing both = +1 VP
		var other_flank = 2 if to_lane == 0 else 0
		if GameState.board[player_id][other_flank] != null:
			score += 6.0  # completing double flank is worth more than center

	var opponent = GameState.board[opponent_id][to_lane]
	if opponent != null and _has_advantage(unit.data.unit_type, opponent.data.unit_type):
		score += 3.0

	return score
