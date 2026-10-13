extends Node

@export var sprite_path: NodePath = "../AnimatedSprite2D"
@export var interval: float = 0.04
@export var fade_time: float = 0.25
@export var alpha: float = 0.5

var _ghost_scene: PackedScene = preload("res://ghost-sprite.tscn")
var _sprite: AnimatedSprite2D
var _timer: Timer

func _ready() -> void:
	_sprite = get_node(sprite_path)
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.timeout.connect(_spawn_ghost)
	add_child(_timer)

func start() -> void:
	_spawn_ghost() # immediate ghost on the first frame, don't wait for the timer
	_timer.start()

func stop() -> void:
	_timer.stop()

func _spawn_ghost() -> void:
	var ghost := _ghost_scene.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.fade_time = fade_time
	ghost.start_alpha = alpha
	ghost.setup(
		_sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame),
		_sprite.global_position,
		_sprite.global_rotation,
		_sprite.flip_h,
		_sprite.z_index - 1
	)
