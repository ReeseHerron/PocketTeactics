# src/RoundManager.gd
extends Node

enum Phase {
	DRAFT_REVEAL,
	DRAFT_BIDDING,
	DRAFT_RESOLVE,
	FUSION,
	ACTION_COMMIT,
	ACTION_RESOLVE,
	LANE_RESOLUTION,
	INCOME,
	VICTORY_CHECK,
	MATCH_OVER
}

var current_phase: Phase = Phase.DRAFT_REVEAL
var draft_pool: DraftPool
var fusion_checker: FusionChecker
var combat_resolver: CombatResolver
var action_executor: ActionExecutor
var economy_manager: EconomyManager
var bot: Bot
var extort_queue: Array[int] = []
const MAX_TEST_ROUNDS := 30

var _lane_results: Array = []

signal phase_changed(new_phase: Phase)
signal waiting_for_player(phase: Phase)
@warning_ignore("unused_signal")
signal round_log_entry(entry: Dictionary)

func _ready() -> void:
	print("RoundManager ready")
	draft_pool = DraftPool.new()
	fusion_checker = FusionChecker.new()
	combat_resolver = CombatResolver.new()
	action_executor = ActionExecutor.new()
	economy_manager = EconomyManager.new()
	bot = Bot.new()

func start_match(roster_a: Array, roster_b: Array) -> void:
	extort_queue.clear()
	draft_pool.build_pool(roster_a, roster_b)
	call_deferred("advance")

func advance() -> void:
	match current_phase:
		Phase.DRAFT_REVEAL:    _do_draft_reveal()
		Phase.DRAFT_BIDDING:   _do_draft_bidding()
		Phase.DRAFT_RESOLVE:   _do_draft_resolve()
		Phase.FUSION:          _do_fusion()
		Phase.ACTION_COMMIT:   _do_action_commit()
		Phase.ACTION_RESOLVE:  _do_action_resolve()
		Phase.LANE_RESOLUTION: _do_lane_resolution()
		Phase.INCOME:          _do_income()
		Phase.VICTORY_CHECK:   _do_victory_check()

func _set_phase(p: Phase) -> void:
	if GameState.round_number >= MAX_TEST_ROUNDS:
		push_error("Emergency stop: exceeded %d rounds. Possible stalled match loop." % MAX_TEST_ROUNDS)
		GameState.match_over.emit(-1)
		return
	current_phase = p
	emit_signal("phase_changed", p)

func _do_draft_reveal() -> void:
	GameState.pending_actions = [{}, {}]  # clear each round
	print("")
	print("========== ROUND %d ==========" % GameState.round_number)
	print("Player — VP: %d  Gold: %d" % [GameState.vp[0], GameState.gold[0]])
	print("Bot    — VP: %d  Gold: %d" % [GameState.vp[1], GameState.gold[1]])
	_print_board_state()
	GameState.current_draft_units = draft_pool.draw_three()
	_set_phase(Phase.DRAFT_BIDDING)
	emit_signal("waiting_for_player", Phase.DRAFT_BIDDING)
	# Bot also prepares bids (stored internally, revealed at resolve)
	bot.prepare_draft_bids_for_player(GameState.current_draft_units, 1)

func _do_draft_bidding() -> void:
	# UI calls submit_player_bids() when player confirms
	pass

func submit_player_bids(bids: Dictionary) -> void:
	# bids = { unit_index: gold_amount }
	assert(current_phase == Phase.DRAFT_BIDDING)
	GameState.pending_bids[0] = bids
	_set_phase(Phase.DRAFT_RESOLVE)
	call_deferred("advance")

