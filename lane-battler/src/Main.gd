# src/Main.gd
# Root scene controller.
# Owns no game logic — only wires EventBus signals to the correct UI panels.
extends Node


@onready var status_panel:       Control = $StatusPanel
@onready var board_panel:        Control = $BoardPanel
@onready var bench_panel:        Control = $BenchPanel
@onready var draft_panel:        Control = $DraftPanel
@onready var action_panel:       Control = $ActionPanel
@onready var combat_log:         Control = $CombatLog
@onready var match_over_label:   Label   = $MatchOverLabel
@onready var step_label:         Label   = $StepLabel
@onready var continue_btn:       Button  = $ContinueBtn


func _ready() -> void:
	# ── EventBus connections ──────────────────────────────────────────────────
	# All signal connections go through EventBus, never directly to systems.
	EventBus.waiting_for_player.connect(_on_waiting_for_player)
	EventBus.plans_revealed.connect(_on_plans_revealed)
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.match_over.connect(_on_match_over)
	EventBus.resolution_update.connect(_on_resolution_update)

	# Economy / board changes just refresh the persistent UI
	EventBus.vp_changed.connect(func(_id, _v): _refresh_ui())
	EventBus.gold_changed.connect(func(_id, _v): _refresh_ui())
	EventBus.board_changed.connect(func(): _refresh_ui())
	EventBus.bench_changed.connect(func(_id): _refresh_ui())
	EventBus.phase_changed.connect(func(_p): _refresh_ui())

	# ── Initial UI state ──────────────────────────────────────────────────────
	match_over_label.hide()
	step_label.hide()
	continue_btn.hide()
	draft_panel.hide()
	action_panel.hide()

	continue_btn.text = "Continue"
	continue_btn.pressed.connect(func():
		step_label.hide()
		continue_btn.hide()
		RoundManager.submit_continue()
	)

	# ── Start the match ───────────────────────────────────────────────────────
	RoundManager.start_match(_load_roster_a(), _load_roster_b())


# ── Persistent UI refresh ─────────────────────────────────────────────────────

func _refresh_ui() -> void:
	status_panel.refresh()
	board_panel.refresh()
	bench_panel.refresh()


# ── EventBus handlers ─────────────────────────────────────────────────────────

func _on_waiting_for_player(phase: int) -> void:
	_refresh_ui()
	draft_panel.hide()
	action_panel.hide()
	continue_btn.hide()
 
	match phase:
		RoundManager.Phase.DRAFT_BIDDING:
			step_label.hide()
			draft_panel.populate(GameState.current_draft_units)
			draft_panel.show()
 
		RoundManager.Phase.MANEUVER_STEP:
			step_label.hide()
			action_panel.show_maneuver_step()
			action_panel.show()
 
		RoundManager.Phase.DEPLOY_STEP:
			step_label.hide()
			action_panel.show_deploy_step()
			action_panel.show()
 
		RoundManager.Phase.PLAN_REVEAL, \
		RoundManager.Phase.RESOLVE_RETREATS, \
		RoundManager.Phase.RESOLVE_SHIFTS, \
		RoundManager.Phase.RESOLVE_MUSTERS, \
		RoundManager.Phase.RESOLVE_DEPLOYS, \
		RoundManager.Phase.RESOLVE_COMBAT, \
		RoundManager.Phase.RESOLVE_REWARDS:
			continue_btn.show()

func _on_resolution_update(message: String) -> void:
	step_label.text = message
	step_label.show()

func _on_plans_revealed(player_plan: Dictionary, bot_plan: Dictionary) -> void:
	_refresh_ui()

func _on_combat_resolved(_log: Array) -> void:
	_refresh_ui()
	# CombatLog panel can connect to EventBus.combat_resolved directly
	# for a richer display; for graybox it's just the print output.


func _on_match_over(winner: int) -> void:
	_refresh_ui()
	draft_panel.hide()
	action_panel.hide()
	match winner:
		0:  match_over_label.text = "Player wins!"
		1:  match_over_label.text = "Bot wins!"
		-1: match_over_label.text = "Draw (timeout)"
	match_over_label.show()


# ── Rosters ───────────────────────────────────────────────────────────────────
# Rename these to match your actual .tres filenames once they're in place.

func _load_roster_a() -> Array:
	return [
		preload("res://data/units/t1_basic_striker.tres"),
		preload("res://data/units/t1_basic_striker.tres"),
		preload("res://data/units/t1_basic_bulwark.tres"),
		preload("res://data/units/t1_basic_bulwark.tres"),
		preload("res://data/units/t1_basic_tactician.tres"),
	]


func _load_roster_b() -> Array:
	return [
		preload("res://data/units/t1_basic_tactician.tres"),
		preload("res://data/units/t1_basic_tactician.tres"),
		preload("res://data/units/t1_basic_striker.tres"),
		preload("res://data/units/t1_basic_bulwark.tres"),
		preload("res://data/units/t1_basic_bulwark.tres"),
	]
