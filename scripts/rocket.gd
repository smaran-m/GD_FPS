extends Node3D

const SPEED = 40.0
const DAMAGE = 60.0

@onready var mesh = $Rocket
@onready var ray = $RayCast3D
@onready var particles = $GPUParticles3D
@onready var boom = $Boom
@onready var area = $ExplosionArea

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position += transform.basis * Vector3(0, 0, -SPEED) * delta
	if ray.is_colliding():
		explode()

func explode(): 
	print("EXPLOSION")
	var colliders = area.get_overlapping_bodies()  # Assuming area is an Area3D node you've added to the rocket
	for collider in colliders:
		if collider.has_method("hit"):
			print("HIT ENEMY")
			var attack_vector = (collider.global_transform.origin - global_transform.origin).normalized()
			collider.hit(DAMAGE, attack_vector)
	mesh.visible = false 
	particles.emitting = true
	boom.play()
	await get_tree().create_timer(1.0).timeout
	queue_free() #area collider still exists after collision for 1 second

func _on_timer_timeout(): #FIXME, doesn't get activated
	queue_free()
