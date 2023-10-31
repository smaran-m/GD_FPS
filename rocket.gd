extends Node3D

const SPEED = 40.0

@onready var mesh = $MeshInstance3D
@onready var ray = $RayCast3D
@onready var particles = $GPUParticles3D
@onready var boom = $Boom

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position += transform.basis * Vector3(0, 0, -SPEED) * delta
	if ray.is_colliding():
		print("HIT")
		mesh.visible = false
		particles.emitting = true
		if ray.get_collider().has_method("hit"):
			print("HIT ENEMY")
			boom.play()
			ray.get_collider().hit()
		await get_tree().create_timer(1.0).timeout
		queue_free()
		

func _on_timer_timeout():
	queue_free()
