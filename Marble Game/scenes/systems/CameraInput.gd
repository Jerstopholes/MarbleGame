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
	if !InputMap.has_action("*left*"):
		InputMap.add_action("*left*", 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_2
		event.axis_value = -1.0
		InputMap.action_add_event("*left*", event)
	
	# right
	if !InputMap.has_action("*right*"):
		InputMap.add_action("*right*", 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_2
		event.axis_value = 1.0
		InputMap.action_add_event("*right*", event)
	
	# now check for the vertical rotation, if it doesn't exist add it
	# up
	if !InputMap.has_action("*up*"):
		InputMap.add_action("*up*", 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_3
		event.axis_value = -1.0
		InputMap.action_add_event("*up*", event)
	
	# down
	if !InputMap.has_action("*down*"):
		InputMap.add_action("*down*", 0.5)
		var event = InputEventJoypadMotion.new()
		event.axis = JOY_AXIS_3
		event.axis_value = 1.0
		InputMap.action_add_event("*down*", event)
	
	
	# now add zoom support
	# controller
	if !InputMap.has_action("*zoom_gamepad*"):
		InputMap.add_action("*zoom_gamepad*", 0.5)
		var event = InputEventJoypadButton.new()
		event.button_index = 10
		InputMap.action_add_event("*zoom_gamepad*", event)
	
	# mouse
	if !InputMap.has_action("*zoom_keyboard*"):
		InputMap.add_action("*zoom_keyboard*", 0.5)
		var event = InputEventKey.new()
		event.scancode = KEY_C
		InputMap.action_add_event("*zoom_keyboard*", event)
