extends SceneTree
## Regresión del spawn al cruzar puerta: la cámara dispara la transición de
## sala y, terminado el wipe, el jugador debe quedar JUNTO a la puerta (a
## `desplazamiento_puerta` del borde compartido), nunca al centro ni en un
## borde cualquiera. Reproduce el fallo real (carrera de `sala_actual()` tras
## el primer await), que un test de geometría aislado no detecta.
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_transicion_spawn.gd

var _casos: Array = []
var _ci := 0
var _fase := 0
var _frames := 0
var _nivel: Node2D
var _jug: Node2D
var _cam: Camera2D
var _trans: Node
var _borde := 0.0
var _eje_x := true
var _checks := 0
var _fallos := 0


func _initialize() -> void:
	for s in range(1, 9):
		_casos.append([s, s % 2])


func _process(_delta: float) -> bool:
	if _fase == 0:
		if _ci >= _casos.size():
			_resumen()
			return true
		_setup(_casos[_ci])
		_fase = 1
		_frames = 0
	elif _fase == 1:
		_frames += 1
		if _frames > 3 and _trans.get("_ocupada") == false:
			_verificar(_casos[_ci])
			_avanzar()
		elif _frames > 240:
			_checks += 1
			_fallos += 1
			print("FAIL sem %d: la transición no terminó" % _casos[_ci][0])
			_avanzar()
	return false


func _avanzar() -> void:
	root.remove_child(_nivel)
	_nivel.free()
	_ci += 1
	_fase = 0


func _setup(caso: Array) -> void:
	_nivel = GeneradorNivel.new().generar(caso[0], caso[1])
	root.add_child(_nivel)
	_jug = get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	_cam = get_first_node_in_group("camara_jugador")
	_trans = get_first_node_in_group("transicion_salas")
	var salas := _salas(_nivel)
	var a: Node2D = salas[0]
	var b: Node2D = null
	for r in salas:
		if r != a and _adyacentes(_cam, a, r):
			b = r
			break
	if b == null:
		return
	var ra: Rect2 = _cam.sala_rect(a)
	var rb: Rect2 = _cam.sala_rect(b)
	var sep := rb.get_center() - ra.get_center()
	var target: Vector2
	if absf(sep.x) >= absf(sep.y):
		_eje_x = true
		_borde = rb.position.x if sep.x > 0.0 else rb.end.x
		var x := rb.position.x + 200.0 if sep.x > 0.0 else rb.end.x - 200.0
		target = Vector2(x, (maxf(ra.position.y, rb.position.y) + minf(ra.end.y, rb.end.y)) * 0.5)
	else:
		_eje_x = false
		_borde = rb.position.y if sep.y > 0.0 else rb.end.y
		var y := rb.position.y + 200.0 if sep.y > 0.0 else rb.end.y - 200.0
		target = Vector2((maxf(ra.position.x, rb.position.x) + minf(ra.end.x, rb.end.x)) * 0.5, y)
	_jug.global_position = target
	_cam._jugador = _jug
	_cam._actual = a
	_cam._physics_process(0.0)


func _verificar(caso: Array) -> void:
	var etq := "sem %d p%d" % [caso[0], caso[1]]
	var pos := _jug.global_position
	var d := absf(pos.x - _borde) if _eje_x else absf(pos.y - _borde)
	var desp: float = _trans.desplazamiento_puerta
	_ok(etq + ": aparece junto a la puerta", absf(d - desp) <= 40.0)
	_ok(etq + ": no aparece en mitad de la sala", d < 400.0)


func _adyacentes(cam: Camera2D, a: Node2D, b: Node2D) -> bool:
	var ra: Rect2 = cam.sala_rect(a)
	var rb: Rect2 = cam.sala_rect(b)
	if ra.size == Vector2.ZERO or rb.size == Vector2.ZERO:
		return false
	var ox := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
	var oy := minf(ra.end.y, rb.end.y) - maxf(ra.position.y, rb.position.y)
	var gap_x := maxf(ra.position.x, rb.position.x) - minf(ra.end.x, rb.end.x)
	var gap_y := maxf(ra.position.y, rb.position.y) - minf(ra.end.y, rb.end.y)
	return (ox > 1.0 and absf(gap_y) < 1.0) or (oy > 1.0 and absf(gap_x) < 1.0)


func _salas(nivel: Node2D) -> Array:
	var out: Array = []
	for h in nivel.get_children():
		if h is Node2D and _tiene_tilemap(h):
			out.append(h)
	return out


func _tiene_tilemap(nodo: Node) -> bool:
	if nodo is TileMapLayer:
		return true
	for c in nodo.get_children():
		if _tiene_tilemap(c):
			return true
	return false


func _resumen() -> void:
	print("==== ASSERT TRANSICION SPAWN: ", _checks - _fallos, "/", _checks, " PASS ====")
	print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
	quit(1 if _fallos > 0 else 0)


func _ok(etq: String, cond: bool) -> void:
	_checks += 1
	if cond:
		print("PASS ", etq)
	else:
		_fallos += 1
		print("FAIL ", etq)
