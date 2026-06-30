# autoload/RoundManager.gd
# Drives the full game loop as a 16-phase state machine.
# UI submits player choices via the submit_* functions.
# Everything else advances automatically via call_deferred("advance").
extends Node


# ── Phase enum ────────────────────────────────────────────────────────────────
enum Phase {
	ROUND_START,      # clear fresh flags, apply income (round 2+)
	BENCH_RECOVERY,   # benched units heal 2 might
	DRAFT_REVEAL,     # draw 3 units from pool, show to both
	DRAFT_BIDDING,    # waiting for player bid submission
	DRAFT_RESOLVE,    # compare bids, award units, charge gold
	FUSION_CHECK,     # auto-fuse matching bench pairs
	MANEUVER_STEP,    # both players secretly choose maneuver
	DEPLOY_STEP,      # both players secretly choose deploy
	PLAN_REVEAL,      # simultaneous reveal of both plans
	RESOLVE_RETREATS, # execute all retreats
	RESOLVE_SHIFTS,   # execute all shifts
	RESOLVE_MUSTERS,  # execute all musters
	RESOLVE_DEPLOYS,  # execute all deploys
	RESOLVE_COMBAT,   # fight in every contested lane
	RESOLVE_REWARDS,  # award gold and VP for claimed lanes
	VICTORY_CHECK,    # check if someone hit 5 VP
	MATCH_OVER,
}

const MAX_ROUNDS := 30  # safety valve to prevent infinite loops

var current_phase: Phase = Phase.ROUND_START

# ── System references ─────────────────────────────────────────────────────────
var _draft_pool: DraftPool
var _fusion_checker: FusionChecker
var _combat_resolver: CombatResolver
var _action_executor: ActionExecutor
var _economy_manager: EconomyManager
var _bot: Bot

# ── Per-round hidden state ────────────────────────────────────────────────────
# Stored here during MANEUVER_STEP and DEPLOY_STEP, assembled into GameState
# pending_plans when the player confirms their deploy.
var _pending_player_maneuver: Dictionary = {}
var _pending_bot_maneuver: Dictionary = {}
var _pending_bot_deploy: Dictionary = {}
var _pending_combat_log: Array = []


# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	print("RoundManager ready")
	_draft_pool     = DraftPool.new()
	_fusion_checker = FusionChecker.new()
	_combat_resolver = CombatResolver.new()
	_action_executor = ActionExecutor.new()
	_economy_manager = EconomyManager.new()
	_bot            = Bot.new()


func start_match(roster_a: Array, roster_b: Array) -> void:
	GameState.clear_plans()
	_draft_pool.build_pool(roster_a, roster_b)
	call_deferred("advance")


# ── Central dispatcher ────────────────────────────────────────────────────────
func advance() -> void:
	match current_phase:
		Phase.ROUND_START:      _do_round_start()
		Phase.BENCH_RECOVERY:   _do_bench_recovery()
		Phase.DRAFT_REVEAL:     _do_draft_reveal()
		Phase.DRAFT_BIDDING:    pass  # waiting for submit_player_bids()
		Phase.DRAFT_RESOLVE:    _do_draft_resolve()
		Phase.FUSION_CHECK:     _do_fusion_check()
		Phase.MANEUVER_STEP:    _do_maneuver_step()
		Phase.DEPLOY_STEP:      pass  # waiting for submit_player_deploy()
		Phase.PLAN_REVEAL:      _do_plan_reveal()
		Phase.RESOLVE_RETREATS: _do_resolve_retreats()
		Phase.RESOLVE_SHIFTS:   _do_resolve_shifts()
		Phase.RESOLVE_MUSTERS:  _do_resolve_musters()
		Phase.RESOLVE_DEPLOYS:  _do_resolve_deploys()
		Phase.RESOLVE_COMBAT:   _do_resolve_combat()
		Phase.RESOLVE_REWARDS:  _do_resolve_rewards()
		Phase.VICTORY_CHECK:    _do_victory_check()


func _set_phase(p: Phase) -> void:
	if GameState.round_number > MAX_ROUNDS:
		push_error("RoundManager: exceeded %d rounds — match stalled." % MAX_ROUNDS)
		current_phase = Phase.MATCH_OVER
		EventBus.match_over.emit(-1)
		return
	current_phase = p
	EventBus.phase_changed.emit(p)


# ── Phase implementations ─────────────────────────────────────────────────────

