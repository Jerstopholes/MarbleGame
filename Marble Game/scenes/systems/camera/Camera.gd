extends Spatial

# These enums help us out in the editor.
enum Mode { MOUSE, GAMEPAD }
enum CollideMode { INSTANT_FORWARD_SMOOTH_BACK, INSTANT_FORWARD_AND_BACK }
enum FollowMode { SMOOTH_INTERPOLATION, INSTANT }
enum Inputs { GENERATE_FOR_ME, SPECIFY_MY_OWN }
export (NodePath) var FollowTarget
export (FollowMode) var CameraFollowMode = FollowMode.SMOOTH_INTERPOLATION
export (float, 0.001, 0.1) var FollowSmoothSpeed = 0.08
export (CollideMode) var CollisionResponse = CollideMode.INSTANT_FORWARD_SMOOTH_BACK
export (float, 0.001, 0.1) var CollisionSmoothSpeed = 0.05
export (float, 0, 2.0) var CameraCollisionOffset = 0.25
export (Mode) var InputMethod = Mode.MOUSE
export (Inputs) var InputsToUse = Inputs.GENERATE_FOR_ME
export (float) var MouseSensitivity = 10.0
export (float) var GamepadSensitivity = 2.75
export (float, 0.01, 0.5) var GamepadDeadzone = 0.25
export (float, 0.01, 179) var CameraFOV = 70.0
export (Environment) var CameraEnvironment
export (float, 0.01, 2.0) var SpringArmSphereRadius = 1
export (float, 0.01, 10.0) var SpringArmSphereMargin = 1.0
export (int) var FramesToWaitBeforeCollision = 5
export (float) var SecondsToWaitForRotation = 2
export (bool) var AllowSwitchToFirstPerson = true


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
var wall_detector_offset : Vector3
var camera_offset : Vector3
var hit_length : float = 0
var spring_length : float = 0
var clipping : bool = false
var touching_wall : bool = false
var centering_camera : bool = false
var detect_hit : bool = false
var angle : float = 0
var cam_distance : float = 0
var fade_out_done : bool = false
var fade_in_done : bool = false
var switch : bool = false


# Node reference variables
onready var x_rotater = $XRotater
onready var camera = $XRotater/Camera
onready var springarm = $XRotater/SpringArm
onready var target = $XRotater/SpringArm/Target
onready var distance_markers = $DistanceMarkers
onready var wall_detector = $WallDetector
onready var CameraInput = $CameraInput
onready var detection_spring = $XRotater/Camera/DetectionSpring
onready var fp_cam = $XRotater/FirstPersonCamera/Camera
onready var anim_player = $XRotater/FirstPersonCamera/AnimPlayer

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
		
		# Hide the markers
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
		printerr("Please make sure you assign a follow target.")
		# Force a crash
		get_tree().quit()
	
	# Assign the SpringArm properties
	springarm.spring_length = distances[0] 
	springarm.shape.set_radius(SpringArmSphereRadius)
	springarm.shape.set_margin(SpringArmSphereMargin)
	
	# Add these nodes to be excluded by the spring arm to prevent false positive collisions
	springarm.add_excluded_object(wall_detector)
	springarm.add_excluded_object(follow_target)
	
	# Do the same for the detection spring on the camera
	detection_spring.add_excluded_object(wall_detector)
	detection_spring.add_excluded_object(follow_target)
	
	# Ensure the target and camera are positioned properly
	target.transform.origin.z = distances[0] - CameraCollisionOffset
	cam_distance = target.transform.origin.z
	camera.transform.origin.z = cam_distance

	# Ensure we don't inherit rotational data from the player
	self.set_as_toplevel(true)
	wall_detector.set_as_toplevel(true)
	
	# Store the offset of the wall detector to the follow target
	wall_detector_offset = wall_detector.global_transform.origin - follow_target.global_transform.origin
	
	# Store the offset of the camera and follow target
	camera_offset = self.global_transform.origin - follow_target.global_transform.origin
	
	# Hide the target visual aid
	target.hide()

# Allows mouse input
func _input(event):
	if InputMethod == Mode.MOUSE:
		if event is InputEventMouseMotion and mouse_captured:
		
			# Handle upwards movement
			cam_up = deg2rad(event.relative.y * -1)

			# Handle sideways movement
			cam_right = deg2rad(event.relative.x)
			
			# We moved this frame, so rotation happened
			rotation_happened = true
			
			# Cancel centering the camera
			centering_camera = false

# Called every frame.
func _process(delta):
	
	# Updates the basic camera settings
	_update_camera_settings()
	
	# Updates the positioning of the camera
	_update_camera_position()
	
	# Checks for camera input
	_check_input()
		
	# Rotates the camera
	_rotate_camera(delta)
	
	# Checks for occlusion/collision
	_occlusion_check()
	

# Updates the camera settings
func _update_camera_settings():
	# Update the springarm's length to match the current specified distance.
	springarm.spring_length = distances[d]
	
	# Store the length of the springarm and its hit length
	spring_length = springarm.spring_length
	hit_length = springarm.get_hit_length()
	
	# Update the target's position so that it is always offset from the actual length of the springarm.
	target.transform.origin.z = hit_length - CameraCollisionOffset
	
	# Update the wall detector's position to the follow target's, plus the specified offset.
	wall_detector.global_transform.origin = follow_target.global_transform.origin + wall_detector_offset

	# Store the camera and target z positions for easier comparisons
	cam_z = camera.transform.origin.z
	tar_z = target.transform.origin.z
	
	# Count the number of frames since rotation last happened. This is done to ensure the camera doesn't clip to 
	# geometry between itself and the player UNLESS there is geometry close enough to the camera, or the player has
	# stopped moving the camera. 
	if not rotation_happened:
		if frames >= FramesToWaitBeforeCollision:
			frames = FramesToWaitBeforeCollision
		else:
			frames += 1
	else:
		# Rotation has happened so reset the counter
		frames = 0
		
	# Check to see if we are switching over to First Person Mode.
	if switch:
		# Flip which cameras are active
		camera.current = !camera.current
		fp_cam.current = !camera.current
		
		# Reset the rotation
		rotation_degrees.y = follow_target.rotation_degrees.y
		rotation_degrees.x = 0
		
		# Play the animation to hide this all
		anim_player.play("FadingIn")
		switch = false
		


