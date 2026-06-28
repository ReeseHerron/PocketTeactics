# DraftPanel.gd
extends VBoxContainer

var bid_values: Array = [0, 0, 0]
var bids_active: Array = [false, false, false]

@onready var cards = [$Card0, $Card1, $Card2]
@onready var bid_inputs = [$Bid0, $Bid1, $Bid2]
@onready var bids_used_label = $BidsUsedLabel
@onready var total_label = $TotalLabel
@onready var confirm_btn = $ConfirmBtn

func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	for i in range(3):
		bid_inputs[i].value_changed.connect(_on_bid_changed.bind(i))

func populate(units: Array) -> void:
	for i in range(3):
		cards[i].setup(units[i])
		bid_inputs[i].value = 0
	bid_values = [0, 0, 0]
	bids_active = [false, false, false]
	_refresh()

func _on_bid_changed(value: float, index: int) -> void:
	bid_values[index] = int(value)
	var cost_floor = GameState.current_draft_units[index].floor_cost
	bids_active[index] = int(value) >= cost_floor
	_refresh()

func _refresh() -> void:
	var active_count = bids_active.count(true)
	bids_used_label.text = "%d/2 bids used" % active_count
	var total = bid_values.reduce(func(a, b): return a + b, 0)
	total_label.text = "Total: %d / %d gold" % [total, GameState.gold[0]]

	# Lock third input if 2 active
	for i in range(3):
		if active_count >= 2 and not bids_active[i]:
			bid_inputs[i].editable = false
		else:
			bid_inputs[i].editable = true

	# Validate confirm
	var valid = total <= GameState.gold[0]
	for i in range(3):
		if bid_values[i] > 0 and bid_values[i] < GameState.current_draft_units[i].floor_cost:
			valid = false
	confirm_btn.disabled = not valid

func _on_confirm() -> void:
	var bids = {}
	for i in range(3):
		if bid_values[i] > 0:
			bids[i] = bid_values[i]
	RoundManager.submit_player_bids(bids)
	hide()
