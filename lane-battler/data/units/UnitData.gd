class_name UnitData
extends Resource

enum UnitType { STRIKER, TACTICIAN, BULWARK }

@export var display_name: String = ""
@export var unit_type: UnitType = UnitType.STRIKER
@export var tier: int = 1
@export var base_might: int = 2      # Tier 1=2, Tier 2=3, Tier 3=6
@export var floor_cost: int = 2      # 2 gold
@export var keyword: String = ""     # empty in MVP

func get_max_might() -> int:
	match tier:
		1: return 2
		2: return 3
		3: return 6
	return 2
