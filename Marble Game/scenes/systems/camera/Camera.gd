extends Spatial

# We use these enums to set certain parameters in the editor more easily. 
# They specifiy which input devices to use by default, how we want the _camera
# to interact with the world, how we should follow the player, and whether
# or not we want to use the default input mappings or specify our own.
enum mode { MOUSE, GAMEPAD }
enum collide_mode { INSTANT_FORWARD_SMOOTH_BACK, INSTANT_FORWARD_AND_BACK }
enum follow_mode { SMOOTH_INTERPOLATION, INSTANT }
enum inputs { GENERATE_FOR_ME, SPECIFY_MY_OWN }

# These exported properties are used to set adjustable parameters, such as the player
# to follow, smoothing speeds, collision responses, input sensitivites, the FOV for the _camera(s), 
# environment to use on the _camera(s), how many _frames to count before collision, and whether the 
# player can switch to first-person mode.
export (NodePath) var player
export (follow_mode) var camera_follow_mode = follow_mode.SMOOTH_INTERPOLATION
export (float, 0.001, 0.1) var follow_smooth_speed = 0.08
export (collide_mode) var collision_response = collide_mode.INSTANT_FORWARD_SMOOTH_BACK
export (float, 0.001, 0.1) var CollisionSmoothSpeed = 0.05
export (float, 0, 2.0) var camera_collision_offset = 0.25
export (mode) var input_method = mode.MOUSE
export (inputs) var inputs_to_use = inputs.GENERATE_FOR_ME
export (float) var mouse_sensitivity = 10.0
export (float) var gamepad_sensitivity = 2.75
export (float, 0.01, 0.5) var gamepad_deadzone = 0.25
export (float, 0.01, 179) var camera_fov = 70.0
export (Environment) var environment
export (float, 0.01, 2.0) var springarm_sphere_radius = 1.0
export (float, 0.01, 10.0) var springarm_sphere_margin = 1.0
export (int) var frames_to_wait_before_collision = 5
export (bool) var enable_first_person = true


# Private helper variables.

# Stores the _camera's z value and the z value of the _target.
var _cam_z : float = 0.0
var _tar_z : float = 0.0

# Used to determine _camera movement input.
var _cam_up : float = 0.0
var _cam_right : float = 0.0
var _cam_stick : Vector2

# Lets us know whether or not rotation occured on this frame.
var _rotation : bool = false

# Determines if the mouse is captured
var _is_mouse_captured : bool = false

# Stores and accesses the different values for the _camera's available distances and tracks
# what the current _camera distance is.
var _distance_array : Array
var _distance_index : int = 0
var _camera_distance : float = 0

# Offsets for the wall detector and the _camera.
var _wall_detector_offset : Vector3
var _camera_offset : Vector3

# Used to determine what the SpringArm length should be, what the hit length of the SpringArm is, 
# and whether or not the SpringArm is actually hitting something.
var _hit_length : float = 0
var _spring_length : float = 0
var _springarm_is_hitting : bool = false

# Lets us know if the player is stuck on a wall, and whether or not the _camera is detecting a hit behind itself
# using the detection SpringArm on its back end.
var _is_touching_wall : bool = false
var _hit_from_behind : bool = false
var _angle : float = 0

# Used for centering the camera
var _centering_camera : bool = false

# The stored player
var _player : Node

# The amount of frames that have elapsed since the player last provided _camera input.
# Used to allow collisions when the player has stopped rotating the _camera but there's still an 
# object obscuring the player. 
var _frames : int = 0


# Node reference variables.
onready var _x_axis = $XRotater
onready var _camera = $XRotater/Camera
onready var _springarm = $XRotater/SpringArm
onready var _target = $XRotater/SpringArm/Target
onready var _distance_markers = $DistanceMarkers
onready var _wall_detector = $WallDetector
onready var _cam_input = $CameraInput
onready var _detection_springarm = $XRotater/Camera/DetectionSpring
onready var _fp_cam = $XRotater/FirstPersonCamera/Camera


