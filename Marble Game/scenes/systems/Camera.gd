extends Spatial

# These enums help us out in the editor.
enum InputMode { MOUSE, GAMEPAD, HYBRID }
enum UpdateStrategy { SMOOTH, INSTANT }
export (NodePath) var FollowTarget
export (UpdateStrategy) var CameraUpdateStrategy = UpdateStrategy.SMOOTH
export (float, 0.001, 0.1) var SmoothSpeed = 0.03
export (InputMode) var CameraInputMode = InputMode.MOUSE
export (float, 0.01, 3.0) var TargetOffset = 1.0
export (float) var CameraFOV = 70.0
export (Environment) var CameraEnvironment
export (Vector3) var WallDetectorOffset = Vector3(0, 1, 0)
export (float, 0.01, 5.0) var SpringArmSphereRadius = 1
export (float, 0.0, 10.0) var SpringArmSphereMargin = 1.0
export (float) var MouseSensitivity = 10.0
export (int) var MaxFrameCount = 5

# Local variables
var cam_up : float = 0.0
var cam_right : float = 0.0
var mouse_moved : bool = false
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
	if CameraInputMode == InputMode.MOUSE or CameraInputMode == InputMode.HYBRID:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true
	elif CameraInputMode == InputMode.GAMEPAD:
		# The cursor isn't captured but we also don't want to show it until the player wants it shown
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		mouse_captured = false
		
	# Get the distance marker's Z values to add to our zoom array
	for i in range(distance_markers.get_child_count()):
		distances.append(distance_markers.get_child(i).transform.origin.z)
		
		# Hide the meshes
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
	springarm.spring_length = distances[d] 
	springarm.shape.set_radius(SpringArmSphereRadius)
	springarm.shape.set_margin(SpringArmSphereMargin)
	springarm.add_excluded_object(wall_detector)
	springarm.add_excluded_object(wall_detector_shape)
	
	# Ensure the target and camera are positioned properly
	target.transform.origin.z = distances[d] - TargetOffset
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
	if CameraInputMode == InputMode.MOUSE or CameraInputMode == InputMode.HYBRID:
		if event is InputEventMouseMotion and mouse_captured:
		
			# Handle upwards movement
			cam_up = deg2rad(event.relative.y * -1)

			# Handle sideways movement
			cam_right = deg2rad(event.relative.x)
			mouse_moved = true

# Called every frame.
func _process(delta):
	# Update the wall detector's position to the follow target's, plus the specified offset.
	wall_detector.global_transform.origin = follow_target.global_transform.origin + WallDetectorOffset
	
	# Update the springarm's length to match the current specified distance.
	springarm.spring_length = distances[d]
	
	# Update the target's position so that it is always offset from the actual length of the springarm.
	target.transform.origin.z = springarm.get_hit_length() - TargetOffset
	
	# Count the number of frames since the mouse last moved.
	if not mouse_moved:
		if frames >= MaxFrameCount:
			frames = MaxFrameCount
		else:
			frames += 1
	else:
		# The mouse has moved so reset the counter
		frames = 0

	# Allow/disallow input
	if Input.is_action_just_pressed("ui_cancel"):
		mouse_captured = not mouse_captured
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Change the distance of the camera
	if CameraInputMode == InputMode.MOUSE:
		if Input.is_action_just_pressed("key_zoom"):
			_change_distance()
	elif CameraInputMode == InputMode.GAMEPAD:
		if Input.is_action_just_pressed("gamepad_zoom"):
			_change_distance()
	elif CameraInputMode == InputMode.HYBRID:
		if Input.is_action_just_pressed("key_zoom") or Input.is_action_just_pressed("gamepad_zoom"):
			_change_distance()
		
	
	# Rotate the camera
	if mouse_moved:
		self.rotate_y(cam_right * MouseSensitivity * distances[d]/15 * delta)
		x_rotater.rotate_x(cam_up * MouseSensitivity * distances[d]/15 * delta)
		mouse_moved = false
		
		# Clamp the camera's rotation
		var x_rotation = x_rotater.rotation_degrees
		x_rotation.x = clamp(x_rotation.x, -90, 90)
		x_rotater.rotation_degrees = x_rotation

	# Store the camera and target z positions for easier comparisons
	var cam_z = camera.transform.origin.z
	var tar_z = target.transform.origin.z
	
	# Get the Target node's current Z value. If it's less than the Camera, we know we are technically clipping, 
	# so check if either the probe array is empty or the mouse has stopped moving to respond to collisions.
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
			camera.transform.origin.z = target.transform.origin.z

# Changes the distance of the camera
func _change_distance():
	d += 1
	if d >= distances.size():
		d = 0


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
