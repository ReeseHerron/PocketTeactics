# src/UnitInstance.gd
# Runtime unit. Wraps a UnitData resource and tracks mutable state.
# Created when a unit is won from draft. Destroyed when might reaches 0.
class_name UnitInstance
extends RefCounted


var data: UnitData
var current_might: int
var owner_id: int        # 0 = player, 1 = bot

# v4: true when this unit entered the board from bench this round.
# Fresh units can claim uncontested lanes but cannot claim after winning combat.
# Cleared at round start by GameState.clear_fresh_flags().
var is_fresh: bool = false

func _init(unit_data: UnitData, owner: int) -> void:
	data = unit_data
	current_might = unit_data.get_max_might()
	owner_id = owner


# ── Combat ────────────────────────────────────────────────────────────────────

func is_alive() -> bool:
	return current_might > 0


func take_damage(amount: int) -> void:
	current_might = max(0, current_might - amount)


# ── Healing ───────────────────────────────────────────────────────────────────

func heal(amount: int) -> void:
	# v4 bench recovery: heals by a fixed amount per round, capped at max.
	# Retreat does NOT heal immediately — bench recovery does at round start.
	current_might = min(data.get_max_might(), current_might + amount)


func heal_to_full() -> void:
	# Used only when creating a fused result unit (always starts at full might).
	current_might = data.get_max_might()


# ── Fusion ────────────────────────────────────────────────────────────────────

func can_fuse_with(other: UnitInstance) -> bool:
	# Match on fusion_group_id and tier — no string comparison.
	# UnitRegistry.get_fusion_result() handles finding the correct result resource.
	return (
		data.fusion_group_id != 0
		and data.fusion_group_id == other.data.fusion_group_id
		and data.tier == other.data.tier
		and data.tier < 3
	)


# ── Display ───────────────────────────────────────────────────────────────────

func display_str() -> String:
	return "T%d %s (%d/%d)" % [
		data.tier,
		data.display_name,
		current_might,
		data.get_max_might(),
	]
