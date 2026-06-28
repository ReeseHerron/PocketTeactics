extends Control

var bid_values: Array = [0, 0, 0]   # one per card slot
var bids_active: Array = [false, false, false]

@onready var card_slots = [$Card0, $Card1, $Card2]
@onready var bid_inputs = [$Bid0, $Bid1, $Bid2]
@onready var bids_used_label = $BidsUsedLabel
@onready var total_label = $TotalBidLabel
@onready var confirm_btn = $ConfirmButton

func _ready() -> void:
	for i in range(3):
		bid_inputs[i].value_changed.connect(_on_bid_changed.bind(i))
	confirm_btn.pressed.connect(_on_confirm)

func populate(units: Array) -> void:
	bid_values = [0, 0, 0]
	bids_active = [false, false, false]

	for i in range(3):
		card_slots[i].setup(units[i])
		bid_inputs[i].min_value = 0
		bid_inputs[i].value = 0
		bid_inputs[i].editable = true

	_refresh_ui()

func _on_bid_changed(value: float, index: int) -> void:
	bid_values[index] = int(value)
	bids_active[index] = value >= GameState.current_draft_units[index].floor_cost
	_refresh_ui()

func _refresh_ui() -> void:
	var active_count = bids_active.count(true)
	bids_used_label.text = "%d/2 bids used" % active_count

	var total = bid_values.reduce(func(a, b): return a + b, 0)
	total_label.text = "Total bid: %d / %d gold" % [total, GameState.gold[0]]

	# Lock third input if 2 bids already active
	for i in range(3):
		if active_count >= 2 and not bids_active[i]:
			bid_inputs[i].editable = false
		else:
			bid_inputs[i].editable = true

	# Validate confirm
	var valid = true
	if total > GameState.gold[0]: valid = false
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
