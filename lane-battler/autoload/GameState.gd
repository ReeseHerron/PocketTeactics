# autoload/GameState.gd
# Pure data store. Holds all runtime game state.
# No signals live here — they all emit through EventBus.
# RoundManager and systems read/write this. UI reads this.
extends Node


func _ready() -> void:
	print("GameState ready")


# ── Board ─────────────────────────────────────────────────────────────────────
# board[player_id][lane] — lane: 0=Left, 1=Center, 2=Right
# Values are UnitInstance or null.
var board: Array = [
	[null, null, null],  # player 0
	[null, null, null],  # player 1 (bot)
]

# bench[player_id] — Array of UnitInstance
var bench: Array = [[], []]


# ── Economy ───────────────────────────────────────────────────────────────────
var gold: Array = [3, 3]   # starting gold per GDD v4
var vp: Array = [0, 0]


# ── Round tracking ────────────────────────────────────────────────────────────
var round_number: int = 1
var current_draft_units: Array = []  # 3 UnitData refs revealed this round
var pending_bids: Array = [{}, {}]   # pending_bids[player_id] = { unit_index: bid_amount }


# ── v4 Hidden Planning ────────────────────────────────────────────────────────
# A plan looks like:
#   {
#     "maneuver": { "type": ManeuverType,
#                   "unit": UnitInstance,   # unit being moved (null for SKIP)
#                   "target_lane": int },   # destination (SHIFT/MUSTER only)
#     "deploy":   { "type": DeployType,
#                   "unit": UnitInstance,   # unit from bench (null for SKIP)
#                   "target_lane": int }    # target lane (DEPLOY only)
#   }
var pending_plans: Array = [{}, {}]
var plans_locked: Array = [false, false]


# ── Economy helpers ───────────────────────────────────────────────────────────
func spend_gold(player_id: int, amount: int) -> void:
	gold[player_id] -= amount
	EventBus.gold_changed.emit(player_id, gold[player_id])


func add_gold(player_id: int, amount: int) -> void:
	gold[player_id] += amount
	EventBus.gold_changed.emit(player_id, gold[player_id])


func add_vp(player_id: int, amount: int) -> void:
	vp[player_id] += amount
	EventBus.vp_changed.emit(player_id, vp[player_id])


func check_victory() -> int:
	# Returns winner id (0 or 1), or -1 if no winner yet.
	for i in range(2):
		if vp[i] >= 5:
			return i
	return -1


func get_gold_range_label(player_id: int) -> String:
	var g = gold[player_id]
	if g <= 2:   return "Low"
	elif g <= 5: return "Medium"
	else:         return "High"


# ── v4 Planning helpers ───────────────────────────────────────────────────────
func lock_plan(player_id: int, plan: Dictionary) -> void:
	pending_plans[player_id] = plan
	plans_locked[player_id] = true


func both_plans_locked() -> bool:
	return plans_locked[0] and plans_locked[1]


func clear_plans() -> void:
	pending_plans = [{}, {}]
	plans_locked = [false, false]


# ── v4 Round-start helpers ────────────────────────────────────────────────────
func apply_bench_recovery() -> void:
	# Called by RoundManager during BENCH_RECOVERY phase.
	# All benched units heal 2 might, capped at max.
	for player_id in range(2):
		for unit in bench[player_id]:
			unit.heal(2)
	EventBus.bench_changed.emit(0)
	EventBus.bench_changed.emit(1)


func clear_fresh_flags() -> void:
	# Called at the top of each round before any new deployments.
	# Units that were fresh last round are now established.
	for player_id in range(2):
		for lane in range(3):
			var unit = board[player_id][lane]
			if unit != null:
				unit.is_fresh = false


# ── Board helpers ─────────────────────────────────────────────────────────────
func get_board_unit(player_id: int, lane: int) -> UnitInstance:
	return board[player_id][lane]


func has_any_board_unit(player_id: int) -> bool:
	for lane in range(3):
		if board[player_id][lane] != null:
			return true
	return false


func get_empty_lanes(player_id: int) -> Array:
	var empty: Array = []
	for lane in range(3):
		if board[player_id][lane] == null:
			empty.append(lane)
	return empty
