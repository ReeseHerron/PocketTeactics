class_name CombatResolver
extends RefCounted

# Weapon triangle
func has_advantage(attacker_type: UnitData.UnitType, defender_type: UnitData.UnitType) -> bool:
	return (
		(attacker_type == UnitData.UnitType.STRIKER and defender_type == UnitData.UnitType.TACTICIAN) or
		(attacker_type == UnitData.UnitType.TACTICIAN and defender_type == UnitData.UnitType.BULWARK) or
		(attacker_type == UnitData.UnitType.BULWARK and defender_type == UnitData.UnitType.STRIKER)
	)

# Returns log entry dict for this lane
func resolve_lane(lane: int) -> Dictionary:
	var unit_a = GameState.board[0][lane]  # player unit
	var unit_b = GameState.board[1][lane]  # bot unit

	var entry := {
		"lane": lane,
		"combat": false,
		"attacker_a": unit_a,
		"attacker_b": unit_b,
		"attacker_a_might_before": unit_a.current_might if unit_a else 0,
		"attacker_b_might_before": unit_b.current_might if unit_b else 0,
		"advantage": "",
		"damage_to_a": 0,
		"damage_to_b": 0,
		"destroyed_a": false,
		"destroyed_b": false,
		"claimant": -1,
		"gold_reward": 0,
		"vp_reward": 0,
	}

	# Snapshot pre-combat state before anything mutates.
	if unit_a != null:
		entry["attacker_a_name"] = unit_a.data.display_name
		entry["attacker_a_tier"] = unit_a.data.tier
		entry["attacker_a_might_before"] = unit_a.current_might

	if unit_b != null:
		entry["attacker_b_name"] = unit_b.data.display_name
		entry["attacker_b_tier"] = unit_b.data.tier
		entry["attacker_b_might_before"] = unit_b.current_might

	# Empty lane: nothing to do.
	if unit_a == null and unit_b == null:
		return entry

	# Combat only happens if both sides have a unit in this lane.
	if unit_a != null and unit_b != null:
		entry["combat"] = true
		_apply_combat(unit_a, unit_b, entry)

	# Snapshot post-combat state.
	if unit_a != null:
		entry["attacker_a_might_after"] = unit_a.current_might

	if unit_b != null:
		entry["attacker_b_might_after"] = unit_b.current_might

	# Determine claimant: exactly one surviving unit claims the lane.
	var a_alive: bool = unit_a != null and unit_a.is_alive()
	var b_alive: bool = unit_b != null and unit_b.is_alive()

	if a_alive and not b_alive:
		entry["claimant"] = 0
	elif b_alive and not a_alive:
		entry["claimant"] = 1
	else:
		entry["claimant"] = -1

	# Assign rewards.
	if entry["claimant"] != -1:
		if lane == 1:
			entry["vp_reward"] = 1
		else:
			entry["gold_reward"] = 1

	# Remove destroyed units from board after claimant/reward info is computed.
	if unit_a != null and not unit_a.is_alive():
		GameState.board[0][lane] = null
		entry["destroyed_a"] = true

	if unit_b != null and not unit_b.is_alive():
		GameState.board[1][lane] = null
		entry["destroyed_b"] = true

	return entry

func _apply_combat(unit_a: UnitInstance, unit_b: UnitInstance, entry: Dictionary) -> void:
	var adv_a := has_advantage(unit_a.data.unit_type, unit_b.data.unit_type)
	var adv_b := has_advantage(unit_b.data.unit_type, unit_a.data.unit_type)

	var dmg_a_deals := unit_a.current_might
	var dmg_b_deals := unit_b.current_might

	if adv_a:
		dmg_a_deals += 1
		dmg_b_deals = max(0, dmg_b_deals - 1)
		entry["advantage"] = "player"
	elif adv_b:
		dmg_b_deals += 1
		dmg_a_deals = max(0, dmg_a_deals - 1)
		entry["advantage"] = "bot"

	entry["damage_to_b"] = dmg_a_deals
	entry["damage_to_a"] = dmg_b_deals

	# Simultaneous damage.
	unit_a.take_damage(dmg_b_deals)
	unit_b.take_damage(dmg_a_deals)