# Updates the positioning of the camera
func _update_camera_position():
	# Determine the follow mode of the camera
	if CameraFollowMode == FollowMode.SMOOTH_INTERPOLATION:
		# Smoothly lerp the position of the camera to the follow target
		self.global_transform.origin = lerp(self.global_transform.origin, follow_target.global_transform.origin + camera_offset, 0.08)
	else:
		# Instantly move the camera to match the follow target's position
		self.global_transform.origin = follow_target.global_transform.origin
		
	# Check to see if the player has prompted recentering
	if centering_camera:
		_center_camera()

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
		
	# Recenter the camera
	if (Input.is_action_just_pressed(CameraInput.CenterCameraKey) and InputMethod == Mode.MOUSE or 
		Input.is_action_just_pressed(CameraInput.CenterCameraButton) and InputMethod == Mode.GAMEPAD):
		centering_camera = true

# Rotates the camera
func _rotate_camera(delta):
	if InputMethod == Mode.MOUSE:
		if rotation_happened:
			rotate_y(-cam_right * MouseSensitivity * delta)
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
		
		# Rotation happened if our cam_stick_input vector length is not equal to zero
		if cam_stick_input.length() != 0:
			rotation_happened = true
			centering_camera = false
		else:
			rotation_happened = false
			
		# Apply the rotation to the camera
		rotate_y(cam_stick_input.x * GamepadSensitivity * delta)
		x_rotater.rotate_x(cam_stick_input.y * GamepadSensitivity * delta)
		
	# Clamp the camera's rotation so that we can't infinitely rotate on the X axis
	var x_rotation = x_rotater.rotation_degrees
	x_rotation.x = clamp(x_rotation.x, -70, 70)
	x_rotater.rotation_degrees = x_rotation

# Checks for occlusion
func _occlusion_check():
	
	# Lets us know if the camera should be colliding with geometry by comparing the hit length 
	# of the spring arm to its current specified length.
	if hit_length < spring_length:
		clipping = true
	else:
		clipping = false
	
	# We determine if something is behind the camera by comparing the hit length of the "detection spring"
	# to its specified length. If it's shorter than the specified length, the camera hit something located 
	# behind it, so let us know that the hit was detected.
	if detection_spring.get_hit_length() < detection_spring.spring_length:
		detect_hit = true
	else:
		detect_hit = false

	# We determine if the Camera is colliding by comparing the Target's Z value to the Camera's.
	# If it's less than the Camera's, AND the SpringArm itself is clipping, we know we are 
	# colliding with something.
	if tar_z < cam_z and clipping:
		
		# We now want to ensure that the camera SHOULD be colliding against the found geometry.
		# We don't want to collide while we're rotating the camera, UNLESS the detection spring
		# finds geometry, or the player has stopped rotating the camera for the amount of frames
		# that are specified to wait. When either is true, pull the Camera forward.
		if frames >= FramesToWaitBeforeCollision or detect_hit:
			cam_distance = lerp(cam_distance, tar_z, 0.4)


	else:
		# Determine the camera's update strategy
		if CollisionResponse == CollideMode.INSTANT_FORWARD_SMOOTH_BACK:
			# Smoothly lerp back to the target's position (great for adventure games).
			cam_distance = lerp(cam_distance, tar_z, CollisionSmoothSpeed)
		else:
			# Snap back instantly (great for action games like third-person shooters)
			cam_distance = tar_z
	camera.transform.origin.z = cam_distance


# Changes the current distance of the camera
func _change_distance():
	# Check if we are in First Person Mode. If we are, we want to switch out of it.
	if fp_cam.current:
		switch = true
	else:
		d += 1
	
	# If we reach the end of the distances array, but allow switching to first-person mode, 
	# start back at the beginning but also set switch to true.
	if d == distances.size() and AllowSwitchToFirstPerson:
		switch = true
		d = 0
		
	# If we reach the end of the distances array, start back at the beginning.
	elif d >= distances.size():
		d = 0



# Rotates the camera to face the same way as the follow target
func _center_camera():

	# Center the camera only if the rotation angle doesn't match the target's
	if rotation_degrees.y != follow_target.rotation_degrees.y:
		angle = lerp(angle, 0.8, 0.01)
		if rotation_degrees.y < follow_target.rotation_degrees.y:
			rotation_degrees.y += angle
		elif rotation_degrees.y > follow_target.rotation_degrees.y:
			rotation_degrees.y -= angle

	# Stop centering the camera and match the rotation exactly once we are close enough to
	# the target's rotation
	if is_equal_approx(stepify(rotation_degrees.y, 0.75), stepify(follow_target.rotation_degrees.y, 0.75)):
		angle = 0
		rotation_degrees.y = follow_target.rotation_degrees.y
		centering_camera = false
	
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
		touching_wall = true

# Lets us know when the player has stopped touching a wall.
func _on_WallDetector_body_exited(body):
	if not body.is_in_group("exclude"):
		touching_wall = false



