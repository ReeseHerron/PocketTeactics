# src/ActionExecutor.gd
# Executes maneuvers and deploys in the correct resolution order.
# Also provides project_board_after_maneuver() as a pure simulation helper
# used by the UI (player board preview) and Bot (deploy scoring).
class_name ActionExecutor
extends RefCounted


enum ManeuverType { RETREAT, SHIFT, MUSTER, SKIP }
enum DeployType   { DEPLOY, SKIP }


# ── Board projection (pure — does NOT mutate GameState) ───────────────────────
# Returns a shallow copy of the board with one player's maneuver applied.
# Safe to call at any time for preview purposes.
static func project_board_after_maneuver(player_id: int, maneuver: Dictionary) -> Array:
	var projected: Array = [
		GameState.board[0].duplicate(),
		GameState.board[1].duplicate(),
	]
	match maneuver.get("type", ManeuverType.SKIP):
		ManeuverType.RETREAT:
			var unit: UnitInstance = maneuver.get("unit")
			if unit:
				for lane in range(3):
					if projected[player_id][lane] == unit:
						projected[player_id][lane] = null
		ManeuverType.SHIFT:
			var unit: UnitInstance = maneuver.get("unit")
			var target: int = maneuver.get("target_lane", -1)
			if unit and target >= 0:
				for lane in range(3):
					if projected[player_id][lane] == unit:
						projected[player_id][lane] = null
				projected[player_id][target] = unit
		ManeuverType.MUSTER:
			var unit: UnitInstance = maneuver.get("unit")
			var target: int = maneuver.get("target_lane", -1)
			if unit and target >= 0:
				projected[player_id][target] = unit
		ManeuverType.SKIP:
			pass
	return projected


# ── Resolution methods (called by RoundManager in strict order) ───────────────
# Each iterates both players and executes that action type if present.

func execute_retreats(plans: Array) -> void:
	for player_id in range(2):
		var m: Dictionary = plans[player_id].get("maneuver", {})
		if m.get("type") == ManeuverType.RETREAT:
			_do_retreat(player_id, m.get("unit"))


func execute_shifts(plans: Array) -> void:
	for player_id in range(2):
		var m: Dictionary = plans[player_id].get("maneuver", {})
		if m.get("type") == ManeuverType.SHIFT:
			_do_shift(player_id, m.get("unit"), m.get("target_lane", -1))


func execute_musters(plans: Array) -> void:
	for player_id in range(2):
		var m: Dictionary = plans[player_id].get("maneuver", {})
		if m.get("type") == ManeuverType.MUSTER:
			_do_muster(player_id, m.get("unit"), m.get("target_lane", -1))


func execute_deploys(plans: Array) -> void:
	for player_id in range(2):
		var d: Dictionary = plans[player_id].get("deploy", {})
		if d.get("type") == DeployType.DEPLOY:
			_do_deploy(player_id, d.get("unit"), d.get("target_lane", -1))


# ── Private action implementations ────────────────────────────────────────────

func _do_retreat(player_id: int, unit: UnitInstance) -> void:
	if unit == null:
		push_error("RETREAT: unit is null for player %d" % player_id)
		return
	for lane in range(3):
		if GameState.board[player_id][lane] == unit:
			GameState.board[player_id][lane] = null
			# v4: retreat does NOT heal. Bench recovery heals at round start.
			GameState.bench[player_id].append(unit)
			EventBus.bench_changed.emit(player_id)
			EventBus.unit_benched.emit(player_id)
			print("    %s retreats %s from lane %d" % [
				"Player" if player_id == 0 else "Bot",
				unit.display_str(), lane
			])
			return
	push_error("RETREAT: unit not found on board for player %d" % player_id)


func _do_shift(player_id: int, unit: UnitInstance, target_lane: int) -> void:
	if unit == null or target_lane < 0:
		push_error("SHIFT: invalid args for player %d" % player_id)
		return
	for lane in range(3):
		if GameState.board[player_id][lane] != unit:
			continue
		if abs(lane - target_lane) != 1:
			push_error("SHIFT: lane %d → %d is not adjacent" % [lane, target_lane])
			return
		if GameState.board[player_id][target_lane] != null:
			push_error("SHIFT: target lane %d occupied for player %d" % [target_lane, player_id])
			return
		GameState.board[player_id][lane] = null
		GameState.board[player_id][target_lane] = unit
		unit.is_fresh = true
		print("    %s shifts %s: lane %d → lane %d" % [
			"Player" if player_id == 0 else "Bot",
			unit.display_str(), lane, target_lane
		])
		return
	push_error("SHIFT: unit not found on board for player %d" % player_id)


func _do_muster(player_id: int, unit: UnitInstance, target_lane: int) -> void:
	# Muster: emergency deploy when the player has no board units.
	# Mustered units count as fresh (same claim rules as a normal deploy).
	if unit == null or target_lane < 0:
		push_error("MUSTER: invalid args for player %d" % player_id)
		return
	if GameState.board[player_id][target_lane] != null:
		push_error("MUSTER: target lane %d occupied for player %d" % [target_lane, player_id])
		return
	if not GameState.bench[player_id].has(unit):
		push_error("MUSTER: unit not on bench for player %d" % player_id)
		return
	GameState.bench[player_id].erase(unit)
	GameState.board[player_id][target_lane] = unit
	unit.is_fresh = true
	EventBus.bench_changed.emit(player_id)
	print("    %s musters %s to lane %d" % [
		"Player" if player_id == 0 else "Bot",
		unit.display_str(), target_lane
	])


func _do_deploy(player_id: int, unit: UnitInstance, target_lane: int) -> void:
	if unit == null or target_lane < 0:
		push_error("DEPLOY: invalid args for player %d" % player_id)
		return
	if GameState.board[player_id][target_lane] != null:
		push_error("DEPLOY: target lane %d occupied for player %d" % [target_lane, player_id])
		return
	if not GameState.bench[player_id].has(unit):
		var msg := "  ⚠ DEPLOY INVALID: %s's %s is not in bench — was it already used by Muster?" % [
			"Player" if player_id == 0 else "Bot",
			unit.display_str(),
		]
		print(msg)
		push_error(msg)
		return
	GameState.bench[player_id].erase(unit)
	GameState.board[player_id][target_lane] = unit
	unit.is_fresh = true
	EventBus.bench_changed.emit(player_id)
	print("    %s deploys %s to lane %d" % [
		"Player" if player_id == 0 else "Bot",
		unit.display_str(), target_lane
	])
