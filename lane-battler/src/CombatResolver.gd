# src/CombatResolver.gd
# Resolves combat in a single lane and determines the claimant.
#
# v4 Fresh Unit Claim Rule:
#   Established unit, uncontested lane  → claims
#   Established unit, wins combat       → claims
#   Fresh unit, uncontested lane        → claims
#   Fresh unit, wins combat             → does NOT claim this round
#
# "Fresh" = unit.is_fresh is true (set when deployed/mustered this round).

# Gold:  any sole surviving unit earns its owner +1 gold
# VP:    established unit always; fresh unit only if lane was uncontested
#
# "Fresh" = unit.is_fresh is true (deployed, mustered, or shifted this round).
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
	#   Established + no combat   → gold + VP
	#   Established + wins combat → gold + VP
	#   Fresh + no combat         → gold + VP   (shifted/deployed into empty lane)
	#   Fresh + wins combat       → gold only   (moved into resistance, not held)
	if entry["combat"]:
		if a_alive and not b_alive:
			entry["gold_winner"] = 0
			entry["vp_eligible"] = -1 if unit_a.is_fresh else 0
		elif b_alive and not a_alive:
			entry["gold_winner"] = 1
			entry["vp_eligible"] = -1 if unit_b.is_fresh else 1
	else:
		if a_alive:
			entry["gold_winner"] = 0
			entry["vp_eligible"] = 0
		elif b_alive:
			entry["gold_winner"] = 1
			entry["vp_eligible"] = 1

	return entry


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
