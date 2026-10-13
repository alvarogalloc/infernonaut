class_name Puerta
extends StaticBody2D
## Barrera física que bloquea una conexión entre salas. El controlador de
## sala (Sala) llama a `abrir()` cuando no quedan enemigos vivos: se
## desactiva la colisión y la puerta se desvanece.
##
## La crea GeneradorNivel por código (colisión 2x2 tiles, collision_layer 8
## = pared, sprite res://sprites/puerta.png).

var _abierta := false


func abrir() -> void:
	if _abierta:
		return
	_abierta = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if not is_inside_tree():
		modulate.a = 0.0
		visible = false
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)


func abierta() -> bool:
	return _abierta
