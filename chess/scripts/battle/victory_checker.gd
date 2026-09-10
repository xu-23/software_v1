class_name VictoryChecker
extends RefCounted


static func check(registry: BattleUnitRegistry) -> String:
	if registry.living("enemy").is_empty():
		return "victory"
	if registry.living("player").is_empty():
		return "defeat"
	return ""