func _do_round_start() -> void:
	print("")
	print("========== ROUND %d ==========" % GameState.round_number)
	# Apply income BEFORE printing gold so the header reflects what's actually spendable
	if GameState.round_number > 1:
		_economy_manager.apply_base_income()
		print("  Income: +2 gold each")
	print("Player — VP: %d  Gold: %d" % [GameState.vp[0], GameState.gold[0]])
	print("Bot    — VP: %d  Gold: %d" % [GameState.vp[1], GameState.gold[1]])
	_print_board_state()

	# v4: clear fresh flags from previous round
	GameState.clear_fresh_flags()

	_set_phase(Phase.BENCH_RECOVERY)
	call_deferred("advance")


func _do_bench_recovery() -> void:
	# All benched units heal 2 might, capped at their max.
	GameState.apply_bench_recovery()
	_set_phase(Phase.DRAFT_REVEAL)
	call_deferred("advance")


func _do_draft_reveal() -> void:
	GameState.pending_bids = [{}, {}]
	GameState.current_draft_units = _draft_pool.draw_three()
	EventBus.draft_units_revealed.emit(GameState.current_draft_units)
	# Bot prepares its bids silently while player sees the draft panel
	_bot.prepare_draft_bids(GameState.current_draft_units, 1)
	_set_phase(Phase.DRAFT_BIDDING)
	EventBus.waiting_for_player.emit(Phase.DRAFT_BIDDING)


func _do_draft_resolve() -> void:
	GameState.pending_bids[1] = _bot.get_draft_bids()
	var results: Array = []

	for i in range(3):
		var unit_data: UnitData = GameState.current_draft_units[i]
		var bid_p: int = GameState.pending_bids[0].get(i, 0)
		var bid_b: int = GameState.pending_bids[1].get(i, 0)
		var winner: int = -1

		if bid_p > 0 or bid_b > 0:
			if bid_p > bid_b:
				winner = 0
			elif bid_b > bid_p:
				winner = 1
			# else: tied → nobody wins (no extort in v4)

		if winner != -1:
			var winning_bid: int = GameState.pending_bids[winner].get(i, 0)
			GameState.spend_gold(winner, winning_bid)
			var new_unit := UnitInstance.new(unit_data, winner)
			GameState.bench[winner].append(new_unit)
			EventBus.bench_changed.emit(winner)

		results.append({
			"unit_index": i,
			"winner": winner,
			"player_bid": bid_p,
			"bot_bid": bid_b,
		})

	print("--- DRAFT RESULTS ---")
	for r in results:
		var unit: UnitData = GameState.current_draft_units[r.unit_index]
		var s := ""
		if r.winner == 0:
			s = "Player wins (bid %d vs %d)" % [r.player_bid, r.bot_bid]
		elif r.winner == 1:
			s = "Bot wins (bid %d vs %d)" % [r.bot_bid, r.player_bid]
		elif r.player_bid == 0 and r.bot_bid == 0:
			s = "passed by both"
		else:
			s = "tied — nobody wins (both bid %d)" % r.player_bid
		print("  %s [%s] floor %d → %s" % [
			unit.display_name, unit.get_type_name(), unit.floor_cost, s
		])

	EventBus.draft_resolved.emit(results)
	_draft_pool.recycle(GameState.current_draft_units)
	_set_phase(Phase.FUSION_CHECK)
	call_deferred("advance")


func _do_fusion_check() -> void:
	for player_id in range(2):
		var events := _fusion_checker.check_and_fuse(player_id)
		for e in events:
			var who := "Player" if e.player_id == 0 else "Bot"
			print("  FUSION: %s fused two %s → %s" % [
				who,
				e.consumed[0].display_str(),
				e.result.display_str(),
			])
	_set_phase(Phase.MANEUVER_STEP)
	call_deferred("advance")


func _do_maneuver_step() -> void:
	# Bot picks its maneuver immediately (hidden from player until reveal)
	_pending_bot_maneuver = _bot.choose_maneuver(1)
	# Clear any leftover player maneuver from last round
	_pending_player_maneuver = {}
	# Tell the UI to show the player their maneuver options
	EventBus.waiting_for_player.emit(Phase.MANEUVER_STEP)


func _do_deploy_step() -> void:
	# Bot picks its deploy using its own projected board after its maneuver.
	var bot_projected := ActionExecutor.project_board_after_maneuver(1, _pending_bot_maneuver)
	_pending_bot_deploy = _bot.choose_deploy(1, bot_projected)
	# Tell the UI to show deploy options.
	# UI can call ActionExecutor.project_board_after_maneuver(0, _pending_player_maneuver)
	# to show the player a preview of their own board before they pick deploy.
	EventBus.waiting_for_player.emit(Phase.DEPLOY_STEP)


