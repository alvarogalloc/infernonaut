extends SceneTree
## Verifica los dashes con Tween: alcance en unidades (fuerte 10 tiles = 600 px,
## normal 5 tiles = 300 px), recorte al cursor y aterrizaje limpio.
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_dash.gd

const TILE := 60.0
const ORIGEN := Vector2(960, 540) ## centro de sala_1x1 del proto

var _nivel: Node
var _jugador: Node2D
var _espera := 2
var _i := 0
var _activo := false
var _timeout := 0
var _checks := 0
var _fallos := 0
# [fuerte, destino_clic, esperado]
var _pasos := [
	[true, Vector2(99999, 540), ORIGEN + Vector2(10 * TILE, 0)],
	[false, Vector2(960, 99999), ORIGEN + Vector2(0, 5 * TILE)],
	[false, Vector2(1200, 540), Vector2(1200, 540)], # clic corto: llega exacto
	[true, Vector2(1200, 540), Vector2(1200, 540)],
]


func _initialize() -> void:
	_nivel = GeneradorNivel.new().generar(12345, 0)
	root.add_child(_nivel)


func _process(_delta: float) -> bool:
	if _espera > 0:
		_espera -= 1
		return false
	if _jugador == null:
		_setup()
		return false
	if _i >= _pasos.size():
		_informe()
		quit(1 if _fallos > 0 else 0)
		return true
	if _activo:
		_timeout -= 1
		if bool(_jugador.get("_dashing")) and _timeout > 0:
			return false
		_checks += 1
		if _timeout <= 0:
			_fallos += 1
			print("FAIL paso ", _i, ": dash no terminó")
		elif _jugador.global_position.distance_to(_pasos[_i][2]) <= 2.0:
			print("PASS paso ", _i, " -> ", _jugador.global_position)
		else:
			_fallos += 1
			print("FAIL paso ", _i, " pos=", _jugador.global_position, " esperado=", _pasos[_i][2])
		_i += 1
		_activo = false
		return false
	_jugador.global_position = ORIGEN
	_jugador.set("target_position", ORIGEN)
	_jugador.call("dash_hacia", _pasos[_i][1], _pasos[_i][0])
	_activo = true
	_timeout = 120
	return false


func _setup() -> void:
	_jugador = get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	for h in _nivel.get_children():
		if h is Node2D and h.name.contains("enemigo"):
			h.set_physics_process(false)
			h.global_position = Vector2(99999, 99999)
	_quitar_pinchos(_nivel)
	var g = get_first_node_in_group("transicion_salas")
	if g:
		g.set("activa", false)
	_jugador.set("collision_mask", 0) # aislar el dash de las paredes


func _informe() -> void:
	print("==== ASSERT DASH: ", _checks - _fallos, "/", _checks, " PASS ====")
	print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")


func _quitar_pinchos(n: Node) -> void:
	for h in n.get_children():
		if h.name.contains("pincho"):
			h.free()
		else:
			_quitar_pinchos(h)
