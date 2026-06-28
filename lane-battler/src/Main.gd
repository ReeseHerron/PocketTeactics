extends Node

@onready var status_panel = $StatusPanel
@onready var board_panel = $BoardPanel
@onready var draft_panel = $DraftPanel
@onready var action_panel = $ActionPanel
@onready var combat_log = $CombatLog

func _ready() -> void:
	RoundManager.waiting_for_player.connect(_on_waiting_for_player)
	GameState.state_changed.connect(_refresh_ui)
	GameState.vp_changed.connect(func(a, b): _refresh_ui())
	GameState.gold_changed.connect(func(a, b): _refresh_ui())
	GameState.match_over.connect(_on_match_over)

	var roster_a = _load_roster_a()
	var roster_b = _load_roster_b()
	RoundManager.start_match(roster_a, roster_b)

func _refresh_ui() -> void:
	status_panel.refresh()
	board_panel.refresh()

func _on_waiting_for_player(phase) -> void:
	_refresh_ui()
	match phase:
		RoundManager.Phase.DRAFT_BIDDING:
			draft_panel.populate(GameState.current_draft_units)
			draft_panel.show()
		RoundManager.Phase.ACTION_COMMIT:
			action_panel.refresh()
			action_panel.show()

func _on_match_over(winner: int) -> void:
	_refresh_ui()
	var msg = "Player wins!" if winner == 0 else "Bot wins!"
	# Show a simple label or popup
	$MatchOverLabel.text = msg
	$MatchOverLabel.show()

func _load_roster_a() -> Array:
	return [
		preload("res://data/units/striker_a.tres"),
		preload("res://data/units/striker_a.tres"),
		preload("res://data/units/tactician_a.tres"),
		preload("res://data/units/bulwark_a.tres"),
		preload("res://data/units/bulwark_a.tres"),
	]

func _load_roster_b() -> Array:
	return [
		preload("res://data/units/tactician_a.tres"),
		preload("res://data/units/tactician_a.tres"),
		preload("res://data/units/striker_a.tres"),
		preload("res://data/units/bulwark_a.tres"),
		preload("res://data/units/bulwark_a.tres"),
	]
