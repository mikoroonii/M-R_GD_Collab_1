## This is a slightly simplified version of my Grapple controller in that Grapple2D thing i sent you.

extends RigidBody2D

###########################################################

## Editable Variables
@export_subgroup("Movement")

## Acceleration of the roll
@export var ROLL_ACCELERATION: float = 2.5

## Maximum roll speed
@export var ROLL_MAX_SPEED: float = 40

## Force applied on jump
@export var JUMP_FORCE: float = 500

## Maximum distance from the floor before being able to jump
@export var FLOOR_DISTANCE: float = 3

## The linear velocity at which damping is applied
@export var DAMPING_VELOCITY_LINEAR: float = 550

## The damping applied when falling below above velocity 
@export var DAMPING: float = 1.5

@export var IN_AIR_MOVE_FORCE: float = 600

@export_subgroup("Grappling")

## Force multiplier for grappling
@export var GRAPPLE_FORCE: float = 3000

## Damping applied to the grapple forces to mitigate oscillation and other issues
@export var GRAPPLE_DAMPING: Vector2 = Vector2(.99, 0.999)

## Boost applied to the player when the grapple is released, as a percentage of current velocity added to the player velocity.
@export var GRAPPLE_RELEASE_BOOST: Vector2 = Vector2(0.1, 0.2)

## Maximum distance the player can grapple
@export var MAX_GRAPPLE_DISTANCE: float = 400

## Multiplier for the force applied to physics objects when grappled
@export var RIGIDBODY_FORCE_MULTIPLIER: Vector2 = Vector2(0.9, 0.9)

## Distance at which the physics applied to a grappled rigid body will be damped
@export var RIGIDBODY_DAMPING_DISTANCE: float = 80

## Damping applied when the player is within rigidbody damping distance of a grappled rigidbody.
@export var RIGIDBODY_CLOSE_DAMPING: Vector2 = Vector2(0.05, 0.05)

## Grapple Angle
@export var GRAPPLE_ANGLE: float = 180

###########################################################

## Internal Variables
var direction
@onready var collision_shape_2d = $CollisionShape2D
@onready var texture = $Texture

var grapple_point = Vector2.ZERO
var grappling = false
var to_grapple = Vector2.ZERO
var grapple_target: Node2D = null  # Stores the object being grappled (must be RigidBody2D)
var local_grapple_offset = Vector2.ZERO  # Stores the grapple point relative to the target's position



@onready var grappleCast = $RayCast2D

###########################################################

func _ready():
	grappleCast.target_position = Vector2(MAX_GRAPPLE_DISTANCE, 0)  # Set the raycast's target position
	print('test')
