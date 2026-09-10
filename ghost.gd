extends Sprite2D

@export var fade_time: float = 0.25
@export var start_alpha: float = 0.5

func setup(tex: Texture2D, pos: Vector2, rot: float, flip_h: bool, z: int) -> void:
	texture = tex
	global_position = pos
	global_rotation = rot
	self.flip_h = flip_h
	z_index = z
	modulate = Color(1.0, 1.0, 1.0, start_alpha)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)
