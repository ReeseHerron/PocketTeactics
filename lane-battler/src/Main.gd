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
@onready var plans_reveal_label: Label   = $PlansRevealLabel


func _ready() -> void:
	# ── EventBus connections ──────────────────────────────────────────────────
	# All signal connections go through EventBus, never directly to systems.
	EventBus.waiting_for_player.connect(_on_waiting_for_player)
	EventBus.plans_revealed.connect(_on_plans_revealed)
	EventBus.combat_resolved.connect(_on_combat_resolved)
	EventBus.match_over.connect(_on_match_over)

	# Economy / board changes just refresh the persistent UI
	EventBus.vp_changed.connect(func(_id, _v): _refresh_ui())
	EventBus.gold_changed.connect(func(_id, _v): _refresh_ui())
	EventBus.board_changed.connect(func(): _refresh_ui())
	EventBus.bench_changed.connect(func(_id): _refresh_ui())
	EventBus.phase_changed.connect(func(_p): _refresh_ui())

	# ── Initial UI state ──────────────────────────────────────────────────────
	match_over_label.hide()
	plans_reveal_label.hide()
	draft_panel.hide()
	action_panel.hide()

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

	match phase:
		RoundManager.Phase.DRAFT_BIDDING:
			draft_panel.populate(GameState.current_draft_units)
			draft_panel.show()

		RoundManager.Phase.MANEUVER_STEP:
			action_panel.show_maneuver_step()
			action_panel.show()

		RoundManager.Phase.DEPLOY_STEP:
			action_panel.show_deploy_step()
			action_panel.show()


func _on_plans_revealed(player_plan: Dictionary, bot_plan: Dictionary) -> void:
	# Show a brief reveal label. Resolution starts immediately behind it —
	# for a polished version, gate RoundManager on a signal from the UI here.
	_refresh_ui()
	plans_reveal_label.show()
	await get_tree().create_timer(1.2).timeout
	plans_reveal_label.hide()


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
