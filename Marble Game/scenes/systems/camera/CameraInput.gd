extends Node


# This script houses the Input settings for the Camera. 

# These exported strings can be used to overide the default input action names.
export (String) var look_left = "*left*"
export (String) var look_right = "*right*"
export (String) var look_up = "*up*"
export (String) var look_down = "*down*"
export (String) var zoom_key = "*zoom_keyboard*"
export (String) var zoom_button = "*zoom_gamepad*"
export (String) var center_camera_key = "*center_camera_keyboard*"
export (String) var center_camera_button = "*center_camera_button*"

# Get the camera
onready var _camera = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready():
	
	# Check if we have selected to generate inputs automatically, and if we have,
	# then generate the inputs!
	if _camera.inputs_to_use == _camera.inputs.GENERATE_FOR_ME:
		_create_input_mappings()


func _create_input_mappings():
	# we check for every input to prevent possible errors/duplicates.
	# a little cumbersome but worth it in the end!
	
	# first check for horizontal rotation, add it if it doesn't exist
	# left
	if !InputMap.has_action(look_left):
		InputMap.add_action(look_left, 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_2
		event.axis_value = -1.0
		InputMap.action_add_event(look_left, event)
	
	# right
	if !InputMap.has_action(look_right):
		InputMap.add_action(look_right, 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_2
		event.axis_value = 1.0
		InputMap.action_add_event(look_right, event)
	
	# now check for the vertical rotation, if it doesn't exist add it
	# up
	if !InputMap.has_action(look_up):
		InputMap.add_action(look_up, 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_3
		event.axis_value = -1.0
		InputMap.action_add_event(look_up, event)
	
	# down
	if !InputMap.has_action(look_down):
		InputMap.add_action(look_down, 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_3
		event.axis_value = 1.0
		InputMap.action_add_event(look_down, event)
	
	
	# now add zoom support
	# controller
	if !InputMap.has_action(zoom_button):
		InputMap.add_action(zoom_button, 0.5)
		var event = InputEventJoypadButton.new()
		event.button_index = 10
		InputMap.action_add_event(zoom_button, event)
	
	# mouse
	if !InputMap.has_action(zoom_key):
		InputMap.add_action(zoom_key, 0.5)
		var event = InputEventKey.new()
		event.scancode = KEY_C
		InputMap.action_add_event(zoom_key, event)
		
	# Recentering camera
	if !InputMap.has_action(center_camera_key):
		InputMap.add_action(center_camera_key)
		var event = InputEventKey.new()
		event.scancode = KEY_V
		InputMap.action_add_event(center_camera_key, event)
		
	if !InputMap.has_action(center_camera_button):
		InputMap.add_action(center_camera_button)
		var event = InputEventJoypadButton.new()
		event.button_index = 9
		InputMap.action_add_event(center_camera_button, event)
