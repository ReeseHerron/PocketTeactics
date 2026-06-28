# StatusPanel.gd
extends VBoxContainer

@onready var round_label = $RoundLabel
@onready var player_vp = $PlayerVP
@onready var bot_vp = $BotVP
@onready var player_gold = $PlayerGold
@onready var bot_gold = $BotGold

func refresh() -> void:
	round_label.text = "Round %d" % GameState.round_number
	player_vp.text = "Player VP: %d / 5" % GameState.vp[0]
	bot_vp.text = "Bot VP: %d / 5" % GameState.vp[1]
	player_gold.text = "Player Gold: %d" % GameState.gold[0]
	bot_gold.text = "Bot Gold: %d (debug)" % GameState.gold[1]
