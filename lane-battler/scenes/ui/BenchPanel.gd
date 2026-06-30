# src/BenchPanel.gd
extends HBoxContainer

@onready var label: Label = $Label

func _ready() -> void:
	EventBus.bench_changed.connect(func(_id): refresh())
	refresh()

func refresh() -> void:
	var lines := ["── Bench ──"]
	for player_id in range(2):
		var who := "Player" if player_id == 0 else "Bot"
		for unit in GameState.bench[player_id]:
			lines.append("  %s: %s" % [who, unit.display_str()])
	label.text = "\n".join(lines)
