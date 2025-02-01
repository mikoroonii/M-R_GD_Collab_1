extends CharacterBody2D

## Character Movement Speed
@export var SPEED: float = 300.0

## Character Jump Velocity
@export var JUMP_VELOCITY: float = 400.0

## Amount of jumps allowed in the air
@export var AIR_JUMPS: int = 1

var current_animation: animations = animations.IDLE :
	set(value):
		current_animation = value
		updateAnimation(value)
	get():
		return current_animation
	
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

var onGround = true

var direction

var anim_lock = false

var remaining_air_jumps = 0

var flip = false:
	set(value):
		flip = value
		$AnimatedSprite2D.flip_h = value

enum animations {DEATH, HIT, IDLE, ROLL, RUN, JUMP, LAND}

var animationData: Dictionary = {
	animations.DEATH: {
		"animationName": "death"
	},
	animations.HIT: {
		"animationName": "hit"
	},
	animations.IDLE: {
		"animationName": "idle"
	},
	animations.ROLL: {
		"animationName": "roll"
	},
	animations.RUN: {
		"animationName": "run"
	},
	animations.JUMP: {
		"animationName": "jump"
	},
	animations.LAND: {
		"animationName": "land"
	}
}

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		jump()

#region Movement Inputs
	direction = Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
		anim_lock = false
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
#endregion

#region Landing
	if is_on_floor() :
		if not onGround:
			land()
	else:
		onGround = false
#endregion
	
	move_and_slide()
	
	determineAnimation()
	


func jump():
	if is_on_floor():
		velocity.y = -JUMP_VELOCITY
		$JumpSFX.pitch_scale = 1
		$JumpSFX.play()
		jumpParticles()
	else:
		if remaining_air_jumps > 0:
			velocity.y = -JUMP_VELOCITY
			remaining_air_jumps -= 1
			$JumpSFX.pitch_scale = 2 - (float(remaining_air_jumps) / float(AIR_JUMPS))
			$JumpSFX.play()
			jumpParticles()
		else:
			pass
	
	
func jumpParticles():
	var temp_particle = $JumpParticles.duplicate()
	temp_particle.emitting = true
	get_parent().add_child(temp_particle)  # Add the duplicated particle to the scene
	temp_particle.global_position = $JumpParticles.global_position  # Optional: Set position
	await get_tree().create_timer(2).timeout
	temp_particle.queue_free()

func land():
	onGround = true
	anim_lock = true
	current_animation = animations.LAND
	remaining_air_jumps = AIR_JUMPS

	
func determineAnimation():
	if !anim_lock:
		var animation: animations = animations.IDLE
		if direction:
			if onGround:
				animation = animations.RUN
			else: 
				animation = animations.JUMP
			if direction > 0:
				flip = false
			else:
				flip = true
		else:
			if onGround:
				animation = animations.IDLE
			else:
				animation = animations.JUMP
				
		current_animation = animation
			
	pass

func updateAnimation(anim: animations):
	$AnimatedSprite2D.play(animationData[anim]["animationName"])
		


func looped() -> void:
	anim_lock = false
