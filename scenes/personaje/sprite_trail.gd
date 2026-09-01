extends Node

@onready var animated_sprite: AnimatedSprite2D = $"../AnimatedSprite2D"
@export var trail_container: Node

var tiempo_inicio: float = 0.5   # Retraso antes de empezar
var tiempo_actual: float = 0.0

func _ready():
	if trail_container == null:
		trail_container = get_tree().current_scene

func _physics_process(delta):
	tiempo_actual += delta
	if tiempo_actual >= tiempo_inicio and (get_tree().get_frame() % 4) == 0:
		crear_ghost()

func crear_ghost():
	var ghost = AnimatedSprite2D.new()
	ghost.sprite_frames = animated_sprite.sprite_frames
	ghost.animation = animated_sprite.animation
	ghost.frame = animated_sprite.frame
	
	# Reproducir la animación (quita ghost.stop())
	ghost.play(animated_sprite.animation)
	ghost.frame = animated_sprite.frame  # Comienza en el frame actual
	
	trail_container.add_child(ghost)
	ghost.global_transform = animated_sprite.global_transform
	ghost.flip_h = animated_sprite.flip_h
	ghost.flip_v = animated_sprite.flip_v
	ghost.offset = animated_sprite.offset
	
	# Color rojo claro
	ghost.modulate = Color(1.0, 0.6, 0.6, 1.0)
	ghost.z_index = -10
	
	# Desvanecer
	var tween = get_tree().create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ghost.queue_free)
