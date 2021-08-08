extends MeshInstance

# Just a sample script really.

export (float) var zSpeed = 1.25
export (float) var ySpeed = 2.5


# Called when the node enters the scene tree for the first time.
func _ready():
	print("Success!")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	rotate_z(zSpeed * delta)
	rotate_y(ySpeed * delta)
