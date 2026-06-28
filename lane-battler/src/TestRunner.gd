extends Node

func _ready() -> void:
	print("TestRunner ready")
	await get_tree().process_frame  # let autoloads finish
	run_headless_match()

func run_headless_match() -> void:
	print("Connecting signals...")
	RoundManager.waiting_for_player.connect(_on_waiting_for_player)
	RoundManager.round_log_entry.connect(_on_log)
	GameState.match_over.connect(_on_match_over)

	print("Loading rosters...")
	var roster_a = [
		preload("res://data/units/striker_a.tres"),
		preload("res://data/units/striker_a.tres"),
		preload("res://data/units/tactician_a.tres"),
		preload("res://data/units/bulwark_a.tres"),
		preload("res://data/units/bulwark_a.tres"),
	]
	var roster_b = [
		preload("res://data/units/tactician_a.tres"),
		preload("res://data/units/tactician_a.tres"),
		preload("res://data/units/striker_a.tres"),
		preload("res://data/units/bulwark_a.tres"),
		preload("res://data/units/bulwark_a.tres"),
	]

	print("Starting match...")
	RoundManager.start_match(roster_a, roster_b)
	
var player_bot: Bot = Bot.new() 

func _on_waiting_for_player(phase) -> void:
	match phase:
		RoundManager.Phase.DRAFT_BIDDING:
			# Let player_bot score the draft for player 0
			player_bot.prepare_draft_bids_for_player(GameState.current_draft_units, 0)
			var bids = player_bot.get_draft_bids()
			RoundManager.submit_player_bids(bids)

		RoundManager.Phase.ACTION_COMMIT:
			player_bot.prepare_action_for_player(0)
			var action = player_bot.get_action()
			RoundManager.submit_player_action(action)

func _on_log(entry: Dictionary) -> void:
	print("LOG: ", entry)

func _on_match_over(winner: int) -> void:
	print("")
	print("========== MATCH OVER ==========")
	print("Winner: %s" % ("Player" if winner == 0 else "Bot"))
	print("Final VP    — Player: %d  Bot: %d" % [GameState.vp[0], GameState.vp[1]])
	print("Final Gold  — Player: %d  Bot: %d" % [GameState.gold[0], GameState.gold[1]])
	print("Rounds played: %d" % GameState.round_number)
