extends Area2D
class_name Interactable

@export var object_id := ""
@export var display_name := ""
@export var kind := ""
@export var is_real := true

var used := false

func mark_used() -> void:
	used = true
	modulate = Color(0.45, 0.45, 0.45, 1.0)
