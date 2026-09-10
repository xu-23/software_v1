class_name BattleUnit
extends RefCounted

var id: String
var display_name: String
var team: String
var unit_type: String
var class_id: String
var max_hp: int
var base_shield: int
var attack: int
var move_range: int
var attack_range: int
var true_damage: bool
var sprite_path: String

var current_hp: int
var current_shield: int
var grid_pos: Vector2i
var has_moved := false
var has_acted := false
var is_dead := false


static func from_data(data: Dictionary, spawn: Vector2i) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.id = str(data.id)
	unit.display_name = str(data.name)
	unit.team = str(data.team)
	unit.unit_type = str(data.unit_type)
	unit.class_id = str(data.class_id)
	unit.max_hp = int(data.max_hp)
	unit.base_shield = int(data.shield)
	unit.attack = int(data.attack)
	unit.move_range = int(data.move_range)
	unit.attack_range = int(data.attack_range)
	unit.true_damage = bool(data.true_damage)
	unit.sprite_path = str(data.get("sprite", ""))
	unit.current_hp = unit.max_hp
	unit.current_shield = unit.base_shield
	unit.grid_pos = spawn
	return unit


func reset_turn() -> void:
	if not is_dead:
		has_moved = false
		has_acted = false


func mark_dead_if_needed() -> bool:
	if current_hp <= 0:
		current_hp = 0
		is_dead = true
	return is_dead


func snapshot() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"team": team,
		"unit_type": unit_type,
		"class_id": class_id,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"current_shield": current_shield,
		"attack": attack,
		"move_range": move_range,
		"attack_range": attack_range,
		"true_damage": true_damage,
		"grid_pos": grid_pos,
		"has_moved": has_moved,
		"has_acted": has_acted,
		"is_dead": is_dead
	}
