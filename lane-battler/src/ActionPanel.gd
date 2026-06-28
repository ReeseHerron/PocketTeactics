extends Control

var selected_unit: UnitInstance = null
var selected_target: int = -1

@onready var deploy_btn = $DeployBtn
@onready var retreat_btn = $RetreatBtn
@onready var shift_btn = $ShiftBtn
@onready var swap_btn = $SwapBtn
@onready var hold_btn = $HoldBtn

func _ready() -> void:
	deploy_btn.pressed.connect(_on_deploy)
	retreat_btn.pressed.connect(_on_retreat)
	shift_btn.pressed.connect(_on_shift)
	swap_btn.pressed.connect(_on_swap)
	hold_btn.pressed.connect(_on_hold)

func refresh_available_actions() -> void:
	var has_bench = not GameState.bench[0].is_empty()
	var has_board = false
	var has_empty_board = false
	for lane in range(3):
		if GameState.board[0][lane] != null: has_board = true
		else: has_empty_board = true

	deploy_btn.disabled = not (has_bench and has_empty_board)
	retreat_btn.disabled = not has_board
	shift_btn.disabled = not has_board
	swap_btn.disabled = true  # enabled contextually after unit selection
	hold_btn.disabled = false

func _on_hold() -> void:
	RoundManager.submit_player_action({ "type": ActionExecutor.ActionType.HOLD })
	hide()

func _on_deploy() -> void:
	# Open lane picker, then on pick:
	# RoundManager.submit_player_action({type: DEPLOY, unit: selected_unit, target_lane: lane})
	pass

func _on_retreat() -> void:
	# Open unit picker from board, then:
	# RoundManager.submit_player_action({type: RETREAT, unit: selected_unit})
	pass

func _on_shift() -> void:
	pass

func _on_swap() -> void:
	pass
