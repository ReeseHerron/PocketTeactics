# src/StatusPanel.gd
# Persistent HUD showing round number, VP, gold for both players.
# Connects through EventBus only — never directly to GameState signals.
#
# Expected scene tree:
#   StatusPanel (VBoxContainer)
#   ├── RoundLabel   (Label)
#   ├── PhaseLabel   (Label)
#   ├── PlayerVP     (Label)
#   ├── BotVP        (Label)
#   ├── PlayerGold   (Label)
#   └── BotGold      (Label)
extends VBoxContainer


@onready var round_label:  Label = $RoundLabel
@onready var phase_label:  Label = $PhaseLabel
@onready var player_vp:    Label = $PlayerVP
@onready var bot_vp:       Label = $BotVP
@onready var player_gold:  Label = $PlayerGold
@onready var bot_gold:     Label = $BotGold


func _ready() -> void:
	# Connect through EventBus — refresh fires whenever economy or phase changes
	EventBus.vp_changed.connect(func(_id, _v): refresh())
	EventBus.gold_changed.connect(func(_id, _v): refresh())
	EventBus.phase_changed.connect(func(_p): refresh())
	refresh()


func refresh() -> void:
	round_label.text  = "Round %d" % GameState.round_number
	phase_label.text  = _phase_name(RoundManager.current_phase)
	player_vp.text    = "Player VP:   %d / 5" % GameState.vp[0]
	bot_vp.text       = "Bot VP:      %d / 5" % GameState.vp[1]
	player_gold.text  = "Player Gold: %d / %d" % [GameState.gold[0], GameState.GOLD_CAP]
	bot_gold.text     = "Bot Gold:    %d / %d" % [GameState.gold[1], GameState.GOLD_CAP]


func _phase_name(phase: int) -> String:
	match phase:
		RoundManager.Phase.ROUND_START:      return "Round Start"
		RoundManager.Phase.BENCH_RECOVERY:   return "Bench Recovery"
		RoundManager.Phase.DRAFT_REVEAL:     return "Draft — Reveal"
		RoundManager.Phase.DRAFT_BIDDING:    return "Draft — Bidding"
		RoundManager.Phase.DRAFT_RESOLVE:    return "Draft — Resolve"
		RoundManager.Phase.FUSION_CHECK:     return "Fusion Check"
		RoundManager.Phase.MANEUVER_STEP:    return "Planning — Maneuver"
		RoundManager.Phase.DEPLOY_STEP:      return "Planning — Deploy"
		RoundManager.Phase.PLAN_REVEAL:      return "Plan Reveal"
		RoundManager.Phase.RESOLVE_RETREATS: return "Resolve — Retreats"
		RoundManager.Phase.RESOLVE_SHIFTS:   return "Resolve — Shifts"
		RoundManager.Phase.RESOLVE_MUSTERS:  return "Resolve — Musters"
		RoundManager.Phase.RESOLVE_DEPLOYS:  return "Resolve — Deploys"
		RoundManager.Phase.RESOLVE_COMBAT:   return "Resolve — Combat"
		RoundManager.Phase.RESOLVE_REWARDS:  return "Resolve — Rewards"
		RoundManager.Phase.VICTORY_CHECK:    return "Victory Check"
		RoundManager.Phase.MATCH_OVER:       return "Match Over"
	return "—"
