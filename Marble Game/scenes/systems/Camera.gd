extends Spatial

# These enums help us out in the editor.
enum InputMode { MOUSE, GAMEPAD }
enum UpdateStrategy { SMOOTH, INSTANT }
export (NodePath) var FollowTarget
export (UpdateStrategy) var CameraUpdateStrategy = UpdateStrategy.SMOOTH
export (float, 0.001, 0.1) var SmoothSpeed = 0.03
export (InputMode) var CameraInputMode = InputMode.MOUSE
export (float, 0.01, 3.0) var TargetOffset = 1.0
export (float, 0.01, 170) var CameraFOV = 70.0
export (Environment) var CameraEnvironment
export (Vector3) var WallDetectorOffset = Vector3(0, 1, 0)
export (float, 0.01, 5.0) var SpringArmSphereRadius = 1
export (float, 0.01, 10.0) var SpringArmSphereMargin = 1.0
export (float) var MouseSensitivity = 10.0
export (int) var MaxFrameCount = 5

# Local variables
var cam_up : float = 0.0
var cam_right : float = 0.0
var cam_stick_input : Vector2
var rotation_happened : bool = false
var mouse_captured : bool = false
var follow_target : Node
var d : int = 0
var distances : Array
var frames : int = 0
var probe : Array
var wall_array : Array

# Node reference variables
onready var x_rotater = $XRotater
onready var camera = $XRotater/Camera
onready var springarm = $XRotater/SpringArm
onready var target = $XRotater/SpringArm/Target
onready var distance_markers = $XRotater/DistanceMarkers
onready var wall_detector = $XRotater/WallDetector
onready var wall_detector_shape = $XRotater/WallDetector/WallDetectorShape

# Called when the node enters the scene tree for the first time.
func _ready():
	# Determine the Camera's input mode.
	if CameraInputMode == InputMode.MOUSE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true
	elif CameraInputMode == InputMode.GAMEPAD:
		# The cursor isn't captured but we also don't want to show it until the player wants it shown
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		mouse_captured = false
		
	# Get the distance marker's Z values to add to our distances array
	for i in range(distance_markers.get_child_count()):
		distances.append(distance_markers.get_child(i).transform.origin.z)
		
		# Hide the helper meshes
		distance_markers.get_child(i).hide()
		
	# Variable to store what distance we are currently set to
	d = 0
	
	# Assign the other camera properties
	camera.environment = CameraEnvironment
	camera.fov = CameraFOV
	
	# Assign the follow target
	if FollowTarget:
		follow_target = get_node(FollowTarget)
	else:
		printerr("NO FOLLOW TARGET ASSIGNED!")
		# Force a crash
		get_tree().quit()
	
	# Assign the SpringArm properties
	springarm.spring_length = distances[0] 
	springarm.shape.set_radius(SpringArmSphereRadius)
	springarm.shape.set_margin(SpringArmSphereMargin)
	springarm.add_excluded_object(wall_detector)
	springarm.add_excluded_object(wall_detector_shape)
	springarm.add_excluded_object(follow_target)
	
	# Ensure the target and camera are positioned properly
	target.transform.origin.z = distances[0] - TargetOffset
	camera.transform.origin.z = target.transform.origin.z

	# Ensure we don't inherit rotational data from the player
	self.set_as_toplevel(true)
	
	# Set the WallDetector as top level so that we can properly position it 
	# to the follow target's origin
	wall_detector.set_as_toplevel(true)
	
	# Hide the target mesh
	target.hide()

# Allows mouse input
func _input(event):
	if CameraInputMode == InputMode.MOUSE:
		if event is InputEventMouseMotion and mouse_captured:
		
			# Handle upwards movement
			cam_up = deg2rad(event.relative.y * -1)

			# Handle sideways movement
			cam_right = deg2rad(event.relative.x)
			rotation_happened = true

