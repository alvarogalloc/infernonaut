extends Area2D
## Llave recogible. Las puertas consumen una al tocarlas.

var _t := 0.0
var _y := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_y = position.y


func _process(delta: float) -> void:
	_t += delta
	position.y = _y + sin(_t * 3.0) * 6.0


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(Constantes.GRUPO_PERSONAJES) or not body.has_method("agregar_llave"):
		return
	body.agregar_llave()
	get_tree().call_group("tutorial_hud", "mensaje", "LLAVE +1")
	queue_free()