# Called when the node enters the scene tree for the first time.
func _ready():
	# Determine the Camera's input mode.
	if input_method == mode.MOUSE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_is_mouse_captured = true
	elif input_method == mode.GAMEPAD:
		# The cursor isn't captured but we also don't want to show it until the player wants it shown
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		_is_mouse_captured = false
		
	# Get the distance marker's Z values to add to our _distance_array array
	for i in range(_distance_markers.get_child_count()):
		_distance_array.append(_distance_markers.get_child(i).transform.origin.z)
		
		# Hide the markers
		_distance_markers.get_child(i).hide()
		
	# Variable to store what distance we are currently set to
	_distance_index = 0
	
	# Assign the other _camera properties
	_camera.environment = environment
	_camera.fov = camera_fov
	
	# Assign the player to _player
	if player:
		_player = get_node(player)
	else:
		# Tell the user what went wrong
		printerr("NO PLAYER ASSIGNED!")
		printerr("Please make sure you assign a player for the _camera to follow.")
		# Force a crash
		get_tree().quit()
	
	# Assign the SpringArm properties
	_springarm.spring_length = _distance_array[0] 
	_springarm.shape.set_radius(springarm_sphere_radius)
	_springarm.shape.set_margin(springarm_sphere_margin)
	
	# Add these nodes to be excluded by the spring arm to prevent false positive collisions
	_springarm.add_excluded_object(_wall_detector)
	_springarm.add_excluded_object(_player)
	
	# Do the same for the detection spring on the _camera
	_detection_springarm.add_excluded_object(_wall_detector)
	_detection_springarm.add_excluded_object(_player)
	
	# Ensure the _target and _camera are positioned properly
	_target.transform.origin.z = _distance_array[0] - camera_collision_offset
	_camera_distance = _target.transform.origin.z
	_camera.transform.origin.z = _camera_distance

	# Ensure we don't inherit rotational data from the player
	self.set_as_toplevel(true)
	_wall_detector.set_as_toplevel(true)
	
	# Store the offset of the wall detector to the player node
	_wall_detector_offset = _wall_detector.global_transform.origin - _player.global_transform.origin
	
	# Store the offset of the _camera and player node
	_camera_offset = self.global_transform.origin - _player.global_transform.origin
	
	# Hide the _target visual aid
	_target.hide()

# Allows mouse input
func _input(event):
	if input_method == mode.MOUSE:
		if event is InputEventMouseMotion and _is_mouse_captured:
		
			# Store the upwards movement
			_cam_up = deg2rad(event.relative.y * -1)

			# Store the sideways movement
			_cam_right = deg2rad(event.relative.x)
			
			# We moved this frame, so set _rotation to true
			_rotation = true
			
			# Cancel centering the _camera if needed
			_centering_camera = false

# Called every frame.
func _process(delta):
	
	# Updates the basic _camera settings
	_update_camera_settings()
	
	# Updates the positioning of the _camera
	_update_camera_position()
	
	# Checks for _camera input
	_check_input()
		
	# Rotates the _camera
	_rotate_camera(delta)
	
	# Checks for occlusion/collision
	_occlusion_check()
	

# Updates the _camera settings
func _update_camera_settings():
	# Update the _springarm's length to match the current specified distance.
	_springarm.spring_length = _distance_array[_distance_index]
	
	# Store the length of the _springarm and its hit length
	_spring_length = _springarm.spring_length
	_hit_length = _springarm.get_hit_length()
	
	# Update the _target's position so that it is always offset from the actual length of the _springarm.
	_target.transform.origin.z = _hit_length - camera_collision_offset
	
	# Update the wall detector's position to the player node's, plus the specified offset.
	_wall_detector.global_transform.origin = _player.global_transform.origin + _wall_detector_offset

	# Store the _camera and _target z positions for easier comparisons
	_cam_z = _camera.transform.origin.z
	_tar_z = _target.transform.origin.z
	
	# Count the number of _frames since rotation last happened. This is done to ensure the _camera doesn't clip to 
	# geometry between itself and the player UNLESS there is geometry close enough to the _camera, or the player has
	# stopped moving the _camera. 
	if not _rotation:
		if _frames >= frames_to_wait_before_collision:
			_frames = frames_to_wait_before_collision
		else:
			_frames += 1
	else:
		# Rotation has happened so reset the counter
		_frames = 0

