extends Node2D

## Proyectil del cobarde: sube en arco hasta su destino y, al aterrizar,
## inflige daño de área al jugador (daño por posición, sin colisiones).
## Señal `aterrizo` para que el lanzador limpie los telégrafos.

signal aterrizo

var radio_dano: float = 90.0

var _origen := Vector2.ZERO
var _destino := Vector2.ZERO
var _duracion := 0.9
var _altura := 240.0
var _t := 0.0


func configurar(origen: Vector2, destino: Vector2, duracion: float, altura: float) -> void:
	_origen = origen
	_destino = destino
	_duracion = maxf(duracion, 0.05)
	_altura = altura
	global_position = origen
	z_index = 5


func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.5, 0.2, 0.9))
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.95, 0.5, 1.0))


func _process(delta: float) -> void:
	_t += delta
	var p := minf(_t / _duracion, 1.0)
	global_position = _origen.lerp(_destino, p) - Vector2(0, sin(p * PI) * _altura)
	if p >= 1.0:
		_aterrizar()


func _aterrizar() -> void:
	for j in get_tree().get_nodes_in_group(Constantes.GRUPO_PERSONAJES):
		if not is_instance_valid(j):
			continue
		if j.global_position.distance_to(_destino) <= radio_dano and j.has_method("golpear"):
			j.golpear()
	aterrizo.emit()
	queue_free()