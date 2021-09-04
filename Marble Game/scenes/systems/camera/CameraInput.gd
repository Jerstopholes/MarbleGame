extends Node


# This script houses the Input settings for the Camera. 

# These exported strings can be used to overide the default input action names.
export (String) var LookLeft = "*left*"
export (String) var LookRight = "*right*"
export (String) var LookUp = "*up*"
export (String) var LookDown = "*down*"
export (String) var ZoomKey = "*zoom_keyboard*"
export (String) var ZoomButton = "*zoom_gamepad*"
export (String) var CenterCameraKey = "*center_camera_keyboard*"
export (String) var CenterCameraButton = "*center_camera_button*"

onready var _camera = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready():
	
	# Check if we have selected to generate inputs automatically, and if we have,
	# then generate the inputs!
	if _camera.InputsToUse == _camera.Inputs.GENERATE_FOR_ME:
		_create_input_mappings()


func _create_input_mappings():
	# we check for every input to prevent possible errors/duplicates.
	# a little cumbersome but worth it in the end!
	
	# first check for horizontal rotation, add it if it doesn't exist
	# left
	if !InputMap.has_action(LookLeft):
		InputMap.add_action(LookLeft, 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_2
		event.axis_value = -1.0
		InputMap.action_add_event(LookLeft, event)
	
	# right
	if !InputMap.has_action(LookRight):
		InputMap.add_action(LookRight, 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_2
		event.axis_value = 1.0
		InputMap.action_add_event(LookRight, event)
	
	# now check for the vertical rotation, if it doesn't exist add it
	# up
	if !InputMap.has_action(LookUp):
		InputMap.add_action(LookUp, 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_3
		event.axis_value = -1.0
		InputMap.action_add_event(LookUp, event)
	
	# down
	if !InputMap.has_action(LookDown):
		InputMap.add_action(LookDown, 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_3
		event.axis_value = 1.0
		InputMap.action_add_event(LookDown, event)
	
	
	# now add zoom support
	# controller
	if !InputMap.has_action(ZoomButton):
		InputMap.add_action(ZoomButton, 0.5)
		var event = InputEventJoypadButton.new()
		event.button_index = 10
		InputMap.action_add_event(ZoomButton, event)
	
	# mouse
	if !InputMap.has_action(ZoomKey):
		InputMap.add_action(ZoomKey, 0.5)
		var event = InputEventKey.new()
		event.scancode = KEY_C
		InputMap.action_add_event(ZoomKey, event)
		
	# Recentering camera
	if !InputMap.has_action(CenterCameraKey):
		InputMap.add_action(CenterCameraKey)
		var event = InputEventKey.new()
		event.scancode = KEY_V
		InputMap.action_add_event(CenterCameraKey, event)
		
	if !InputMap.has_action(CenterCameraButton):
		InputMap.add_action(CenterCameraButton)
		var event = InputEventJoypadButton.new()
		event.button_index = 9
		InputMap.action_add_event(CenterCameraButton, event)
