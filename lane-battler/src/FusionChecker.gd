class_name FusionChecker
extends RefCounted

# Returns array of fusion events: {player_id, consumed: [UnitInstance, UnitInstance], result: UnitInstance}
func check_and_fuse(player_id: int) -> Array:
	var events = []
	var changed = true

	while changed:
		changed = false
		var all_units = _get_all_units(player_id)

		for i in range(all_units.size()):
			var unit_a = all_units[i]

			for j in range(i + 1, all_units.size()):
				var unit_b = all_units[j]

				if unit_a.can_fuse_with(unit_b) and unit_a.data.tier < 3:
					var fused = _create_fused_unit(unit_a, player_id)

					_remove_unit(player_id, unit_a)
					_remove_unit(player_id, unit_b)
					_place_on_bench(player_id, fused)

					events.append({
						"player_id": player_id,
						"consumed": [unit_a, unit_b],
						"result": fused
					})

					changed = true
					break

			if changed:
				break

	return events

func _get_all_units(player_id: int) -> Array:
	return GameState.bench[player_id].duplicate()

func _create_fused_unit(source: UnitInstance, owner: int) -> UnitInstance:
	var new_data = source.data.duplicate()
	new_data.tier = source.data.tier + 1
	new_data.base_might = new_data.get_max_might()
	return UnitInstance.new(new_data, owner)

func _remove_unit(player_id: int, unit: UnitInstance) -> void:
	GameState.bench[player_id].erase(unit)
	for lane in range(3):
		if GameState.board[player_id][lane] == unit:
			GameState.board[player_id][lane] = null

func _place_on_bench(player_id: int, unit: UnitInstance) -> void:
	GameState.bench[player_id].append(unit)