func _physics_process(_delta):
	grappleCast.target_position = grappleposition()
	queue_redraw()
	
	## ROLLING CONTROLS #######################################
	direction = Input.get_axis("move_left", "move_right")
	if Input.is_action_pressed("brake"):
		angular_velocity = 0
	else:
		if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
			if direction:
				angular_velocity = clamp(move_toward(angular_velocity, direction * ROLL_MAX_SPEED, ROLL_ACCELERATION), -ROLL_MAX_SPEED, ROLL_MAX_SPEED)
				if !is_on_floor():
					apply_central_force(Vector2(direction * IN_AIR_MOVE_FORCE, 0))
	###########################################################

	## JUMP CONTROLS ##########################################
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			linear_velocity.y -= JUMP_FORCE
	###########################################################

	## UPDATE MOTION BLUR #####################################
	if $Texture.material is Material:
		$Texture.material.set_shader_parameter("amount", angular_velocity * 0.015)
	###########################################################

	## DAMPING ################################################
	if linear_velocity.length() < DAMPING_VELOCITY_LINEAR:
		self.angular_damp = DAMPING
	else:
		self.angular_damp = 0
		pass
	###########################################################

	## GRAPPLING ##############################################
	if Input.is_action_just_released("grapple"):
		grappling = false
		grapple_target = null
	if Input.is_action_just_pressed("grapple"):
		grappleCast.force_raycast_update()
		if grappleCast.is_colliding():
			grappling = true
			grapple_point = grappleCast.get_collision_point()  # Set the grapple point to the collision point
			
			var collider = grappleCast.get_collider()
			if collider is RigidBody2D or collider is AnimatableBody2D:
				grapple_target = collider
				if grapple_target:
					# Store the grapple point relative to the target's position
					local_grapple_offset = grapple_target.to_local(grapple_point)
					print("Grappled to: ", grapple_target.name)
					to_grapple = (grapple_point - global_position).normalized()

	if grappling and grapple_target:
		# Convert the local offset back to global coordinates
		grapple_point = grapple_target.to_global(local_grapple_offset)
		
		# Calculate the direction to the grapple point relative to the player's rotation
		var grapple_direction = (grapple_point - global_position).rotated(-rotation).normalized()
		
		# Apply force towards the grapple point, taking into account the player's rotation
		apply_central_force(grapple_direction * GRAPPLE_FORCE * _delta)
		
		# Apply damping to mitigate oscillation
		linear_velocity *= GRAPPLE_DAMPING
		if grapple_target is RigidBody2D:
			var player_mass = mass
			var target_mass = grapple_target.mass
			var total_mass = player_mass + target_mass

			if total_mass > 0:  # Avoid division by zero
				grapple_direction = (grapple_point - global_position).normalized()
				var force = grapple_direction * GRAPPLE_FORCE
				
				var player_force = force * (target_mass / total_mass)
				var target_force = force * (player_mass / total_mass)

				apply_force(player_force)
				grapple_target.apply_force(-target_force)
		else:
			grapple_direction = (grapple_point - global_position).normalized()
			apply_force(grapple_direction * GRAPPLE_FORCE)
	else:
		if grappling:
			var grapple_direction = (grapple_point - global_position).normalized()
			apply_force(grapple_direction * GRAPPLE_FORCE)
	###########################################################

func _process(_delta):
	if Input.is_action_just_pressed("action"):
		pass

## FUNCTIONS ##############################################

## Used to detect if the player is on the floor.
var floorcast_start: Vector2
var floorcast_end: Vector2
var collision_point: Vector2
var has_collision: bool = false
func is_on_floor():
	# Calculate ray positions
	floorcast_start = global_position + Vector2(0, $CollisionShape2D.shape.get_radius() - FLOOR_DISTANCE)
	floorcast_end = floorcast_start + Vector2(0, FLOOR_DISTANCE * 2)
	
	# Set up raycast parameters
	var direct_state = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.new()
	params.from = floorcast_start
	params.to = floorcast_end
	params.exclude = [self.get_rid()]
	
	# Perform raycast
	var collision = direct_state.intersect_ray(params)
	has_collision = !collision.is_empty()
	collision_point = collision.position if has_collision else Vector2.ZERO
	# Trigger draw update
	#queue_redraw()
	
	return collision

func _draw():
	var drawColor = Color.RED
	var drawWidth = 2
	if grappling:
		drawWidth = 9
	else:
		drawWidth = 2
	grappleCast.force_raycast_update()
	if grappleCast.is_colliding() or grappling:
		drawColor = Color.GREEN
	if grappleCast.is_colliding() and !grappling:
		draw_circle(to_local(grappleCast.get_collision_point()), 15, Color.ORANGE)
	
	draw_line(Vector2.ZERO, grappleposition(), drawColor, drawWidth, 30)

func grappleposition():
	if grappling:
		# Return the grapple point relative to the player's position
		return (grapple_point - global_position).rotated(-rotation)
	else:
		# Return the mouse position relative to the player, clamped to MAX_GRAPPLE_DISTANCE
		var mousePosition = get_local_mouse_position()
		if mousePosition.length() > MAX_GRAPPLE_DISTANCE:
			return mousePosition.normalized() * MAX_GRAPPLE_DISTANCE
		else:
			return mousePosition
