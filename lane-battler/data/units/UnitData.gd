# data/units/UnitData.gd
# Static unit definition. One .tres file per unique unit variant.
# UnitInstance wraps this at runtime and tracks mutable state.
#
# ID ASSIGNMENT RULES (permanent — never reuse a retired ID):
#   unit_id       — unique per .tres file, used for exact unit identity
#   fusion_group_id — shared across T1/T2/T3 of the same unit family
#
# Current ID map:
#   fusion_group 1 — Basic Striker    → unit_ids 1, 2, 3
#   fusion_group 2 — Basic Bulwark    → unit_ids 4, 5, 6
#   fusion_group 3 — Basic Tactician  → unit_ids 7, 8, 9
#   fusion_group 4 — Finisher Striker → unit_ids 10, 11, 12
#   fusion_group 5 — Guard Bulwark    → unit_ids 13, 14, 15
#   fusion_group 6 — Planner Tactician → unit_ids 16, 17, 18
#   (continue from 19+ as new units are added)
class_name UnitData
extends Resource


enum UnitType { STRIKER, TACTICIAN, BULWARK }


# ── Identity ──────────────────────────────────────────────────────────────────

# Unique per .tres file. Set once, never change. 0 = unset (triggers assert in UnitRegistry).
@export var unit_id: int = 0

# Shared across the T1/T2/T3 variants of one unit family.
# FusionChecker matches on fusion_group_id + tier — no string comparison.
@export var fusion_group_id: int = 0


# ── Display ───────────────────────────────────────────────────────────────────

@export var display_name: String = ""


# ── Combat stats ──────────────────────────────────────────────────────────────

@export var unit_type: UnitType = UnitType.STRIKER
@export var tier: int = 1

# v4 might scale baselines: T1=4, T2=6, T3=10.
# Individual units may deviate (e.g. T1 Scout at 3, T1 Brute at 5).
# get_max_might() reads this directly.
@export var base_might: int = 4

@export var floor_cost: int = 2


# ── Abilities ─────────────────────────────────────────────────────────────────

# Each entry is a Dictionary describing one ability.
# AbilitySystem reads these at runtime.
# Format: { "trigger": "ON_DEPLOY", "effect": "GAIN_GOLD", "amount": 1 }
# Leave empty for baseline units.
@export var abilities: Array = []


# ── Helpers ───────────────────────────────────────────────────────────────────

func get_max_might() -> int:
	if base_might > 0:
		return base_might
	# Fallback in case base_might wasn't set in the inspector.
	match tier:
		1: return 4
		2: return 6
		3: return 10
	return 4


func get_type_name() -> String:
	match unit_type:
		UnitType.STRIKER:   return "Striker"
		UnitType.BULWARK:   return "Bulwark"
		UnitType.TACTICIAN: return "Tactician"
	return "?"
