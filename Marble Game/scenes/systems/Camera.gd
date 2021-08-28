extends Spatial

# These enums help us out in the editor.
enum Mode { MOUSE, GAMEPAD }
enum CollideMode { PULL_FORWARD_SMOOTH_BACK, INSTANT_FORWARD_AND_BACK }
enum Inputs { GENERATE_FOR_ME, SPECIFY_MY_OWN }
export (NodePath) var FollowTarget
export (CollideMode) var CollisionResponse = CollideMode.PULL_FORWARD_SMOOTH_BACK
export (float, 0.001, 0.1) var SmoothSpeed = 0.03
export (Mode) var InputMethod = Mode.MOUSE
export (Inputs) var InputsToUse = Inputs.GENERATE_FOR_ME
export (float) var MouseSensitivity = 10.0
export (float, 0.01, 0.5) var GamepadDeadzone = 0.25
export (float) var GamepadSensitivity = 2.5
export (float, 0, 2.0) var CameraCollisionOffset = 0.25
export (float, 0.01, 170) var CameraFOV = 70.0
export (Environment) var CameraEnvironment
export (float, 0.01, 2.0) var SpringArmSphereRadius = 1
export (float, 0.01, 10.0) var SpringArmSphereMargin = 1.0
export (int) var MaxFrameCount = 5


# Local variables
var cam_z : float = 0
var tar_z : float = 0
var cam_up : float = 0
var cam_right : float = 0
var cam_stick_input : Vector2
var rotation_happened : bool = false
var mouse_captured : bool = false
var follow_target : Node
var d : int = 0
var distances : Array
var frames : int = 0
var probe : Array
var wall_array : Array
var wall_detector_offset : Vector3
var hit_length : float = 0
var spring_length : float = 0
var clipping : bool = false

# Node reference variables
onready var x_rotater = $XRotater
onready var camera = $XRotater/Camera
onready var springarm = $XRotater/SpringArm
onready var target = $XRotater/SpringArm/Target
onready var distance_markers = $XRotater/DistanceMarkers
onready var wall_detector = $XRotater/WallDetector
onready var wall_detector_shape = $XRotater/WallDetector/WallDetectorShape
onready var CameraInput = $CameraInput

# Called when the node enters the scene tree for the first time.
func _ready():
	# Determine the Camera's input mode.
	if InputMethod == Mode.MOUSE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true
	elif InputMethod == Mode.GAMEPAD:
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
		print_debug("Please make sure you assign a follow target.")
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
	target.transform.origin.z = distances[0] - CameraCollisionOffset
	camera.transform.origin.z = target.transform.origin.z

	# Ensure we don't inherit rotational data from the player
	self.set_as_toplevel(true)
	
	# Set the walldetector as toplevel
	wall_detector.set_as_toplevel(true)
	
	# Store the offset of the wall detector to the follow target
	wall_detector_offset = wall_detector.global_transform.origin - follow_target.global_transform.origin
	
	# Hide the target mesh
	target.hide()

# Allows mouse input
func _input(event):
	if InputMethod == Mode.MOUSE:
		if event is InputEventMouseMotion and mouse_captured:
		
			# Handle upwards movement
			cam_up = deg2rad(event.relative.y * -1)

			# Handle sideways movement
			cam_right = deg2rad(event.relative.x)
			rotation_happened = true

# Called every frame.
func _process(delta):
	
	# Updates the basic camera settings
	_update_camera_settings()
	
	# Checks for camera input
	_check_input()
		
	# Rotates the camera
	_rotate_camera(delta)
	
	# Checks for occlusion/collision
	_occlusion_check()
	

# Updates the camera settings
func _update_camera_settings():
	# Store the length of the springarm and its hit length
	spring_length = springarm.spring_length
	hit_length = springarm.get_hit_length()
	
	# Lets us know if the camera should be colliding with geometry by comparing the hit length 
	# of the spring arm to its current specified length.
	if hit_length < spring_length:
		clipping = true
	else:
		clipping = false
	
	# Update the wall detector's position to the follow target's, plus the specified offset.
	wall_detector.global_transform.origin = follow_target.global_transform.origin + wall_detector_offset

	# Store the camera and target z positions for easier comparisons
	cam_z = camera.transform.origin.z
	tar_z = target.transform.origin.z
	
	# Update the springarm's length to match the current specified distance.
	springarm.spring_length = distances[d]
	
	# Update the target's position so that it is always offset from the actual length of the springarm.
	target.transform.origin.z = hit_length - CameraCollisionOffset
	
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

# Checks the input of the camera
func _check_input():
	# Allow/disallow mouse input
	if Input.is_action_just_pressed("ui_cancel"):
		mouse_captured = not mouse_captured
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			InputMethod = Mode.MOUSE
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			InputMethod = Mode.GAMEPAD

	# Change the distance of the camera
	if ((Input.is_action_just_pressed(CameraInput.ZoomKey) and InputMethod == Mode.MOUSE or 
		Input.is_action_just_pressed(CameraInput.ZoomButton) and InputMethod == Mode.GAMEPAD) and 
		not clipping):
		_change_distance()

# Rotates the camera
func _rotate_camera(delta):
	if InputMethod == Mode.MOUSE:
		if rotation_happened:
			self.rotate_y(-cam_right * MouseSensitivity * delta)
			x_rotater.rotate_x(cam_up * MouseSensitivity * delta)
			rotation_happened = false
	elif InputMethod == Mode.GAMEPAD:
		# Store the right movement
		cam_right = Input.get_action_strength(CameraInput.LookLeft) - Input.get_action_strength(CameraInput.LookRight)
		
		# Store the up movement
		cam_up = Input.get_action_strength(CameraInput.LookUp) - Input.get_action_strength(CameraInput.LookDown)
		
		# Create an input vector containing the input information
		cam_stick_input = Vector2(cam_right, cam_up)
		
		# Apply the deadzone
		cam_stick_input = _apply_gamepad_deadzone(cam_stick_input, 0.25)
		
		# Rotation happened if our cam_stick_input vector length is greater than zero
		if cam_stick_input.length() > 0:
			rotation_happened = true
		else:
			rotation_happened = false
		
		# Apply the rotation to the camera
		self.rotate_y(cam_stick_input.x * GamepadSensitivity * delta)
		x_rotater.rotate_x(cam_stick_input.y * GamepadSensitivity * delta)
		
	# Clamp the camera's rotation so that we can't infinitely rotate on the X axis
	var x_rotation = x_rotater.rotation_degrees
	x_rotation.x = clamp(x_rotation.x, -70, 70)
	x_rotater.rotation_degrees = x_rotation

# Checks for occlusion
func _occlusion_check():
	# Compare the Target's z value to the Camera's z value. If it's less than the Camera, we know we are colliding, 
	# so check if either the probe array is NOT empty or the Camera has stopped rotating to respond to collisions.
	if tar_z < cam_z and clipping:
		if frames >= MaxFrameCount or not probe.empty():
			camera.transform.origin.z = target.transform.origin.z
	else:
		# Determine the camera's update strategy
		if CollisionResponse == CollideMode.PULL_FORWARD_SMOOTH_BACK:
			# Smoothly lerp back to the starting position (great for adventure games).
			camera.transform.origin.z = lerp(camera.transform.origin.z, 
			target.transform.origin.z,
			SmoothSpeed)
		else:
			# Snap back instantly (good for action games like third-person shooters)
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
