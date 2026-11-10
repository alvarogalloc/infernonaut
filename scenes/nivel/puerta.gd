class_name Puerta
extends StaticBody2D
## Barrera física en el hueco entre salas. Se abre al tocarla con una llave
## (la consume). Sin llave avisa por el HUD y sigue cerrada.

signal abierta

@export var necesita_llave := true

var _esta_abierta := false
var _ultimo_aviso := -2000


func _ready() -> void:
	var detector := Area2D.new()
	detector.name = "Detector"
	detector.collision_layer = 0
	detector.collision_mask = 1 ## cuerpo del jugador
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(170, 140)
	forma.shape = rect
	detector.add_child(forma)
	add_child(detector)
	detector.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _esta_abierta or not body.is_in_group(Constantes.GRUPO_PERSONAJES):
		return
	if necesita_llave and body.get("llaves") <= 0:
		var ahora := Time.get_ticks_msec()
		if ahora - _ultimo_aviso > 1500:
			_ultimo_aviso = ahora
			get_tree().call_group("tutorial_hud", "mensaje", "NECESITAS UNA LLAVE")
		return
	if necesita_llave:
		body.llaves -= 1
	abrir()


func abrir() -> void:
	if _esta_abierta:
		return
	_esta_abierta = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	abierta.emit()
	queue_redraw()
	if not is_inside_tree():
		visible = false
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)


func esta_abierta() -> bool:
	return _esta_abierta


func _draw() -> void:
	if _esta_abierta:
		return
	# Cerradura simple encima del sprite de la puerta.
	draw_circle(Vector2(0, -12), 10, Color(0.05, 0.03, 0.05, 0.9))
	draw_rect(Rect2(-4, -8, 8, 20), Color(0.05, 0.03, 0.05, 0.9))