func _do_plan_reveal() -> void:
	var player_plan: Dictionary = GameState.pending_plans[0]
	var bot_plan: Dictionary = GameState.pending_plans[1]

	print("--- PLANS REVEALED ---")
	print("  Player Maneuver: %s" % _maneuver_str(player_plan.get("maneuver", {})))
	print("  Player Deploy:   %s" % _deploy_str(player_plan.get("deploy", {})))
	print("  Bot Maneuver:    %s" % _maneuver_str(bot_plan.get("maneuver", {})))
	print("  Bot Deploy:      %s" % _deploy_str(bot_plan.get("deploy", {})))

	EventBus.plans_revealed.emit(player_plan, bot_plan)
	_set_phase(Phase.RESOLVE_RETREATS)
	call_deferred("advance")


func _do_resolve_retreats() -> void:
	print("--- RESOLVE: Retreats ---")
	_action_executor.execute_retreats(GameState.pending_plans)
	EventBus.board_changed.emit()
	_set_phase(Phase.RESOLVE_SHIFTS)
	call_deferred("advance")


func _do_resolve_shifts() -> void:
	print("--- RESOLVE: Shifts ---")
	_action_executor.execute_shifts(GameState.pending_plans)
	EventBus.board_changed.emit()
	_set_phase(Phase.RESOLVE_MUSTERS)
	call_deferred("advance")


func _do_resolve_musters() -> void:
	print("--- RESOLVE: Musters ---")
	_action_executor.execute_musters(GameState.pending_plans)
	EventBus.board_changed.emit()
	_set_phase(Phase.RESOLVE_DEPLOYS)
	call_deferred("advance")


func _do_resolve_deploys() -> void:
	print("--- RESOLVE: Deploys ---")
	_action_executor.execute_deploys(GameState.pending_plans)
	EventBus.board_changed.emit()
	_set_phase(Phase.RESOLVE_COMBAT)
	call_deferred("advance")


func _do_resolve_combat() -> void:
	print("--- RESOLVE: Combat ---")
	_pending_combat_log = []
	var lane_names := ["Left Flank", "Center", "Right Flank"]

	for lane in range(3):
		var result := _combat_resolver.resolve_lane(lane)
		_pending_combat_log.append(result)

		if not result.combat and result.claimant == -1:
			print("  %s: empty" % lane_names[lane])
		elif not result.combat:
			var holder: UnitInstance = result.attacker_a if result.claimant == 0 else result.attacker_b
			print("  %s: %s uncontested" % [lane_names[lane], holder.display_str()])
		else:
			var adv_str := ""
			if result.advantage == "player":   adv_str = " [Player advantage]"
			elif result.advantage == "bot":    adv_str = " [Bot advantage]"
			var a_str := _snapshot_str(result, "a")
			var b_str := _snapshot_str(result, "b")
			print("  %s: %s vs %s%s" % [lane_names[lane], a_str, b_str, adv_str])
			print("    Damage dealt → Player unit: %d  Bot unit: %d" % [
				result.damage_to_a, result.damage_to_b
			])
			if result.destroyed_a: print("    Player unit destroyed")
			if result.destroyed_b: print("    Bot unit destroyed")
			if not result.destroyed_a and result.attacker_a:
				print("    Player unit survives at %d might" % result.attacker_a.current_might)
			if not result.destroyed_b and result.attacker_b:
				print("    Bot unit survives at %d might" % result.attacker_b.current_might)
			# Note fresh-unit non-claim
			if result.claimant == -1 and result.combat:
				var fresh_winner := ""
				if result.attacker_a and result.attacker_a.is_alive() and result.attacker_a.is_fresh:
					fresh_winner = "Player's fresh unit wins but cannot claim this round"
				elif result.attacker_b and result.attacker_b.is_alive() and result.attacker_b.is_fresh:
					fresh_winner = "Bot's fresh unit wins but cannot claim this round"
				if fresh_winner != "":
					print("    (%s)" % fresh_winner)

	EventBus.combat_resolved.emit(_pending_combat_log)
	_set_phase(Phase.RESOLVE_REWARDS)
	call_deferred("advance")


