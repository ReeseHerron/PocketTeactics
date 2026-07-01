# src/BenchPanel.gd
extends HBoxContainer

func _ready() -> void:
	EventBus.bench_changed.connect(func(_id): refresh())
	refresh()

func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_add_section("── Your Bench ──", 0)
	_add_section("── Bot Bench ──",  1)

func _add_section(title: String, player_id: int) -> void:
	# Each section is a VBoxContainer so cards stack vertically
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(200, 0)

	var header := Label.new()
	header.text = title
	section.add_child(header)

	if GameState.bench[player_id].is_empty():
		var empty := Label.new()
		empty.text = "  (empty)"
		section.add_child(empty)
	else:
		for unit in GameState.bench[player_id]:
			_add_unit_card(unit, section)

	add_child(section)

func _add_unit_card(unit: UnitInstance, section: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color                   = unit.data.get_color()
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = "  " + unit.display_str()
	panel.add_child(lbl)
	section.add_child(panel)
