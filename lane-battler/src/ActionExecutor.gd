class_name ActionExecutor
extends RefCounted

enum ActionType { DEPLOY, RETREAT, SHIFT, SWAP, HOLD }

# action = { type: ActionType, unit: UnitInstance, target_lane: int, swap_lane: int }
func execute(player_id: int, action: Dictionary) -> void:
	var action_type = action["type"]  # use bracket access instead of dot access
	match action_type:
		0: _deploy(player_id, action["unit"], action["target_lane"])
		1: _retreat(player_id, action["unit"])
		2: _shift(player_id, action["unit"], action["target_lane"])
		3: _swap(player_id, action["target_lane"], action["swap_lane"])
		4: pass  # HOLD
		_: print("Unknown action type: ", action_type)

func _deploy(player_id: int, unit: UnitInstance, lane: int) -> void:
	if unit == null:
		push_error("DEPLOY FAILED: unit is null")
		return

	if lane < 0 or lane >= 3:
		push_error("DEPLOY FAILED: invalid lane %d" % lane)
		return

	if GameState.board[player_id][lane] != null:
		push_error("DEPLOY FAILED: lane %d already occupied for player %d" % [lane, player_id])
		return

	if not GameState.bench[player_id].has(unit):
		push_error("DEPLOY FAILED: unit not found in bench for player %d: %s" % [
			player_id,
			unit.data.display_name
		])
		return

	GameState.bench[player_id].erase(unit)
	GameState.board[player_id][lane] = unit

func _retreat(player_id: int, unit: UnitInstance) -> void:
	for lane in range(3):
		if GameState.board[player_id][lane] == unit:
			GameState.board[player_id][lane] = null
			unit.heal_to_full()
			GameState.bench[player_id].append(unit)
			return

func _shift(player_id: int, unit: UnitInstance, target_lane: int) -> void:
	# Find current lane
	for lane in range(3):
		if GameState.board[player_id][lane] == unit:
			assert(abs(lane - target_lane) == 1)
			assert(GameState.board[player_id][target_lane] == null)
			GameState.board[player_id][lane] = null
			GameState.board[player_id][target_lane] = unit
			return

func _swap(player_id: int, lane_a: int, lane_b: int) -> void:
	assert(abs(lane_a - lane_b) == 1)
	var tmp = GameState.board[player_id][lane_a]
	GameState.board[player_id][lane_a] = GameState.board[player_id][lane_b]
	GameState.board[player_id][lane_b] = tmp
