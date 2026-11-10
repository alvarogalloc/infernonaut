extends Node2D
## Llama viva: luz aditiva suave y de baja energía, con parpadeo desfasado
## por antorcha. Add (no Mix) porque light_suave.png tiene fondo negro y Mix
## lo dibujaría como cajas negras.

@onready var _luz: PointLight2D = $PointLight2D

var _t := 0.0


func _ready() -> void:
	_t = randf() * TAU
	_luz.blend_mode = Light2D.BLEND_MODE_ADD


func _process(delta: float) -> void:
	_t += delta
	_luz.energy = 0.8 + 0.1 * sin(_t * 9.0) + 0.04 * sin(_t * 23.0)
	_luz.texture_scale = 0.35 + 0.02 * sin(_t * 7.0)
