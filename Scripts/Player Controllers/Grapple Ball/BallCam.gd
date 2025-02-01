extends Camera2D

@export var BallPlayerRef: Node2D

@export_subgroup("BallCam Variables")
@export var MAX_ROTATION_DEGREES: float = 1;
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var direction = Input.get_axis("move_left", "move_right")
	rotation_degrees = lerp(rotation_degrees, -direction * MAX_ROTATION_DEGREES, delta * 2)
	pass
	
func _physics_process(delta):
	if BallPlayerRef:
		position = lerp(position, BallPlayerRef.position, delta * 12)
