extends Node2D

const INTERACT_DISTANCE := 64.0

var time_left := 180.0
var has_supply := false
var seal_active := false
var mission_done := false
var mistakes := 0

@onready var player: CharacterBody2D = $World/Player
@onready var order_label: Label = $UI/Panel/Stack/Orders
@onready var call_label: Label = $UI/Panel/Stack/Call
@onready var status_label: Label = $UI/Panel/Stack/Status
@onready var prompt_label: Label = $UI/Prompt
@onready var result_label: Label = $UI/Result

func _ready() -> void:
	player.interact_pressed.connect(_try_interact)
	result_label.hide()
	_refresh_ui()

func _process(delta: float) -> void:
	if mission_done:
		return
	time_left -= delta
	if time_left <= 0.0:
		_finish("Mission failed: time expired.")
	_refresh_ui()

func _try_interact() -> void:
	if mission_done:
		return

	var target := _closest_interactable()
	if target == null:
		prompt_label.text = "No target nearby"
		return

	match target.kind:
		"supply":
			if target.is_real:
				has_supply = true
				target.mark_used()
				prompt_label.text = "Real supply box retrieved."
			else:
				mistakes += 1
				target.mark_used()
				prompt_label.text = "Fake supply box. Seija left the wrong seal color."
		"seal":
			seal_active = true
			target.mark_used()
			prompt_label.text = "Seal device activated."
		"exit":
			if has_supply and seal_active:
				_finish("Mission complete.")
			else:
				mistakes += 1
				prompt_label.text = "Objective incomplete."
		"hazard":
			mistakes += 1
			prompt_label.text = "Hazard confirmed. Sagume's 'safe west corridor' was reversed."

	_refresh_ui()

func _closest_interactable() -> Interactable:
	var closest: Interactable = null
	var closest_distance := INTERACT_DISTANCE
	for node in get_tree().get_nodes_in_group("interactable"):
		var interactable := node as Interactable
		if interactable == null or interactable.used:
			continue
		var distance := player.global_position.distance_to(interactable.global_position)
		if distance < closest_distance:
			closest = interactable
			closest_distance = distance
	return closest

func _refresh_ui() -> void:
	order_label.text = "Written Order\n- Retrieve the real supply box\n- Activate the seal device\n- Evacuate through the north exit"
	call_label.text = "Sagume Call\n\"The west corridor is safe. The red supply box is genuine.\"\n\nSeija Noise\n[Caller: Sagume?] \"Ignore the seal.\""
	status_label.text = "Time: %03d  Supply: %s  Seal: %s  Mistakes: %d" % [
		maxi(0, int(ceil(time_left))),
		"yes" if has_supply else "no",
		"on" if seal_active else "off",
		mistakes
	]

func _finish(message: String) -> void:
	mission_done = true
	result_label.text = "%s\nTime left: %ds\nMistakes: %d" % [message, int(maxf(0.0, time_left)), mistakes]
	result_label.show()