# Updates the positioning of the _camera
func _update_camera_position():
	# Determine the follow mode of the _camera
	if camera_follow_mode == follow_mode.SMOOTH_INTERPOLATION:
		# Smoothly lerp the position of the _camera to the player node
		global_transform.origin = lerp(global_transform.origin, _player.global_transform.origin + _camera_offset, 0.08)
	else:
		# Instantly move the _camera to match the player node's position
		global_transform.origin = _player.global_transform.origin
		
	# Check to see if the player has prompted recentering
	if _centering_camera:
		_center_camera()

# Checks the input of the _camera
func _check_input():
	# Allow/disallow mouse input
	if Input.is_action_just_pressed("ui_cancel"):
		_is_mouse_captured = not _is_mouse_captured
		if _is_mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			input_method = mode.MOUSE
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			input_method = mode.GAMEPAD

	# Change the distance of the _camera
	if ((Input.is_action_just_pressed(_cam_input.zoom_key) and input_method == mode.MOUSE or 
			Input.is_action_just_pressed(_cam_input.zoom_button) and input_method == mode.GAMEPAD) and
			not _springarm_is_hitting):
				
		# Change the current distance of the _camera
		_change_distance()
		
	# Recenter the _camera
	if ((Input.is_action_just_pressed(_cam_input.center_camera_key) and input_method == mode.MOUSE or 
			Input.is_action_just_pressed(_cam_input.center_camera_button) and input_method == mode.GAMEPAD) and
			not _fp_cam.current):
				
		# Allow centering of the _camera
		_centering_camera = true

# Rotates the _camera
func _rotate_camera(delta):
	if input_method == mode.MOUSE:
		if _rotation:
			rotate_y(-_cam_right * mouse_sensitivity * delta)
			_x_axis.rotate_x(_cam_up * mouse_sensitivity * delta)
			_rotation = false
	elif input_method == mode.GAMEPAD:
		# Store the right movement
		_cam_right = Input.get_action_strength(_cam_input.look_left) - Input.get_action_strength(_cam_input.look_right)
		
		# Store the up movement
		_cam_up = Input.get_action_strength(_cam_input.look_up) - Input.get_action_strength(_cam_input.look_down)
		
		# Create an input vector containing the input information
		_cam_stick = Vector2(_cam_right, _cam_up)
		
		# Apply the deadzone
		_cam_stick = _apply_gamepad_deadzone(_cam_stick, 0.25)
		
		# Rotation happened if our _cam_stick vector length is not equal to zero
		if _cam_stick.length() != 0:
			_rotation = true
			_centering_camera = false
		else:
			_rotation = false
			
		# Apply the rotation to the _camera
		rotate_y(_cam_stick.x * gamepad_sensitivity * delta)
		_x_axis.rotate_x(_cam_stick.y * gamepad_sensitivity * delta)
		
	# Clamp the _camera's rotation so that we can't infinitely rotate on the X axis
	var x_rotation = _x_axis.rotation_degrees
	x_rotation.x = clamp(x_rotation.x, -70, 70)
	_x_axis.rotation_degrees = x_rotation

