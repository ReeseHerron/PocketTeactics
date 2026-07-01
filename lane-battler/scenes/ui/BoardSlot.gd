# scenes/ui/BoardSlot.gd
# Displays a single board slot — one player's unit in one lane.
# Called by BoardPanel.refresh() every time the board changes.
#
# Expected scene tree:
#   BoardSlot (PanelContainer)
#   ├── NameLabel   (Label)  — "T1 Basic Striker" or "Empty"
#   ├── TypeLabel   (Label)  — "Striker" / "Bulwark" / "Tactician"
#   ├── MightLabel  (Label)  — "4/4" or blank
#   └── FreshLabel  (Label)  — "(fresh)" — hidden when unit is established
extends PanelContainer


@onready var name_label:  Label = $VBoxContainer/NameLabel
@onready var type_label:  Label = $VBoxContainer/TypeLabel
@onready var might_label: Label = $VBoxContainer/MightLabel
@onready var fresh_label: Label = $VBoxContainer/FreshLabel


func setup(unit: UnitInstance, lane: int, is_bot: bool) -> void:
	_apply_style(unit, lane, is_bot)
	
	if unit == null:
		name_label.text  = "Empty"
		type_label.text  = "_"
		might_label.text = "_"
		fresh_label.text = "—"
		fresh_label.hide()
		return

	name_label.text  = "T%d %s" % [unit.data.tier, unit.data.display_name]
	type_label.text  = unit.data.get_type_name()
	might_label.text = "%d / %d" % [unit.current_might, unit.data.get_max_might()]

	if unit.is_fresh:
		fresh_label.text = "⟳ Moved"
		
	else:
		fresh_label.text = "★ Holding"
	fresh_label.show()

func _apply_style(unit: UnitInstance, lane: int, is_bot: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = unit.data.get_color() if unit != null else Color(0.18, 0.18, 0.18)
	style.corner_radius_top_left    = 4
	style.corner_radius_top_right   = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
 
	# Always show matchup glow when an opponent occupies the same lane
	if unit != null:
		var player_id:   int          = 1 if is_bot else 0
		var opponent_id: int          = 1 - player_id
		var opponent:    UnitInstance = GameState.board[opponent_id][lane]
		if opponent != null:
			if CombatResolver.style_beats(unit.data.unit_type, opponent.data.unit_type):
				style.border_width_top    = 4
				style.border_width_bottom = 4
				style.border_width_left   = 4
				style.border_width_right  = 4
				style.border_color        = Color(1.0, 1.0, 1.0, 0.9)
			elif CombatResolver.style_beats(opponent.data.unit_type, unit.data.unit_type):
				style.border_width_top    = 4
				style.border_width_bottom = 4
				style.border_width_left   = 4
				style.border_width_right  = 4
				style.border_color        = Color(0.05, 0.05, 0.05, 1.0)
 
	add_theme_stylebox_override("panel", style)
