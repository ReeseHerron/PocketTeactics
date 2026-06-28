# autoload/GameState.gd
extends Node

func _ready() -> void:
	print("GameState ready")

# --- Board ---
# Indexed [player_id][lane] where lane 0=left, 1=center, 2=right
var board: Array = [
	[null, null, null],  # player 0 slots
	[null, null, null]   # player 1 (bot) slots
]
var bench: Array = [[], []]  # bench[0] = player bench, bench[1] = bot bench

# --- Economy ---
var gold: Array = [3, 3]           # exact gold per player
var vp: Array = [0, 0]             # starting VP per GDD v3

# --- Round tracking ---
var round_number: int = 1
var current_draft_units: Array = []    # 3 UnitData refs
var pending_bids: Array = [{}, {}]     # pending_bids[player][unit_index] = bid_amount
var pending_actions: Array = [{}, {}]

# --- Signals ---
signal state_changed()
signal draft_resolved(results: Array)
signal fusion_occurred(player_id: int, new_unit: UnitInstance)
signal combat_resolved(log: Array)
signal vp_changed(player_id: int, new_vp: int)
signal gold_changed(player_id: int, new_gold: int)
signal match_over(winner_id: int)

# --- Gold range helper (for opponent display) ---
func get_gold_range_label(player_id: int) -> String:
	var g = gold[player_id]
	if g <= 2: return "Low"
	elif g <= 5: return "Medium"
	else: return "High"

func spend_gold(player_id: int, amount: int) -> void:
	gold[player_id] -= amount
	emit_signal("gold_changed", player_id, gold[player_id])

func add_gold(player_id: int, amount: int) -> void:
	gold[player_id] += amount
	emit_signal("gold_changed", player_id, gold[player_id])

func add_vp(player_id: int, amount: int) -> void:
	vp[player_id] += amount
	emit_signal("vp_changed", player_id, vp[player_id])

func steal_vp(from_id: int, to_id: int) -> void:
	vp[from_id] = max(0, vp[from_id] - 1)
	vp[to_id] += 1
	emit_signal("vp_changed", from_id, vp[from_id])
	emit_signal("vp_changed", to_id, vp[to_id])

func check_victory() -> int:
	# Returns winner id or -1
	for i in range(2):
		if vp[i] >= 5:
			return i
	return -1