# Checks for collisions and occlusions
func _occlusion_check():
	
	# Lets us know if the _camera should be colliding with geometry by comparing the hit length 
	# of the spring arm to its current specified length.
	if _hit_length < _spring_length:
		_springarm_is_hitting = true
	else:
		_springarm_is_hitting = false
	
	# We determine if something is behind the _camera by comparing the hit length of the "detection spring"
	# to its specified length. If it's shorter than the specified length, the _camera hit something located 
	# behind it, so let us know that the hit was detected.
	if _detection_springarm.get_hit_length() < _detection_springarm.spring_length:
		_hit_from_behind = true
	else:
		_hit_from_behind = false

	# We determine if the Camera is colliding by comparing the Target's Z value to the Camera's.
	# If it's less than the Camera's, AND the SpringArm itself is _springarm_is_hitting, we know we are 
	# colliding with something.
	if _tar_z < _cam_z and _springarm_is_hitting:
		
		# We now want to ensure that the _camera SHOULD be colliding against the found geometry.
		# We don't want to collide while we're rotating the _camera, UNLESS the detection spring
		# finds geometry, or the player has stopped rotating the _camera for the amount of _frames
		# that are specified to wait. When either is true, pull the Camera forward.
		if _frames >= frames_to_wait_before_collision or _hit_from_behind:
			_camera_distance = lerp(_camera_distance, _tar_z, 0.4)
	else:
		# Determine the _camera's collision response strategy
		if collision_response == collide_mode.INSTANT_FORWARD_SMOOTH_BACK:
			# Smoothly lerp back to the _target's position (great for adventure games).
			_camera_distance = lerp(_camera_distance, _tar_z, CollisionSmoothSpeed)
		else:
			# Snap back instantly (great for action games like third-person shooters)
			_camera_distance = _tar_z
			
	# Update the camera's Z value with _camera_distance
	_camera.transform.origin.z = _camera_distance

# Changes the current distance of the _camera
func _change_distance():
	# Check if we are in First Person mode. If we are, we want to switch out of it before increasing the 
	# distance of the _camera!
	if _fp_cam.current:
		_switch_camera()
	else:
		_distance_index += 1
	
	# If we reach the end of _distance_array, but allow switching to first-person mode, 
	# start back at the beginning of _distance_array but also call _switch_camera().
	if _distance_index == _distance_array.size() and enable_first_person:
		_switch_camera()
		_distance_index = 0
		
	# If we reach the end of the _distance_array, start back at the beginning.
	elif _distance_index >= _distance_array.size():
		_distance_index = 0
		
func _switch_camera():
	# Flip which cameras are active
	if _camera.current:
		_fp_cam.make_current()
	elif _fp_cam.current:
		_camera.make_current()

# Rotates the _camera to face the same way as the player node
func _center_camera():

	# Center the _camera only if the rotation _angle doesn't match the _target's
	if rotation_degrees.y != _player.rotation_degrees.y:
		_angle = lerp(_angle, 0.8, 0.01)
		if rotation_degrees.y < _player.rotation_degrees.y:
			rotation_degrees.y += _angle
		elif rotation_degrees.y > _player.rotation_degrees.y:
			rotation_degrees.y -= _angle

	# Stop centering the _camera and match the rotation exactly once we are close enough to
	# the _target's rotation
	if is_equal_approx(stepify(rotation_degrees.y, 0.75), stepify(_player.rotation_degrees.y, 0.75)):
		_angle = 0
		rotation_degrees.y = _player.rotation_degrees.y
		_centering_camera = false
	
# We use this function to apply the deadzone for gamepads
func _apply_gamepad_deadzone(var input_vector, var deadzone):
	if input_vector.length() < deadzone:
		input_vector = Vector2.ZERO
	else:
		input_vector = input_vector.normalized() * ((input_vector.length() - deadzone) / (1 - deadzone))
		
	# Return the input vector
	return input_vector
	
# Lets us know when the player is touching a wall.
func _on_WallDetector_body_entered(body):
	if not body.is_in_group("exclude"):
		_is_touching_wall = true

# Lets us know when the player has stopped touching a wall.
func _on_WallDetector_body_exited(body):
	if not body.is_in_group("exclude"):
		_is_touching_wall = false



