# BoardSlot.gd
extends PanelContainer

@onready var name_label = $VBox/NameLabel
@onready var might_label = $VBox/MightLabel
@onready var type_label = $VBox/TypeLabel

func display(unit) -> void:
	if unit == null:
		name_label.text = "Empty"
		might_label.text = ""
		type_label.text = ""
	else:
		name_label.text = "T%d %s" % [unit.data.tier, unit.data.display_name]
		might_label.text = "%d/%d Might" % [unit.current_might, unit.data.get_max_might()]
		type_label.text = unit.data.get_type_name()  # add this helper to UnitData
