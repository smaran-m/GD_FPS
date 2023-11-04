extends CharacterBody3D

var move_speed = 2.0
var attack_range = 3.0
var health = 100
var knockback_scale = 1

@onready var player : CharacterBody3D = get_tree().get_first_node_in_group("player")
var dead = false

func _physics_process(delta):
	if dead:
		return
	if player == null:
		return

func hit(damage = 1.0, attack_vector: Vector3 = Vector3()):
	health -= damage
	#$Hitsound.pitch_scale = damage/100
	$Hitsound.play()
	$SubViewport/HealthBar3D.value = health if health > 0 else 0
	if health <= 0:
		kill()
	# KNOCKBACK
	if attack_vector != Vector3():
		var knockback_direction = attack_vector.normalized()
		var knockback_magnitude = damage * knockback_scale  # Assume knockback_scale is a constant value you've defined
		velocity += knockback_direction * knockback_magnitude
	
	
func kill():
	dead = true
	#$DeathSound.play()
	#$AnimationController.play("death")
	self.queue_free()
