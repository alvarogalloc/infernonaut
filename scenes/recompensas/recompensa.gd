extends Area2D

## Recogible de una sala "tesoro": al tocarlo da una mejora de una vez.
##   "escudo"      -> +1 golpe antes de morir (dos golpes en total)
##   "dash_sombra" -> +5 dashes sombra (atraviesan paredes)
signal recogida

@export var tipo := "escudo"
var _t := 0.0
var _recogido := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 ## cuerpo del jugador
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	rotation += delta * 1.5
	scale = Vector2.ONE * (1.0 + 0.12 * sin(_t * 4.0))


func _draw() -> void:
	var col := Color(0.5, 0.7, 1.0) if tipo == "dash_sombra" else Color(0.95, 0.8, 0.25)
	draw_circle(Vector2.ZERO, 30.0, col)
	draw_circle(Vector2.ZERO, 14.0, col.lightened(0.4))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 40, col.darkened(0.25), 4.0)


func _on_body_entered(body: Node2D) -> void:
	if _recogido or not body.is_in_group(Constantes.GRUPO_PERSONAJES):
		return
	if not is_instance_valid(body) or not body.has_method("aplicar_recompensa"):
		return
	_recogido = true
	body.aplicar_recompensa(tipo)
	recogida.emit()
	queue_free()