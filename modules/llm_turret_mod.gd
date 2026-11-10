## Name: Новая Турель
## Description: Сгенерированная турель
## Tags: turret, defense
extends Node3D

func get_module_id() -> String:
	return "llm_turret_mod"

func initialize(_ctx: Dictionary) -> bool:
	return true

func cleanup() -> void:
	pass
