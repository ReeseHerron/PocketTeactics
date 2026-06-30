# src/CombatResolver.gd
# Resolves combat in a single lane and determines gold and VP outcomes.
#
# Gold:   any sole surviving unit earns +1 gold (all lanes)
# VP:     Center — unit must be established (is_fresh == false, held position all turn)
#         Flanks — any sole unit earns flank VP regardless of freshness
#
# "Fresh" = unit.is_fresh is true (set when deployed, mustered, or shifted this round).
class_name CombatResolver
extends RefCounted


func has_advantage(attacker: UnitData.UnitType, defender: UnitData.UnitType) -> bool:
	return (
		(attacker == UnitData.UnitType.STRIKER   and defender == UnitData.UnitType.TACTICIAN) or
		(attacker == UnitData.UnitType.TACTICIAN and defender == UnitData.UnitType.BULWARK)   or
		(attacker == UnitData.UnitType.BULWARK   and defender == UnitData.UnitType.STRIKER)
	)


func resolve_lane(lane: int) -> Dictionary:
	var unit_a: UnitInstance = GameState.board[0][lane]  # player
	var unit_b: UnitInstance = GameState.board[1][lane]  # bot

	var entry: Dictionary = {
		"lane":                     lane,
		"combat":                   false,
		"attacker_a":               unit_a,
		"attacker_b":               unit_b,
		"attacker_a_might_before":  unit_a.current_might if unit_a else 0,
		"attacker_b_might_before":  unit_b.current_might if unit_b else 0,
		"advantage":                "",
		"damage_to_a":              0,
		"damage_to_b":              0,
		"destroyed_a":              false,
		"destroyed_b":              false,
		"gold_winner":              -1,  # sole survivor earns +1 gold regardless of freshness
		"vp_eligible":              -1,  # earns VP: established always, fresh only if uncontested
	}

	# Empty lane — nothing to do
	if unit_a == null and unit_b == null:
		return entry

	# Combat: both sides present → fight
	if unit_a != null and unit_b != null:
		entry["combat"] = true
		_apply_combat(unit_a, unit_b, entry)

	# Snapshot post-combat survival
	var a_alive: bool = unit_a != null and unit_a.is_alive()
	var b_alive: bool = unit_b != null and unit_b.is_alive()

	# Remove destroyed units from the board
	if unit_a != null and not unit_a.is_alive():
		GameState.board[0][lane] = null
		entry["destroyed_a"] = true
	if unit_b != null and not unit_b.is_alive():
		GameState.board[1][lane] = null
		entry["destroyed_b"] = true

	# ── Determine gold_winner and vp_eligible ────────────────────────────────
	# Gold:   any sole surviving unit earns +1 gold (all lanes, always)
	# VP:     Center (lane 1) — must be established (is_fresh == false)
	#         Flanks (lane 0/2) — any sole unit counts toward both-flank bonus
	if entry["combat"]:
		if a_alive and not b_alive:
			entry["gold_winner"] = 0
			entry["vp_eligible"] = _vp_eligible(unit_a, lane)
		elif b_alive and not a_alive:
			entry["gold_winner"] = 1
			entry["vp_eligible"] = _vp_eligible(unit_b, lane)
		# Both dead or both alive → no gold, no VP
	else:
		# Uncontested lane
		if a_alive:
			entry["gold_winner"] = 0
			entry["vp_eligible"] = _vp_eligible(unit_a, lane)
		elif b_alive:
			entry["gold_winner"] = 1
			entry["vp_eligible"] = _vp_eligible(unit_b, lane)

	return entry


func _vp_eligible(unit: UnitInstance, lane: int) -> int:
	if lane == 1:  # Center: must have held position all turn (established)
		return -1 if unit.is_fresh else unit.owner_id
	else:          # Flanks: any sole unit counts
		return unit.owner_id


func _apply_combat(
		unit_a: UnitInstance,
		unit_b: UnitInstance,
		entry: Dictionary) -> void:

	var adv_a := has_advantage(unit_a.data.unit_type, unit_b.data.unit_type)
	var adv_b := has_advantage(unit_b.data.unit_type, unit_a.data.unit_type)

	var dmg_a_deals := unit_a.current_might
	var dmg_b_deals := unit_b.current_might

	if adv_a:
		dmg_a_deals += 1
		dmg_b_deals  = max(0, dmg_b_deals - 1)
		entry["advantage"] = "player"
	elif adv_b:
		dmg_b_deals += 1
		dmg_a_deals  = max(0, dmg_a_deals - 1)
		entry["advantage"] = "bot"

	entry["damage_to_b"] = dmg_a_deals  # player deals to bot
	entry["damage_to_a"] = dmg_b_deals  # bot deals to player

	# Simultaneous — both take damage at the same moment
	unit_a.take_damage(dmg_b_deals)
	unit_b.take_damage(dmg_a_deals)
