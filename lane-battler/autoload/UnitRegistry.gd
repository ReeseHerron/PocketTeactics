# autoload/UnitRegistry.gd
# Central registry for all UnitData definitions.
# Add to Autoloads AFTER EventBus, BEFORE GameState and RoundManager.
#
# Every unit in the game is registered here at startup.
# Systems look units up by unit_id or by (fusion_group_id, tier).
# Nothing compares unit names or duplicates resources at runtime.
extends Node


# Keyed by unit_id → UnitData
var _by_id: Dictionary = {}

# Keyed by "fusion_group_id_tier" → UnitData
# Used by FusionChecker to find the correct fused result resource.
var _by_fusion_key: Dictionary = {}


func _ready() -> void:
	_register_all()


# ── Registration ──────────────────────────────────────────────────────────────

func _register_all() -> void:
	# Add every unit .tres here as the roster grows.
	# IDs are permanent — never reassign a used ID.
	#
	# fusion_group | tier | unit_id | file
	# ─────────────┼──────┼─────────┼──────────────────────────────
	# 1 Basic Striker
	_add(preload("res://data/units/t1_basic_striker.tres"))
	_add(preload("res://data/units/t2_basic_striker.tres"))
	_add(preload("res://data/units/t3_basic_striker.tres"))
	# 2 Basic Bulwark
	_add(preload("res://data/units/t1_basic_bulwark.tres"))
	_add(preload("res://data/units/t2_basic_bulwark.tres"))
	_add(preload("res://data/units/t3_basic_bulwark.tres"))
	# 3 Basic Tactician
	_add(preload("res://data/units/t1_basic_tactician.tres"))
	_add(preload("res://data/units/t2_basic_tactician.tres"))
	_add(preload("res://data/units/t3_basic_tactician.tres"))
	# 4 Finisher Striker (ability: Finisher — deals +1 damage to damaged enemies)
	# _add(preload("res://data/units/t1_finisher_striker.tres"))
	# _add(preload("res://data/units/t2_finisher_striker.tres"))
	# _add(preload("res://data/units/t3_finisher_striker.tres"))
	# 5 Guard Bulwark (ability: Guard — takes 1 less damage while in Center)
	# _add(preload("res://data/units/t1_guard_bulwark.tres"))
	# 6 Planner Tactician (ability: Planner — gain +1 Gold on deploy/muster)
	# _add(preload("res://data/units/t1_planner_tactician.tres"))


func _add(unit_data: UnitData) -> void:
	assert(unit_data.unit_id != 0,
		"UnitData '%s' has unit_id = 0. Assign a unique non-zero ID." % unit_data.display_name)
	assert(not _by_id.has(unit_data.unit_id),
		"Duplicate unit_id %d for '%s'." % [unit_data.unit_id, unit_data.display_name])

	_by_id[unit_data.unit_id] = unit_data

	var fusion_key := _make_key(unit_data.fusion_group_id, unit_data.tier)
	_by_fusion_key[fusion_key] = unit_data


# ── Lookups ───────────────────────────────────────────────────────────────────

func get_unit(unit_id: int) -> UnitData:
	assert(_by_id.has(unit_id), "UnitRegistry: unit_id %d not registered." % unit_id)
	return _by_id[unit_id]


func get_fusion_result(fusion_group_id: int, target_tier: int) -> UnitData:
	# Returns the UnitData for the next tier in a fusion line, or null if none exists.
	# FusionChecker calls this to get the correct fused resource rather than
	# duplicating or mutating the source resource.
	var key := _make_key(fusion_group_id, target_tier)
	if not _by_fusion_key.has(key):
		push_error("UnitRegistry: no unit for fusion_group %d tier %d." % [fusion_group_id, target_tier])
		return null
	return _by_fusion_key[key]


func has_fusion_result(fusion_group_id: int, target_tier: int) -> bool:
	return _by_fusion_key.has(_make_key(fusion_group_id, target_tier))


func get_all_units() -> Array:
	return _by_id.values()


# ── Internal ──────────────────────────────────────────────────────────────────

func _make_key(fusion_group_id: int, tier: int) -> String:
	return "%d_%d" % [fusion_group_id, tier]
