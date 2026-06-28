class_name UnitInstance
extends RefCounted

var data: UnitData          # the template
var current_might: int
var owner_id: int           # 0 = player, 1 = bot

func _init(unit_data: UnitData, owner: int) -> void:
	data = unit_data
	current_might = unit_data.get_max_might()
	owner_id = owner

func is_alive() -> bool:
	return current_might > 0

func take_damage(amount: int) -> void:
	current_might = max(0, current_might - amount)

func heal_to_full() -> void:
	current_might = data.get_max_might()

# Two instances fuse if same unit_name and same tier
func can_fuse_with(other: UnitInstance) -> bool:
	return data.display_name == other.data.display_name and data.tier == other.data.tier