# Called every frame.
func _process(delta):
	# Update the wall detector's position to the follow target's, plus the specified offset.
	wall_detector.global_transform.origin = follow_target.global_transform.origin + WallDetectorOffset
	
	# Update the springarm's length to match the current specified distance.
	springarm.spring_length = distances[d]
	
	# Update the target's position so that it is always offset from the actual length of the springarm.
	target.transform.origin.z = springarm.get_hit_length() - TargetOffset
	
	# Count the number of frames since rotation last happened. This is done to ensure the camera doesn't clip to 
	# geometry between itself and the player UNLESS there is geometry close enough to the camera, or the player has
	# stopped moving the camera. 
	if not rotation_happened:
		if frames >= MaxFrameCount:
			frames = MaxFrameCount
		else:
			frames += 1
	else:
		# Rotation has happened so reset the counter
		frames = 0

	# Allow/disallow mouse input
	if Input.is_action_just_pressed("ui_cancel"):
		mouse_captured = not mouse_captured
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			CameraInputMode = InputMode.MOUSE
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			CameraInputMode = InputMode.GAMEPAD

	# Change the distance of the camera
	if Input.is_action_just_pressed("key_zoom") and CameraInputMode == InputMode.MOUSE or Input.is_action_just_pressed("gamepad_zoom") and CameraInputMode == InputMode.GAMEPAD:
		_change_distance()
		
	# Rotate the camera
	if CameraInputMode == InputMode.MOUSE:
		if rotation_happened:
			self.rotate_y(-cam_right * MouseSensitivity * delta)
			x_rotater.rotate_x(cam_up * MouseSensitivity * delta)
			rotation_happened = false
	elif CameraInputMode == InputMode.GAMEPAD:
		# Store the right movement
		cam_right = Input.get_action_strength("cam_look_left") - Input.get_action_strength("cam_look_right")
		
		# Store the up movement
		cam_up = Input.get_action_strength("cam_look_up") - Input.get_action_strength("cam_look_down")
		
		# Create an input vector containing the input information
		cam_stick_input = Vector2(cam_right, cam_up)
		
		# Apply the deadzone
		cam_stick_input = _apply_gamepad_deadzone(cam_stick_input, 0.25)
		
		# Rotation happened if our cam_stick_input vector length is greater than zero
		if cam_stick_input.length() > 0:
			rotation_happened = true
		else:
			rotation_happened = false
		
		# Apply the rotation
		self.rotate_y(cam_stick_input.x * MouseSensitivity * delta)
		x_rotater.rotate_x(cam_stick_input.y * MouseSensitivity * delta)
		
	# Clamp the camera's rotation
	var x_rotation = x_rotater.rotation_degrees
	x_rotation.x = clamp(x_rotation.x, -90, 90)
	x_rotater.rotation_degrees = x_rotation

	# Store the camera and target z positions for easier comparisons
	var cam_z = camera.transform.origin.z
	var tar_z = target.transform.origin.z
	
	# Get the Target node's current Z value. If it's less than the Camera, we know we are technically clipping, 
	# so check if either the probe array is NOT empty or the mouse has stopped moving to respond to collisions.
	if tar_z < cam_z:
		if frames >= MaxFrameCount or not probe.empty():
			camera.transform.origin.z = target.transform.origin.z
	else:
		# Determine the camera's update strategy
		if CameraUpdateStrategy == UpdateStrategy.SMOOTH:
			# Smoothly lerp back to the starting position.
			camera.transform.origin.z = lerp(camera.transform.origin.z, 
			target.transform.origin.z,
			SmoothSpeed)
		else:
			# Snap back instantly (good for action games)
			camera.transform.origin.z = target.transform.origin.z

# Changes the current distance of the camera
func _change_distance():
	# Increase the value of d by 1
	d += 1
	
	# If we reach the end of the distances array, start back at the beginning.
	if d >= distances.size():
		d = 0

# We use this function to apply the deadzone for gamepads
func _apply_gamepad_deadzone(var input_vector, var deadzone):
	if input_vector.length() < deadzone:
		input_vector = Vector2.ZERO
	else:
		input_vector = input_vector.normalized() * ((input_vector.length() - deadzone) / (1 - deadzone))
		
	# Return the input vector
	return input_vector
	
# Allows collision if bodies are close enough to the camera
func _on_DetectionSphere_body_entered(body):
	if not body.is_in_group("noclip"):
		
		# Check to make sure this body doesn't exist in the array.
		if probe.find(body) == -1:
			# Add the body to the array
			probe.append(body)
			#print("Added " + str(body) + " at index [" + str(probe.size()-1) + "]")

# Removes bodies from the probe array to disallow collisions until otherwise specified.
func _on_DetectionSphere_body_exited(body):
	if not body.is_in_group("noclip"):
		
		# Check the probe array to make sure it is not empty.
		if probe.size() != -1:
			# Search for the body and remove it
			var body_to_remove = probe.find(body)
			if body_to_remove != -1:
				probe.remove(body_to_remove)
				#print("Removed " + str(body) + " from index [" + str(probe.size()) + "]")

# Lets us know when the player is touching a wall.
func _on_WallDetector_body_entered(body):
	if not body.is_in_group("player"):
	
		# Check to make sure this body doesn't exist in the array.
		if wall_array.find(body) == -1:
			# Add the body to the array
			wall_array.append(body)
			#print(wall_array)

# Lets us know when the player has stopped touching a wall.
func _on_WallDetector_body_exited(body):
	if not body.is_in_group("player"):
		
		# Check the wall array to make sure it is not empty.
		if wall_array.size() != -1:
			# Search for the body and remove it
			var body_to_remove = wall_array.find(body)
			if body_to_remove != -1:
				wall_array.remove(body_to_remove)
				#print(wall_array)
