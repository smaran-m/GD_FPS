extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D
@onready var anim_player: AnimationPlayer = $Camera3D/Pistol/AnimationPlayer
@onready var footsteps = $SFX/Footsteps
@onready var raycast = $Camera3D/RayCast3D
@onready var hp_label = $UserInterface/HP

@onready var pistol_node = $Camera3D/Pistol
@onready var rpg_node = $Camera3D/RPG

enum WeaponType {
	PISTOL,
	RPG
}
var current_weapon: WeaponType = WeaponType.PISTOL

var rocket = load("res://scenes/rocket.tscn")
var instance
var knockback_scale = 0.3

var can_shoot = true
var zoomed = false
var dead = false

var health = 100

@export var mouse_sens: float = 0.001
@export var fov: int = 90
var zoom_fov: int = 45

@export var friction: float = 4
@export var accel: float = 12
@export var accel_air: float = 40
@export var top_speed_ground: float = 12
@export var top_speed_air: float = 2.5
#added walking
var walk_speed: float = top_speed_ground*0.5
var is_walking: bool = false
var lin_friction_speed: float = 10
@export var jump_force: float = 7
var projected_speed: float = 0
var grounded_prev: bool = true
var grounded: bool = true
var wish_dir: Vector3 = Vector3.ZERO
@export var gravity_mult: float = 2
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")\
	*gravity_mult

@export var auto_bhop: bool = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hp_label.add_text(str(health))

func _input(event: InputEvent) -> void:
	if dead:
		return
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
	if Input.is_action_just_pressed("shoot"):
		shoot()
	if Input.is_action_just_pressed("zoom"):
		zoom()
	if Input.is_action_just_pressed("toggle"):
		switch_weapon()

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
	if is_walking:
		top_speed = walk_speed
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
	clip_velocity(get_wall_normal(), 14, delta) # what does 14 refer to here
	clip_velocity(get_floor_normal(), 14, delta)
	velocity.y -= gravity * delta

func ground_move(delta):
	floor_snap_length = 0.4
	apply_acceleration(accel, top_speed_ground, delta)
	#if Input.is_action_pressed("jump"):
	if auto_bhop:
		if Input.is_action_pressed("jump"):
			velocity.y = jump_force
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force
	if grounded == grounded_prev:
		apply_friction(delta)
	if is_on_wall:
		clip_velocity(get_wall_normal(), 1, delta)

func _physics_process(delta):
	is_walking = Input.is_action_pressed("walk")
	grounded_prev = grounded
	var input_dir: Vector2 = Input.get_vector("left", "right", "up", "down") 
	
	if anim_player.current_animation == "Shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("Move")
		footsteps.play()
	elif not is_on_floor():
		# Optionally, add a jump or fall animation here.
		pass  
	else:
		anim_player.play("Idle")

	wish_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	projected_speed = (velocity * Vector3(1, 0, 1)).dot(wish_dir)
	if not is_on_floor():
		footsteps.stop()
		grounded = false
		air_move(delta)
	if is_on_floor():
		if velocity.y > 10:
			grounded = false
			air_move(delta)
		else:
			grounded = true
			ground_move(delta)
	move_and_slide()

func shoot():
	if !can_shoot:
		return
	else:
		match current_weapon:
			WeaponType.PISTOL:
				_shoot_pistol()
			WeaponType.RPG:
				_shoot_rpg()

func _shoot_pistol():
	if anim_player.current_animation != "Shoot":
		if raycast.is_colliding():
			print("HIT")
			if raycast.get_collider().has_method("hit"):
				print("HIT ENEMY")
				var attack_vector = raycast.global_transform.basis.z.normalized()  # Assuming the raycast is facing along the Z axis
				raycast.get_collider().hit(10)
	# ANIMATIONS
	anim_player.stop()
	anim_player.play("Shoot")
	$Camera3D/Pistol/MuzzleFlash.restart()
	$Camera3D/Pistol/MuzzleFlash.emitting = true
	$Camera3D/Pistol/Gunshot.play()

func _shoot_rpg():
	if anim_player.current_animation != "Shoot":
		instance = rocket.instantiate()
		instance.position = raycast.global_position
		instance.transform.basis = raycast.global_transform.basis
		get_parent().add_child(instance)
	# ANIMATIONS
	anim_player.stop()
	anim_player.play("Shoot")
	$Camera3D/RPG/RPG_Model/MuzzleFlash.restart()
	$Camera3D/RPG/RPG_Model/MuzzleFlash.emitting = true
	$Camera3D/RPG/FireSound.play()

func zoom():
	if !zoomed:
		camera.fov = zoom_fov
	else:
		camera.fov = fov
	zoomed = !zoomed

func hit(damage = 1, attack_vector: Vector3 = Vector3(0,0,0)):
	health -= damage
	hp_label.clear()
	hp_label.add_text(str(health))
	if health <= 0:
		kill()
	
	# KNOCKBACK
	if attack_vector != Vector3():
		var knockback_direction = attack_vector.normalized()
		var knockback_magnitude = damage * knockback_scale  # Assume knockback_scale is a constant value you've defined
		velocity += knockback_direction * knockback_magnitude

func kill():
	hp_label.clear()
	hp_label.add_text("SUPER LONG DEATH LABEL FOR TESTS")
	pass
	#dead = true
	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#$UserInterface/DeathScreen.show()
	#queue_free()

func switch_weapon(): # Need to make this work for any loadout
	match current_weapon:
		WeaponType.PISTOL:
			current_weapon = WeaponType.RPG
			anim_player = $Camera3D/RPG/AnimationPlayer
			pistol_node.visible = false
			rpg_node.visible = true
		WeaponType.RPG:
			current_weapon = WeaponType.PISTOL
			anim_player = $Camera3D/Pistol/AnimationPlayer
			rpg_node.visible = false
			pistol_node.visible = true

