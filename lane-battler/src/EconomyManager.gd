class_name EconomyManager
extends RefCounted

func apply_lane_rewards(lane_results: Array) -> void:
	for result in lane_results:
		var cid = result.claimant
		if cid == -1:
			continue
		if result.gold_reward > 0:
			GameState.add_gold(cid, result.gold_reward)
		if result.vp_reward > 0:
			GameState.add_vp(cid, result.vp_reward)

func apply_base_income() -> void:
	GameState.add_gold(0, 2)
	GameState.add_gold(1, 2)
