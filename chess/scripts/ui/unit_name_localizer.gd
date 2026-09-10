class_name UnitNameLocalizer
extends RefCounted

const UNIT_NAMES := {
	"Vanguard": "先锋",
	"Archer": "弓箭手",
	"Ranger": "游侠",
	"Verdant Guard": "翠绿卫士",
	"Earth Warden": "大地守卫",
	"Raider": "掠夺者",
	"Marksman": "神射手",
	"Sentry": "哨兵",
	"Flamecaster": "火焰术士"
}


static func localized(standard_name: String) -> String:
	return str(UNIT_NAMES.get(standard_name, standard_name))
