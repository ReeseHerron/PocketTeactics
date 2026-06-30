# src/TestRunner.gd
# Headless match runner — simulates both players using Bot AI.
# Attach this to a scene instead of Main.tscn to run a full match in the
# output log with no UI interaction needed.
#
# Useful for validating rule logic after any systems change.
extends Node


var _player_bot: Bot = Bot.new()  # second Bot instance simulates the human player


func _ready() -> void:
	print("TestRunner ready")
	await get_tree().process_frame  # let autoloads finish _ready()
	_run()


func _run() -> void:
	print("Connecting signals via EventBus...")
	EventBus.waiting_for_player.connect(_on_waiting_for_player)
	EventBus.match_over.connect(_on_match_over)

	# Use the renamed .tres files — update if your filenames differ
	var roster_a := [
		preload("res://data/units/t1_basic_striker.tres"),
		preload("res://data/units/t1_basic_striker.tres"),
		preload("res://data/units/t1_basic_bulwark.tres"),
		preload("res://data/units/t1_basic_bulwark.tres"),
		preload("res://data/units/t1_basic_tactician.tres"),
	]
	var roster_b := [
		preload("res://data/units/t1_basic_tactician.tres"),
		preload("res://data/units/t1_basic_tactician.tres"),
		preload("res://data/units/t1_basic_striker.tres"),
		preload("res://data/units/t1_basic_bulwark.tres"),
		preload("res://data/units/t1_basic_bulwark.tres"),
	]

	print("Starting headless match...")
	RoundManager.start_match(roster_a, roster_b)


func _on_waiting_for_player(phase: int) -> void:
	match phase:

		RoundManager.Phase.DRAFT_BIDDING:
			_player_bot.prepare_draft_bids(GameState.current_draft_units, 0)
			RoundManager.submit_player_bids(_player_bot.get_draft_bids())

		RoundManager.Phase.MANEUVER_STEP:
			var maneuver := _player_bot.choose_maneuver(0)
			RoundManager.submit_player_maneuver(maneuver)

		RoundManager.Phase.DEPLOY_STEP:
			# Use the maneuver the player bot just chose to compute the projected board
			var projected := ActionExecutor.project_board_after_maneuver(
				0, _player_bot.get_maneuver()
			)
			var deploy := _player_bot.choose_deploy(0, projected)
			RoundManager.submit_player_deploy(deploy)
		
		# Auto-continue through all resolution steps — no human needed in headless mode	
		RoundManager.Phase.PLAN_REVEAL, \
		RoundManager.Phase.RESOLVE_RETREATS, \
		RoundManager.Phase.RESOLVE_SHIFTS, \
		RoundManager.Phase.RESOLVE_MUSTERS, \
		RoundManager.Phase.RESOLVE_DEPLOYS, \
		RoundManager.Phase.RESOLVE_COMBAT, \
		RoundManager.Phase.RESOLVE_REWARDS:
			RoundManager.submit_continue()


func _on_match_over(winner: int) -> void:
	print("")
	print("========== MATCH OVER ==========")
	match winner:
		0:  print("Winner: Player")
		1:  print("Winner: Bot")
		-1: print("Winner: Draw (timeout)")
	print("Final VP    — Player: %d  Bot: %d" % [GameState.vp[0], GameState.vp[1]])
	print("Final Gold  — Player: %d  Bot: %d" % [GameState.gold[0], GameState.gold[1]])
	print("Rounds played: %d" % GameState.round_number)
