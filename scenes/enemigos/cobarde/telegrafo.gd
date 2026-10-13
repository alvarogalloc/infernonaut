extends Node2D

## Marca en el suelo la zona donde caerá un proyectil del cobarde. Se queda
## desde que el cobarde se prepara hasta que el proyectil aterriza.

var radio := 90.0
var _pulso := 0.0


func _ready() -> void:
	z_index = -5
	queue_redraw()


func _process(delta: float) -> void:
	_pulso += delta
	queue_redraw()


func _draw() -> void:
	var a := 0.30 + 0.15 * sin(_pulso * 6.0)
	draw_circle(Vector2.ZERO, radio, Color(1.0, 0.15, 0.10, a * 0.7))
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 48, Color(1.0, 0.35, 0.25, a), 4.0)