extends Area2D
## Meta del nivel: al tocarla el jugador, avisa y da feedback.
signal objetivo_alcanzado

var _alcanzado := false
var _t := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	rotation += delta * 0.8
	scale = Vector2.ONE * (1.0 + 0.08 * sin(_t * 3.0))


func _on_body_entered(body: Node2D) -> void:
	if _alcanzado or not body.is_in_group(Constantes.GRUPO_PERSONAJES):
		return
	_alcanzado = true
	print("OBJETIVO ALCANZADO")
	objetivo_alcanzado.emit()
	var t := create_tween().set_loops(5)
	t.tween_property(self, "modulate", Color(1.8, 1.8, 1.3, 1.0), 0.12)
	t.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
