class_name DamageCalculator
extends RefCounted


static func apply(attacker: BattleUnit, target: BattleUnit) -> Dictionary:
	if attacker == null or target == null or attacker.attack < 0:
		push_error("[DamageCalculator.apply] invalid combatant or attack value")
		return {}
	var result := {
		"attacker_id": attacker.id,
		"target_id": target.id,
		"damage_value": attacker.attack,
		"shield_before": target.current_shield,
		"hp_before": target.current_hp,
		"shield_broken": false,
		"is_true_damage": attacker.true_damage
	}
	if attacker.true_damage:
		target.current_hp = maxi(target.current_hp - attacker.attack, 0)
	elif target.current_shield > 0:
		target.current_shield = maxi(target.current_shield - attacker.attack, 0)
		result.shield_broken = result.shield_before > 0 and target.current_shield == 0
	else:
		target.current_hp = maxi(target.current_hp - attacker.attack, 0)
	target.mark_dead_if_needed()
	result["shield_after"] = target.current_shield
	result["hp_after"] = target.current_hp
	result["target_dead"] = target.is_dead
	return result
