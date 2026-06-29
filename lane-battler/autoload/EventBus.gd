# autoload/EventBus.gd
# Global signal hub. Nothing emits directly to another node.
# Systems emit here. UI listens here.
# Add this as an autoload in Project > Project Settings > Autoload BEFORE RoundManager.
extends Node


# ── Economy ──────────────────────────────────────────────────────────────────
signal gold_changed(player_id: int, new_gold: int)
signal vp_changed(player_id: int, new_vp: int)


# ── Phase / Game flow ────────────────────────────────────────────────────────
signal phase_changed(new_phase: int)
signal waiting_for_player(phase: int)   # UI should show the relevant input panel
signal match_over(winner_id: int)       # -1 = draw / timeout


# ── Draft ────────────────────────────────────────────────────────────────────
signal draft_units_revealed(units: Array)
signal draft_resolved(results: Array)   # Array of { unit_index, winner, player_bid, bot_bid }


# ── Fusion ───────────────────────────────────────────────────────────────────
signal fusion_occurred(player_id: int, new_unit: UnitInstance)


# ── v4 Hidden Planning ───────────────────────────────────────────────────────
# Emitted when a player locks in their maneuver choice (before deploy step).
signal maneuver_locked(player_id: int)
# Emitted when a player locks in their deploy choice (plan is now fully sealed).
signal deploy_locked(player_id: int)
# Emitted once both players have locked full plans — triggers the reveal animation.
signal plans_revealed(player_plan: Dictionary, bot_plan: Dictionary)


# ── Board / Bench ────────────────────────────────────────────────────────────
signal board_changed()
signal bench_changed(player_id: int)


# ── Combat / Resolution ──────────────────────────────────────────────────────
signal combat_resolved(log: Array)          # Array of lane result dicts
signal lane_rewards_applied(results: Array) # same lane result dicts, after rewards
