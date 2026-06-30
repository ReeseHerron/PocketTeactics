# src/FusionChecker.gd
# Checks bench for fuseable triples and produces fused units via UnitRegistry.
# Fusion requires 3 identical T1 units → 1 T2 unit.
# T2 units do not fuse further unless a special unit type allows it in future.
class_name FusionChecker
extends RefCounted


# Returns an Array of fusion event Dictionaries:
#   { player_id, consumed: [Unit, Unit, Unit], result: UnitInstance }
func check_and_fuse(player_id: int) -> Array:
	var events := []
	var changed := true

	# Loop until no more fusions are possible.
	while changed:
		changed = false

		# Group eligible bench units by fusion_group_id + tier.
		# Only T1 fuses for now; T2→T3 can be added later per unit type.
		var groups: Dictionary = {}
		for unit in GameState.bench[player_id]:
			if unit.data.tier != 1 or unit.data.fusion_group_id == 0:
				continue
			var key: String = "%d_%d" % [unit.data.fusion_group_id, unit.data.tier]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(unit)

		# Look for any group of 3+
		for key in groups:
			var group: Array = groups[key]
			if group.size() < 3:
				continue

			var consumed: Array = [group[0], group[1], group[2]]
			var fused: UnitInstance = _create_fused_unit(consumed[0], player_id)
			if fused == null:
				continue

			for unit in consumed:
				_remove_unit(player_id, unit)
			_place_on_bench(player_id, fused)

			events.append({
				"player_id": player_id,
				"consumed":  consumed,
				"result":    fused,
			})
			EventBus.fusion_occurred.emit(player_id, fused)
			changed = true
			break

	return events


# ── Internal ──────────────────────────────────────────────────────────────────

func _create_fused_unit(source: UnitInstance, owner: int) -> UnitInstance:
	# Ask the registry for the correct T(n+1) resource in this fusion line.
	# No resource duplication or mutation — we get the real authored .tres file.
	var result_data := UnitRegistry.get_fusion_result(
		source.data.fusion_group_id,
		source.data.tier + 1
	)
	if result_data == null:
		return null
	return UnitInstance.new(result_data, owner)


func _remove_unit(player_id: int, unit: UnitInstance) -> void:
	GameState.bench[player_id].erase(unit)
	# Safety: also clear it from the board if it somehow ended up there.
	for lane in range(3):
		if GameState.board[player_id][lane] == unit:
			GameState.board[player_id][lane] = null


func _place_on_bench(player_id: int, unit: UnitInstance) -> void:
	GameState.bench[player_id].append(unit)
	EventBus.bench_changed.emit(player_id)