func _do_resolve_rewards() -> void:
	print("--- RESOLVE: Rewards ---")
	var lane_names := ["Left Flank", "Center", "Right Flank"]
	var claimants := [-1, -1, -1]

	for result in _pending_combat_log:
		claimants[result.lane] = result.claimant

	for result in _pending_combat_log:
		var cid: int = result.claimant
		if cid == -1:
			continue
		var who := "Player" if cid == 0 else "Bot"
		GameState.add_gold(cid, 1)
		if result.lane == 1:  # Center → +1 VP
			GameState.add_vp(cid, 1)
			print("  %s claims Center (+1 gold, +1 VP)" % who)
		else:
			print("  %s claims %s (+1 gold)" % [who, lane_names[result.lane]])

	# Both flanks bonus → +1 VP
	for player_id in range(2):
		if claimants[0] == player_id and claimants[2] == player_id:
			GameState.add_vp(player_id, 1)
			var who := "Player" if player_id == 0 else "Bot"
			print("  %s controls both flanks (+1 VP)" % who)

	EventBus.lane_rewards_applied.emit(_pending_combat_log)
	GameState.clear_plans()
	_set_phase(Phase.VICTORY_CHECK)
	call_deferred("advance")


func _do_victory_check() -> void:
	var winner := GameState.check_victory()
	if winner != -1:
		_set_phase(Phase.MATCH_OVER)
		EventBus.match_over.emit(winner)
	else:
		GameState.round_number += 1
		_set_phase(Phase.ROUND_START)
		call_deferred("advance")


# ── Player submission functions (called by UI) ────────────────────────────────

func submit_player_bids(bids: Dictionary) -> void:
	assert(current_phase == Phase.DRAFT_BIDDING,
		"submit_player_bids called outside DRAFT_BIDDING (current: %d)" % current_phase)
	GameState.pending_bids[0] = bids
	_set_phase(Phase.DRAFT_RESOLVE)
	call_deferred("advance")


func submit_player_maneuver(maneuver: Dictionary) -> void:
	# Called by UI when player locks their maneuver choice.
	# UI then shows the player their projected board and the deploy picker.
	assert(current_phase == Phase.MANEUVER_STEP,
		"submit_player_maneuver called outside MANEUVER_STEP (current: %d)" % current_phase)
	_pending_player_maneuver = maneuver
	EventBus.maneuver_locked.emit(0)
	_set_phase(Phase.DEPLOY_STEP)
	_do_deploy_step()


func submit_player_deploy(deploy: Dictionary) -> void:
	# Called by UI when player confirms their deploy choice.
	# Both plans are now complete — assemble and move to reveal.
	assert(current_phase == Phase.DEPLOY_STEP,
		"submit_player_deploy called outside DEPLOY_STEP (current: %d)" % current_phase)
	EventBus.deploy_locked.emit(0)
	GameState.lock_plan(0, {
		"maneuver": _pending_player_maneuver,
		"deploy": deploy,
	})
	GameState.lock_plan(1, {
		"maneuver": _pending_bot_maneuver,
		"deploy": _pending_bot_deploy,
	})
	_set_phase(Phase.PLAN_REVEAL)
	call_deferred("advance")


# ── Debug helpers ─────────────────────────────────────────────────────────────

func _print_board_state() -> void:
	var lane_names := ["Left", "Center", "Right"]
	print("  Board:")
	for lane in range(3):
		var p: UnitInstance = GameState.board[0][lane]
		var b: UnitInstance = GameState.board[1][lane]
		print("    %s — Player: %s | Bot: %s" % [
			lane_names[lane],
			p.display_str() if p else "empty",
			b.display_str() if b else "empty",
		])


func _maneuver_str(m: Dictionary) -> String:
	if m.is_empty(): return "none"
	match m.get("type"):
		ActionExecutor.ManeuverType.RETREAT:
			return "Retreat %s" % (m.unit.display_str() if m.get("unit") else "?")
		ActionExecutor.ManeuverType.SHIFT:
			return "Shift %s → lane %d" % [
				m.unit.display_str() if m.get("unit") else "?",
				m.get("target_lane", -1)
			]
		ActionExecutor.ManeuverType.MUSTER:
			return "Muster %s → lane %d" % [
				m.unit.display_str() if m.get("unit") else "?",
				m.get("target_lane", -1)
			]
		ActionExecutor.ManeuverType.SKIP:
			return "Skip"
	return "unknown"


func _deploy_str(d: Dictionary) -> String:
	if d.is_empty(): return "none"
	match d.get("type"):
		ActionExecutor.DeployType.DEPLOY:
			return "Deploy %s → lane %d" % [
				d.unit.display_str() if d.get("unit") else "?",
				d.get("target_lane", -1)
			]
		ActionExecutor.DeployType.SKIP:
			return "Skip"
	return "unknown"


func _snapshot_str(result: Dictionary, side: String) -> String:
	var attacker = result.get("attacker_" + side)
	var might_before = result.get("attacker_" + side + "_might_before", 0)
	if attacker == null: return "empty"
	return "T%d %s (%d might)" % [attacker.data.tier, attacker.data.display_name, might_before]
