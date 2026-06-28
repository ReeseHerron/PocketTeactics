extends Control

@onready var cost_label = $CostLabel
@onready var opponent_vp_label = $OpponentVpLabel
@onready var yes_btn = $YesBtn
@onready var no_btn = $NoBtn

func show_prompt() -> void:
	cost_label.text = "Extort cost: %d gold" % GameState.extort_cost[0]
	opponent_vp_label.text = "Opponent VP: %d" % GameState.vp[1]
	yes_btn.disabled = not GameState.can_extort(0)
	show()

func _ready() -> void:
	yes_btn.pressed.connect(func(): RoundManager.submit_extort_decision(true); hide())
	no_btn.pressed.connect(func(): RoundManager.submit_extort_decision(false); hide())
