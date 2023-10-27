extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash

var mouse_sens: float = 0.001
var friction: float = 4
var accel: float = 12
var accel_air: float = 40
var top_speed_ground: float = 15
var top_speed_air: float = 2.5
var lin_friction_speed: float = 10
var jump_force: float = 7
var projected_speed: float = 0
var grounded_prev: bool = true
var grounded: bool = true
var wish_dir: Vector3 = Vector3.ZERO
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			self.rotate_y(-event.relative.x * mouse_sens)
			camera.rotate_x(-event.relative.y * mouse_sens)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(60))

func _unhandled_input(event):
	if Input.is_action_just_pressed("shoot") \
			and anim_player.current_animation != "Shoot":
		play_shoot_effects()

func clip_velocity(normal: Vector3, overbounce: float, delta) -> void:
	var correction_amount: float = 0
	var correction_dir: Vector3 = Vector3.ZERO
	var move_vector: Vector3 = get_velocity().normalized()
	correction_amount = move_vector.dot(normal) * overbounce
	correction_dir = normal * correction_amount
	velocity -= correction_dir
	velocity.y -= correction_dir.y * (gravity/20)

func apply_friction(delta):
	var speed_scalar: float = 0
	var friction_curve: float = 0
	var speed_loss: float = 0
	var current_speed: float = 0
	current_speed = velocity.length()
	if current_speed < 0.1:
		velocity.x = 0
		velocity.y = 0
		return
	friction_curve = clampf(current_speed, lin_friction_speed, INF)
	speed_loss = friction_curve * friction * delta
	speed_scalar = clampf(current_speed - speed_loss, 0, INF)
	speed_scalar /= clampf(current_speed, 1, INF)
	velocity *= speed_scalar

func apply_acceleration(acceleration: float, top_speed: float, delta):
	var speed_remaining: float = 0
	var accel_final: float = 0
	speed_remaining = (top_speed * wish_dir.length()) - projected_speed
	if speed_remaining <= 0:
		return
	accel_final = acceleration * delta * top_speed
	clampf(accel_final, 0, speed_remaining)
	velocity.x += accel_final * wish_dir.x
	velocity.z += accel_final * wish_dir.z

func air_move(delta):
	apply_acceleration(accel_air, top_speed_air, delta)
	clip_velocity(get_wall_normal(), 14, delta)
	clip_velocity(get_floor_normal(), 14, delta)
	velocity.y -= gravity * delta

func ground_move(delta):
	floor_snap_length = 0.4
	apply_acceleration(accel, top_speed_ground, delta)
	if Input.is_action_pressed("jump"):
		velocity.y = jump_force
	if grounded == grounded_prev:
		apply_friction(delta)
	if is_on_wall:
		clip_velocity(get_wall_normal(), 1, delta)

func _physics_process(delta):
	grounded_prev = grounded
	var input_dir: Vector2 = Input.get_vector("left", "right", "up", "down") 
	
	if anim_player.current_animation == "Shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("Move")
	elif not is_on_floor():
		# Optionally, add a jump or fall animation here.
		pass  
	else:
		anim_player.play("Idle")

	wish_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	projected_speed = (velocity * Vector3(1, 0, 1)).dot(wish_dir)
	if not is_on_floor():
		grounded = false
		air_move(delta)
	if is_on_floor():
		if velocity.y > 10:
			grounded = false
			air_move(delta)
		else:
			grounded = true
			ground_move(delta)
			if Input.is_action_just_pressed("ui_accept"):
				velocity.y = jump_force
	move_and_slide()

func play_shoot_effects():
	anim_player.stop()
	anim_player.play("Shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true
