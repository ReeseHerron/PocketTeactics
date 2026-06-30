# scenes/ui/BoardPanel.gd
# Displays the 3-lane board for both players.
# Listens to EventBus.board_changed and refreshes all slots.
#
# Expected scene tree:
#   BoardPanel (Control or GridContainer)
#   ├── LaneLeft   (Control)
#   │   ├── PlayerSlot  (BoardSlot)
#   │   └── BotSlot     (BoardSlot)
#   ├── LaneCenter (Control)
#   │   ├── PlayerSlot  (BoardSlot)
#   │   └── BotSlot     (BoardSlot)
#   └── LaneRight  (Control)
#       ├── PlayerSlot  (BoardSlot)
#       └── BotSlot     (BoardSlot)
#
# Adjust node paths below to match your actual scene if they differ.
extends Control


@onready var player_slots: Array = [
	$HBoxContainer/LaneLeft/PlayerSlot,
	$HBoxContainer/LaneCenter/PlayerSlot,
	$HBoxContainer/LaneRight/PlayerSlot,
]
@onready var bot_slots: Array = [
	$HBoxContainer/LaneLeft/BotSlot,
	$HBoxContainer/LaneCenter/BotSlot,
	$HBoxContainer/LaneRight/BotSlot,
]


func _ready() -> void:
	EventBus.board_changed.connect(refresh)
	EventBus.bench_changed.connect(func(_id): refresh())
	refresh()


func refresh() -> void:
	for lane in range(3):
		player_slots[lane].setup(GameState.board[0][lane], lane, false)
		bot_slots[lane].setup(GameState.board[1][lane], lane, true)
