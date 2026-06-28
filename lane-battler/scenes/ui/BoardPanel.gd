# BoardPanel.gd
extends GridContainer

# 6 slot nodes, top row = bot, bottom row = player
@onready var slots = [
	[$BotLeft, $BotCenter, $BotRight],           # index 1 = bot
	[$PlayerLeft, $PlayerCenter, $PlayerRight]   # index 0 = player
]

func refresh() -> void:
	for player_id in range(2):
		for lane in range(3):
			var unit = GameState.board[player_id][lane]
			var slot = slots[player_id][lane]
			if unit == null:
				slot.get_node("VBox/NameLabel").text = "Empty"
				slot.get_node("VBox/MightLabel").text = ""
				slot.get_node("VBox/TypeLabel").text = ""
			else:
				slot.get_node("VBox/NameLabel").text = "T%d %s" % [unit.data.tier, unit.data.display_name]
				slot.get_node("VBox/MightLabel").text = "%d/%d Might" % [unit.current_might, unit.data.get_max_might()]
				slot.get_node("VBox/TypeLabel").text = unit.data.get_type_name()
