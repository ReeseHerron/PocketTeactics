# src/BenchPanel.gd
# Displays both benches as color-coded unit cards, created dynamically on refresh.
# The scene only needs the root VBoxContainer — no Label child required.
extends HBoxContainer


func _ready() -> void:
	EventBus.bench_changed.connect(func(_id): refresh())
	refresh()


func refresh() -> void:
	# Clear all existing children
	for child in get_children():
		child.queue_free()

	_add_section("── Your Bench ──", 0)
	_add_section("── Bot Bench ──",  1)


# ── Internal ──────────────────────────────────────────────────────────────────

func _add_section(title: String, player_id: int) -> void:
	var header := Label.new()
	header.text = title
	add_child(header)

	if GameState.bench[player_id].is_empty():
		var empty := Label.new()
		empty.text = "  (empty)"
		add_child(empty)
	else:
		for unit in GameState.bench[player_id]:
			_add_unit_card(unit)


func _add_unit_card(unit: UnitInstance) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color                  = unit.data.get_color()
	style.corner_radius_top_left    = 4
	style.corner_radius_top_right   = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = "  " + unit.display_str()
	panel.add_child(lbl)
	add_child(panel)
