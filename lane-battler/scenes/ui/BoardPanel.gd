# BoardPanel.gd
extends GridContainer

# 6 slot nodes, top row = bot, bottom row = player
@onready var slots = [
	[$BotLeft, $BotCenter, $BotRight],
	[$PlayerLeft, $PlayerCenter, $PlayerRight]
]

func refresh() -> void:
	for player_id in range(2):
		for lane in range(3):
			var unit = GameState.board[player_id][lane]
			slots[player_id][lane].display(unit)
