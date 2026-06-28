extends Node

@onready var board_ui = $Board
@onready var draft_panel = $DraftPanel
@onready var action_panel = $ActionPanel
@onready var extort_prompt = $ExtortPrompt
@onready var combat_log = $CombatLog

func _ready() -> void:
	# Connect RoundManager signals to UI
	RoundManager.phase_changed.connect(_on_phase_changed)
	RoundManager.waiting_for_player.connect(_on_waiting_for_player)
	RoundManager.round_log_entry.connect(_on_log_entry)

	GameState.state_changed.connect(board_ui.refresh)
	GameState.vp_changed.connect(board_ui.update_vp)
	GameState.gold_changed.connect(board_ui.update_gold)
	GameState.match_over.connect(_on_match_over)

	# Start match with placeholder rosters
	var roster_a = _load_roster_a()
	var roster_b = _load_roster_b()
	RoundManager.start_match(roster_a, roster_b)

func _on_waiting_for_player(phase) -> void:
	match phase:
		RoundManager.Phase.DRAFT_BIDDING:
			draft_panel.populate(GameState.current_draft_units)
			draft_panel.show()
		RoundManager.Phase.ACTION_COMMIT:
			action_panel.refresh_available_actions()
			action_panel.show()
		RoundManager.Phase.EXTORT_PROMPT:
			extort_prompt.show_prompt()
			
func _on_phase_changed(new_phase: RoundManager.Phase) -> void:
	print("Phase changed to: ", RoundManager.Phase.keys()[new_phase])

func _on_log_entry(entry: Dictionary) -> void:
	combat_log.append_entry(entry)

func _on_match_over(winner: int) -> void:
	if winner == 0:
		$VictoryScreen.show_win()
	else:
		$VictoryScreen.show_loss()

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
