# ActionPanel.gd
extends VBoxContainer

var selected_unit: UnitInstance = null
var selected_lane: int = -1

@onready var deploy_btn = $DeployBtn
@onready var retreat_btn = $RetreatBtn
@onready var shift_btn = $ShiftBtn
@onready var hold_btn = $HoldBtn
@onready var unit_picker = $UnitPicker      # OptionButton
@onready var lane_picker = $LanePicker      # OptionButton
@onready var confirm_btn = $ConfirmBtn

func _ready() -> void:
	hold_btn.pressed.connect(_submit_hold)
	confirm_btn.pressed.connect(_on_confirm)
	deploy_btn.pressed.connect(func(): _set_mode(0))
	retreat_btn.pressed.connect(func(): _set_mode(1))
	shift_btn.pressed.connect(func(): _set_mode(2))

var current_mode: int = -1

func refresh() -> void:
	# Populate unit picker with bench units for deploy/retreat
	unit_picker.clear()
	for unit in GameState.bench[0]:
		unit_picker.add_item("T%d %s" % [unit.data.tier, unit.data.display_name])
	
	# Enable/disable buttons based on what's possible
	deploy_btn.disabled = GameState.bench[0].is_empty()
	var has_board = false
	for lane in range(3):
		if GameState.board[0][lane] != null:
			has_board = true
	retreat_btn.disabled = not has_board
	shift_btn.disabled = not has_board

func _set_mode(mode: int) -> void:
	current_mode = mode
	# Repopulate pickers based on mode
	unit_picker.clear()
	lane_picker.clear()
	match mode:
		0:  # Deploy
			for unit in GameState.bench[0]:
				unit_picker.add_item("T%d %s" % [unit.data.tier, unit.data.display_name])
			for lane in range(3):
				if GameState.board[0][lane] == null:
					lane_picker.add_item(["Left", "Center", "Right"][lane])
		1:  # Retreat
			for lane in range(3):
				if GameState.board[0][lane] != null:
					unit_picker.add_item("T%d %s in %s" % [
						GameState.board[0][lane].data.tier,
						GameState.board[0][lane].data.display_name,
						["Left", "Center", "Right"][lane]
					])
		2:  # Shift
			for lane in range(3):
				if GameState.board[0][lane] != null:
					unit_picker.add_item("T%d %s in %s" % [
						GameState.board[0][lane].data.tier,
						GameState.board[0][lane].data.display_name,
						["Left", "Center", "Right"][lane]
					])
			for lane in range(3):
				if GameState.board[0][lane] == null:
					lane_picker.add_item(["Left", "Center", "Right"][lane])

func _submit_hold() -> void:
	RoundManager.submit_player_action({"type": 4})
	hide()

func _on_confirm() -> void:
	match current_mode:
		0:  # Deploy
			var unit = GameState.bench[0][unit_picker.selected]
			var lane = _lane_name_to_index(lane_picker.get_item_text(lane_picker.selected))
			RoundManager.submit_player_action({
				"type": 0,
				"unit": unit,
				"target_lane": lane
			})
		1:  # Retreat
			var lane = _board_unit_index_to_lane(unit_picker.selected)
			var unit = GameState.board[0][lane]
			RoundManager.submit_player_action({
				"type": 1,
				"unit": unit
			})
		2:  # Shift
			var lane = _board_unit_index_to_lane(unit_picker.selected)
			var unit = GameState.board[0][lane]
			var target = _lane_name_to_index(lane_picker.get_item_text(lane_picker.selected))
			RoundManager.submit_player_action({
				"type": 2,
				"unit": unit,
				"target_lane": target
			})
	hide()

func _lane_name_to_index(name: String) -> int:
	match name:
		"Left": return 0
		"Center": return 1
		"Right": return 2
	return -1

func _board_unit_index_to_lane(picker_index: int) -> int:
	var count = 0
	for lane in range(3):
		if GameState.board[0][lane] != null:
			if count == picker_index:
				return lane
			count += 1
	return -1
