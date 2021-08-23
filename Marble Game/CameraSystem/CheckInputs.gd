
extends Node

# this script checks for the inputs needed for this scene to work.
# if it doesn't find them, it adds them, along with the deadzones, 
# which you can tweak through the deadzone variables here.

export (float) var ControllerDeadZone = 0.25
export (float) var MouseDeadZone = 0.1

# Called when the game starts
func _ready():
	
	# we check for every input to prevent possible errors/duplicates.
	# a little cumbersome but worth it in the end!
	
	# first check for horizontal rotation, add it if it doesn't exist
	# left
	if !InputMap.has_action("cam_look_left"):
		InputMap.add_action("cam_look_left", ControllerDeadZone)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_2
		event.axis_value = -1.0
		InputMap.action_add_event("cam_look_left", event)
	
	# right
	if !InputMap.has_action("cam_look_right"):
		InputMap.add_action("cam_look_right", ControllerDeadZone)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_2
		event.axis_value = 1.0
		InputMap.action_add_event("cam_look_right", event)
	
	# now check for the vertical rotation, if it doesn't exist add it
	# up
	if !InputMap.has_action("cam_look_up"):
		InputMap.add_action("cam_look_up", ControllerDeadZone)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_3
		event.axis_value = -1.0
		InputMap.action_add_event("cam_look_up", event)
	
	# down
	if !InputMap.has_action("cam_look_down"):
		InputMap.add_action("cam_look_down", ControllerDeadZone)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_3
		event.axis_value = 1.0
		InputMap.action_add_event("cam_look_down", event)
	
	
	# now add zoom support
	# controller
	if !InputMap.has_action("gamepad_zoom"):
		InputMap.add_action("gamepad_zoom", ControllerDeadZone)
		var event = InputEventJoypadButton.new()
		event.button_index = 10
		InputMap.action_add_event("gamepad_zoom", event)
	
	# mouse
	if !InputMap.has_action("key_zoom"):
		InputMap.add_action("key_zoom", MouseDeadZone)
		var event = InputEventKey.new()
		event.scancode = KEY_C
		InputMap.action_add_event("key_zoom", event)
