# src/FusionChecker.gd
# Checks bench for fuseable pairs and produces fused units via UnitRegistry.
# Called by RoundManager during the FUSION_CHECK phase.
class_name FusionChecker
extends RefCounted


# Returns an Array of fusion event Dictionaries:
#   { player_id, consumed: [UnitInstance, UnitInstance], result: UnitInstance }
func check_and_fuse(player_id: int) -> Array:
	var events := []
	var changed := true

	# Loop until no more fusions are possible (handles chain fusions: T1→T2→T3).
	while changed:
		changed = false
		var all_units : Array = GameState.bench[player_id].duplicate()

		for i in range(all_units.size()):
			var unit_a: UnitInstance = all_units[i]

			for j in range(i + 1, all_units.size()):
				var unit_b: UnitInstance = all_units[j]

				if not unit_a.can_fuse_with(unit_b):
					continue

				var fused := _create_fused_unit(unit_a, player_id)
				if fused == null:
					continue  # Registry had no result (shouldn't happen; logged there)

				_remove_unit(player_id, unit_a)
				_remove_unit(player_id, unit_b)
				_place_on_bench(player_id, fused)

				events.append({
					"player_id": player_id,
					"consumed": [unit_a, unit_b],
					"result": fused,
				})

				EventBus.fusion_occurred.emit(player_id, fused)
				changed = true
				break

			if changed:
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
