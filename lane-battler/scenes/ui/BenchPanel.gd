# src/BenchPanel.gd
# Displays both benches in clearly separated sections.
# No scene changes needed — one Label child is enough.
#
# Expected scene tree:
#   BenchPanel (HBoxContainer)
#   └── Label
extends HBoxContainer

@onready var label: Label = $Label


func _ready() -> void:
	EventBus.bench_changed.connect(func(_id): refresh())
	refresh()


func refresh() -> void:
	var player_lines: Array = ["── Your Bench ──"]
	for unit in GameState.bench[0]:
		player_lines.append("  " + unit.display_str())
	if GameState.bench[0].is_empty():
		player_lines.append("  (empty)")

	var bot_lines: Array = ["── Bot Bench ──"]
	for unit in GameState.bench[1]:
		bot_lines.append("  " + unit.display_str())
	if GameState.bench[1].is_empty():
		bot_lines.append("  (empty)")

	label.text = "\n".join(player_lines) + "\n\n" + "\n".join(bot_lines)