func _do_draft_resolve() -> void:
	var bot_bids = bot.get_draft_bids()
	GameState.pending_bids[1] = bot_bids
	var results = []
	for i in range(3):
		var unit_data = GameState.current_draft_units[i]
		var bid_p = GameState.pending_bids[0].get(i, 0)
		var bid_b = GameState.pending_bids[1].get(i, 0)
		var winner = -1
		if bid_p > 0 or bid_b > 0:
			if bid_p > bid_b:
				winner = 0
			elif bid_b > bid_p:
				winner = 1
			else:
				winner = -1 # tie, nobody wins
		if winner != -1:
			var winning_bid = GameState.pending_bids[winner].get(i, 0)
			GameState.spend_gold(winner, winning_bid)
			var new_unit = UnitInstance.new(unit_data, winner)
			GameState.bench[winner].append(new_unit)
		results.append({
			"unit_index": i,
			"winner": winner,
			"player_bid": bid_p,
			"bot_bid": bid_b
		})

	print("--- DRAFT RESULTS ---")
	for r in results:
		var unit = GameState.current_draft_units[r.unit_index]
		var result_str = ""
		if r.winner == 0:
			result_str = "Player wins (bid %d vs %d)" % [r.player_bid, r.bot_bid]
		elif r.winner == 1:
			result_str = "Bot wins (bid %d vs %d)" % [r.bot_bid, r.player_bid]
		elif r.player_bid == 0 and r.bot_bid == 0:
			result_str = "passed by both"
		else:
			result_str = "tied — nobody wins (both bid %d)" % r.player_bid
		print("  %s [%s] floor %d → %s" % [
			unit.display_name,
			_weapon_str(unit.unit_type),
			unit.floor_cost,
			result_str
		])

	draft_pool.recycle(GameState.current_draft_units)
	_set_phase(Phase.FUSION)
	call_deferred("advance")

func _do_fusion() -> void:
	for player_id in range(2):
		var events = fusion_checker.check_and_fuse(player_id)
		for e in events:
			var who = "Player" if e.player_id == 0 else "Bot"
			print("  FUSION: %s fused two %s → %s" % [
				who,
				_unit_str(e.consumed[0]),
				_unit_str(e.result)
			])
	_set_phase(Phase.ACTION_COMMIT)
	bot.prepare_action_for_player(1)
	emit_signal("waiting_for_player", Phase.ACTION_COMMIT)

func _do_action_commit() -> void:
	pass  # waiting for player input

func submit_player_action(action: Dictionary) -> void:
	assert(current_phase == Phase.ACTION_COMMIT)
	GameState.pending_actions[0] = action
	_set_phase(Phase.ACTION_RESOLVE)
	call_deferred("advance")

func _do_action_resolve() -> void:
	GameState.pending_actions[1] = bot.get_action()
	print("--- ACTIONS ---")
	print("  Player: %s" % _action_str(GameState.pending_actions[0]))
	print("  Bot:    %s" % _action_str(GameState.pending_actions[1]))
	action_executor.execute(0, GameState.pending_actions[0])
	action_executor.execute(1, GameState.pending_actions[1])
	_set_phase(Phase.LANE_RESOLUTION)
	call_deferred("advance")

