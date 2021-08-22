extends Spatial

# These enums help us out in the editor.
enum InputMode { MOUSE, GAMEPAD }
enum UpdateStrategy { SMOOTH, INSTANT }
export (UpdateStrategy) var CameraUpdateStrategy = UpdateStrategy.SMOOTH
export (float, 0.001, 0.1) var SmoothSpeed = 0.03
export (InputMode) var CameraInputMode = InputMode.MOUSE
export (NodePath) var LookAtTarget
export (float) var TargetOffset = 1.0
export (float) var CameraFOV = 70.0
export (Environment) var CameraEnvironment
export (float) var SpringArmLength = 6.0
export (float) var SpringArmSphereRadius = 1
export (float, 0.0, 10.0) var SpringArmSphereMargin = 1.0
export (float) var MouseSensitivity = 10.0

# Local variables
var cam_up : float = 0.0
var cam_right : float = 0.0
var mouse_moved : bool = false
var mouse_captured : bool = false
var current_zoom : int = 0
var zoom_markers : Array
var frames : int = 0
var probe : Array
var look_at_target 

onready var camera = $XRotater/Camera
onready var springarm = $XRotater/SpringArm
onready var target = $XRotater/SpringArm/Target

# Called when the node enters the scene tree for the first time.
func _ready():
	# Determine the Camera's input mode.
	if CameraInputMode == InputMode.MOUSE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_captured = true
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false
	
	# Assign the other camera properties
	camera.environment = CameraEnvironment
	camera.fov = CameraFOV
	
	# Assign the SpringArm properties
	springarm.spring_length = SpringArmLength
	springarm.shape.set_radius(SpringArmSphereRadius)
	springarm.shape.set_margin(SpringArmSphereMargin)
	
	# Get the look at target
	if LookAtTarget:
		look_at_target = get_node(LookAtTarget)
	
	# Ensure the target and camera are positioned properly
	target.transform.origin.z = springarm.spring_length - TargetOffset
	camera.transform.origin.z = target.transform.origin.z
	
	# Get the zoom marker's Z value to add to our zoom array
	for i in range($"XRotater/Zoom Markers".get_child_count()):
		zoom_markers.insert(zoom_markers.size(), $"XRotater/Zoom Markers".get_child(i).transform.origin.z)
	
	# Variable to store what zoom level we are currently at
	current_zoom = 0
	
	# Ensure we don't inherit rotational data from the player
	self.set_as_toplevel(true)

# Allows mouse input
func _input(event):
	if event is InputEventMouseMotion:
	
		# Handle upwards movement
		cam_up = deg2rad(event.relative.y * -1)

		# Handle sideways movement
		cam_right = deg2rad(event.relative.x)
		mouse_moved = true

# Called every frame.
func _process(delta):
	# Update the springarm's length
	springarm.spring_length = zoom_markers[current_zoom]
	
	# Update the target's position so that it is always offset from the actual length of the springarm.
	target.transform.origin.z = springarm.get_hit_length() - TargetOffset
	
	# Count the number of frames since the mouse last moved.
	if not mouse_moved:
		frames += 1
		if frames >= 3:
			frames = 3
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
	if Input.is_action_just_pressed("zoom"):
		current_zoom += 1
		if current_zoom >= zoom_markers.size():
			current_zoom = 0
	
	# Rotate the camera
	if mouse_moved:
		self.rotate_y(cam_right * MouseSensitivity * zoom_markers[current_zoom]/15 * delta)
		$XRotater.rotate_x(cam_up * MouseSensitivity * zoom_markers[current_zoom]/15 * delta)
		mouse_moved = false
		
		# Clamp the camera's rotation
		var x_rotation = $XRotater.rotation_degrees
		x_rotation.x = clamp(x_rotation.x, -90, 90)
		$XRotater.rotation_degrees = x_rotation

	# Store the camera and target z positions for easier comparisons
	var cam_z = camera.transform.origin.z
	var tar_z = target.transform.origin.z
	
	# Get the Target node's current Z value. If it's less than the Camera, we know we are technically clipping, 
	# so check if either the probe array is empty or the mouse has stopped moving to respond to collisions.
	if tar_z < cam_z:
		if frames >= 3 or not probe.empty():
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
