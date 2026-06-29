# src/ActionPanel.gd
# Two-step planning UI for the v4 hidden planning phase.
#
# Step 1 — MANEUVER_STEP: shows available maneuvers as buttons.
#   Player picks one → submitted → RoundManager moves to DEPLOY_STEP.
#
# Step 2 — DEPLOY_STEP: shows projected board after maneuver, then deploy options.
#   Player picks one → submitted → RoundManager moves to PLAN_REVEAL.
#
# Expected scene tree:
#   ActionPanel (Control)
#   ├── PhaseLabel         (Label)   — "Choose Maneuver" / "Choose Deploy"
#   ├── ProjectedBoard     (Label)   — board preview; hidden during maneuver step
#   └── OptionsContainer   (VBoxContainer) — filled dynamically each step
extends Control


@onready var phase_label:       Label        = $PhaseLabel
@onready var projected_board:   Label        = $ProjectedBoard
@onready var options_container: VBoxContainer = $OptionsContainer

# Stores the maneuver the player chose so we can compute the projected board
# for the deploy step and pass it to RoundManager.
var _committed_maneuver: Dictionary = {}

# Locked once the player presses any option button — prevents double-submission.
var _submitted: bool = false


# ── Public API (called by Main) ───────────────────────────────────────────────

func show_maneuver_step() -> void:
	_submitted = false
	_committed_maneuver = {}
	phase_label.text = "Choose Maneuver"
	projected_board.hide()
	_clear_options()
	_build_maneuver_options()


func show_deploy_step() -> void:
	_submitted = false
	phase_label.text = "Choose Deploy"
	var projected := ActionExecutor.project_board_after_maneuver(0, _committed_maneuver)
	projected_board.text = _format_projected_board(projected)
	projected_board.show()
	_clear_options()
	_build_deploy_options(projected)


# ── Option builders ───────────────────────────────────────────────────────────

func _build_maneuver_options() -> void:
	# SKIP — always available
	_add_button("Skip (do nothing)", func():
		_submit_maneuver({ "type": ActionExecutor.ManeuverType.SKIP })
	)

	# RETREAT — one option per board unit
	for lane in range(3):
		var unit: UnitInstance = GameState.board[0][lane]
		if unit == null:
			continue
		var captured_unit := unit
		var captured_lane := lane
		_add_button(
			"Retreat  %s  from %s" % [unit.data.display_name, _lane_name(lane)],
			func():
				_submit_maneuver({
					"type": ActionExecutor.ManeuverType.RETREAT,
					"unit": captured_unit,
				})
		)

	# SHIFT — one option per valid adjacent move
	for lane in range(3):
		var unit: UnitInstance = GameState.board[0][lane]
		if unit == null:
			continue
		for adj in [lane - 1, lane + 1]:
			if adj < 0 or adj >= 3:
				continue
			if GameState.board[0][adj] != null:
				continue
			# Capture loop variables explicitly — closures share the loop scope
			var captured_unit := unit
			var captured_from := lane
			var captured_to   := adj
			_add_button(
				"Shift  %s:  %s → %s" % [
					unit.data.display_name,
					_lane_name(lane),
					_lane_name(adj)
				],
				func():
					_submit_maneuver({
						"type":        ActionExecutor.ManeuverType.SHIFT,
						"unit":        captured_unit,
						"target_lane": captured_to,
					})
			)

	# MUSTER — only when the player has no board units
	if not GameState.has_any_board_unit(0):
		for unit in GameState.bench[0]:
			for lane in range(3):
				var captured_unit := unit
				var captured_lane := lane
				_add_button(
					"Muster  %s  to %s" % [unit.data.display_name, _lane_name(lane)],
					func():
						_submit_maneuver({
							"type":        ActionExecutor.ManeuverType.MUSTER,
							"unit":        captured_unit,
							"target_lane": captured_lane,
						})
				)


func _build_deploy_options(projected: Array) -> void:
	# SKIP — always available
	_add_button("Skip deploy", func():
		_submit_deploy({ "type": ActionExecutor.DeployType.SKIP })
	)

	# DEPLOY — each bench unit into each empty lane on the projected board
	for unit in GameState.bench[0]:
		for lane in range(3):
			if projected[0][lane] != null:
				continue  # lane occupied after our maneuver
			var captured_unit := unit
			var captured_lane := lane
			_add_button(
				"Deploy  %s  to %s" % [unit.data.display_name, _lane_name(lane)],
				func():
					_submit_deploy({
						"type":        ActionExecutor.DeployType.DEPLOY,
						"unit":        captured_unit,
						"target_lane": captured_lane,
					})
			)


# ── Submission ────────────────────────────────────────────────────────────────

func _submit_maneuver(maneuver: Dictionary) -> void:
	if _submitted:
		return
	_submitted = true
	_committed_maneuver = maneuver
	hide()
	RoundManager.submit_player_maneuver(maneuver)


func _submit_deploy(deploy: Dictionary) -> void:
	if _submitted:
		return
	_submitted = true
	hide()
	RoundManager.submit_player_deploy(deploy)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()


func _add_button(label: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(callback)
	options_container.add_child(btn)


func _format_projected_board(projected: Array) -> String:
	# Text preview shown during the deploy step so the player can see the
	# effect of their chosen maneuver before committing to a deploy.
	var lines := ["── Your board after maneuver ──"]
	for lane in range(3):
		var p_unit: UnitInstance = projected[0][lane]
		var b_unit: UnitInstance = projected[1][lane]
		lines.append("  %s  |  You: %-20s  Bot: %s" % [
			_lane_name(lane),
			p_unit.display_str() if p_unit else "Empty",
			b_unit.display_str() if b_unit else "Empty",
		])
	return "\n".join(lines)


func _lane_name(lane: int) -> String:
	match lane:
		0: return "Left Flank"
		1: return "Center"
		2: return "Right Flank"
	return "?"