func _do_lane_resolution() -> void:
	_lane_results = []
	var lane_names = ["Left Flank", "Center", "Right Flank"]
	print("--- LANE RESOLUTION ---")

	# First loop: resolve combat and print what happened
	for lane in range(3):
		var result = combat_resolver.resolve_lane(lane)
		_lane_results.append(result)
		var lane_name = lane_names[lane]

		if not result.combat and result.claimant == -1:
			print("  %s: empty" % lane_name)
		elif not result.combat:
			var unit = result.attacker_a if result.claimant == 0 else result.attacker_b
			print("  %s: %s uncontested" % [lane_name, _unit_str(unit)])
		else:
			var adv_str = ""
			if result.advantage == "player": adv_str = " [Player advantage]"
			elif result.advantage == "bot": adv_str = " [Bot advantage]"
			# Use snapshotted might values, not live values
			var a_str = "T%d %s (%d Might)" % [
				result.attacker_a.data.tier,
				result.attacker_a.data.display_name,
				result.attacker_a_might_before
			] if result.attacker_a else "empty"
			var b_str = "T%d %s (%d Might)" % [
				result.attacker_b.data.tier,
				result.attacker_b.data.display_name,
				result.attacker_b_might_before
			] if result.attacker_b else "empty"

			print("  %s: %s vs %s%s" % [lane_name, a_str, b_str, adv_str])
			print("    Damage → Player unit: %d, Bot unit: %d" % [
				result.damage_to_a,
				result.damage_to_b
			])
			if result.destroyed_a: print("    Player unit destroyed")
			if result.destroyed_b: print("    Bot unit destroyed")
			if not result.destroyed_a and result.attacker_a:
				print("    Player unit survives at %d Might" % result.attacker_a.current_might)
			if not result.destroyed_b and result.attacker_b:
				print("    Bot unit survives at %d Might" % result.attacker_b.current_might)

	# Second loop: apply rewards
	var claimants = [-1, -1, -1]
	for result in _lane_results:
		claimants[result.lane] = result.claimant

	print("--- REWARDS ---")
	for result in _lane_results:
		var cid = result.claimant
		if cid == -1:
			continue
		var who = "Player" if cid == 0 else "Bot"
		var lane_name = lane_names[result.lane]
		GameState.add_gold(cid, 1)
		if result.lane == 1:
			GameState.add_vp(cid, 1)
			print("  %s claims Center (+1 gold +1 VP)" % who)
			if GameState.check_victory() != -1:
				_set_phase(Phase.VICTORY_CHECK)
				call_deferred("advance")
				return
		else:
			print("  %s claims %s (+1 gold)" % [who, lane_name])

	# Both flanks bonus
	for player_id in range(2):
		if claimants[0] == player_id and claimants[2] == player_id:
			GameState.add_vp(player_id, 1)
			var who = "Player" if player_id == 0 else "Bot"
			print("  %s controls both flanks (+1 VP bonus)" % who)
			if GameState.check_victory() != -1:
				_set_phase(Phase.VICTORY_CHECK)
				call_deferred("advance")
				return

	_set_phase(Phase.INCOME)
	call_deferred("advance")

func _do_income() -> void:
	economy_manager.apply_base_income()
	GameState.round_number += 1
	_set_phase(Phase.VICTORY_CHECK)
	call_deferred("advance")

func _do_victory_check() -> void:
	var winner = GameState.check_victory()
	if winner != -1:
		_set_phase(Phase.MATCH_OVER)
		GameState.emit_signal("match_over", winner)
	else:
		_set_phase(Phase.DRAFT_REVEAL)
		call_deferred("advance")

func _unit_str(unit) -> String:
	if unit == null:
		return "empty"
	return "T%d %s (%d Might)" % [unit.data.tier, unit.data.display_name, unit.current_might]

func _weapon_str(unit_type: int) -> String:
	match unit_type:
		UnitData.UnitType.STRIKER:  return "Striker"
		UnitData.UnitType.TACTICIAN: return "Tactician"
		UnitData.UnitType.BULWARK:  return "Bulwark"
	return "?"
	
func _action_str(action: Dictionary) -> String:
	if action.is_empty():
		return "none"
	match action.get("type", -1):
		0: return "Deploy %s → lane %d" % [_unit_str(action.get("unit")), action.get("target_lane", -1)]
		1: return "Retreat %s" % _unit_str(action.get("unit"))
		2: return "Shift %s → lane %d" % [_unit_str(action.get("unit")), action.get("target_lane", -1)]
		3: return "Swap lanes %d and %d" % [action.get("target_lane", -1), action.get("swap_lane", -1)]
		4: return "Hold"
	return "unknown"
	
func _print_board_state() -> void:
	var lane_names = ["Left", "Center", "Right"]
	print("  Board:")
	for lane in range(3):
		var p = GameState.board[0][lane]
		var b = GameState.board[1][lane]
		var p_str = _unit_str(p) if p != null else "empty"
		var b_str = _unit_str(b) if b != null else "empty"
		print("    %s — Player: %s | Bot: %s" % [lane_names[lane], p_str, b_str])
