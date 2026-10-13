extends SceneTree
## Puertas seguras:
##  1) el generador no coloca enemigos a menos de DESPEJE_PUERTA de una puerta.
##  2) al cruzar una puerta el jugador aparece JUNTO a ella (a
##     `desplazamiento_puerta` dentro de la sala nueva), no en el centro.
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_puerta_segura.gd

var _checks := 0
var _fallos := 0
var _i := 0
var _casos: Array = []


func _initialize() -> void:
	for sem in range(1, 21):
		_casos.append([sem, sem % 2])


func _process(_delta: float) -> bool:
	if _i < _casos.size():
		var caso: Array = _casos[_i]
		_i += 1
		var nivel := GeneradorNivel.new().generar(caso[0], caso[1])
		root.add_child(nivel)
		_probar(caso, nivel)
		root.remove_child(nivel)
		nivel.free()
		return false
	_resumen()
	return true


func _probar(caso: Array, nivel: Node2D) -> void:
	var etq := "sem %d p%d" % [caso[0], caso[1]]
	_enemigos_lejos_de_puertas(etq, nivel)
	_spawn_junto_a_puerta(etq, nivel)


func _enemigos_lejos_de_puertas(etq: String, nivel: Node2D) -> void:
	var puertas := _puertas(nivel)
	if puertas.is_empty():
		return
	var cerca := false
	for e in get_nodes_in_group(Constantes.GRUPO_ENEMIGOS):
		for p in puertas:
			if e.global_position.distance_to(p.global_position) < GeneradorNivel.DESPEJE_PUERTA - 1.0:
				cerca = true
	_ok(etq + ": enemigos lejos de las puertas", not cerca)


func _spawn_junto_a_puerta(etq: String, nivel: Node2D) -> void:
	var cam: Camera2D = get_first_node_in_group("camara_jugador")
	var trans: Node = get_first_node_in_group("transicion_salas")
	if cam == null or trans == null:
		return
	var salas := _salas(nivel)
	if salas.size() < 2:
		return
	var a: Node2D = salas[0]
	var b: Node2D = null
	for r in salas:
		if r != a and _adyacentes(cam, a, r):
			b = r
			break
	if b == null:
		return
	cam._actual = a
	var pt: Vector2 = trans._punto_entrada(a, b)
	var rb: Rect2 = cam.sala_rect(b)
	var ra: Rect2 = cam.sala_rect(a)
	_ok(etq + ": aparece dentro de la sala nueva", rb.grow(-1.0).has_point(pt))
	var sep := rb.get_center() - ra.get_center()
	var desp: float = trans.desplazamiento_puerta
	if absf(sep.x) >= absf(sep.y):
		var borde := rb.position.x if sep.x > 0.0 else rb.end.x
		_ok(etq + ": aparece junto al borde de la puerta",
				absf(absf(pt.x - borde) - desp) <= 20.0)
	else:
		var borde := rb.position.y if sep.y > 0.0 else rb.end.y
		_ok(etq + ": aparece junto al borde de la puerta",
				absf(absf(pt.y - borde) - desp) <= 20.0)


func _adyacentes(cam: Camera2D, a: Node2D, b: Node2D) -> bool:
	var ra: Rect2 = cam.sala_rect(a)
	var rb: Rect2 = cam.sala_rect(b)
	if ra.size == Vector2.ZERO or rb.size == Vector2.ZERO:
		return false
	var ox := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
	var oy := minf(ra.end.y, rb.end.y) - maxf(ra.position.y, rb.position.y)
	var gap_x := maxf(ra.position.x, rb.position.x) - minf(ra.end.x, rb.end.x)
	var gap_y := maxf(ra.position.y, rb.position.y) - minf(ra.end.y, rb.end.y)
	# Solape en un eje y pegadas en el otro (borde compartido).
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


func _puertas(nivel: Node) -> Array:
	var out: Array = []
	_cosechar_puertas(nivel, out)
	return out


func _cosechar_puertas(nodo: Node, out: Array) -> void:
	if nodo.name.begins_with("puerta_"):
		out.append(nodo)
	for c in nodo.get_children():
		_cosechar_puertas(c, out)


func _resumen() -> void:
	print("==== ASSERT PUERTA SEGURA: ", _checks - _fallos, "/", _checks, " PASS ====")
	print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
	quit(1 if _fallos > 0 else 0)


func _eq(etq: String, real, esperado) -> void:
	_checks += 1
	if real == esperado:
		print("PASS ", etq)
	else:
		_fallos += 1
		print("FAIL ", etq, " real=", real, " esperado=", esperado)


func _ok(etq: String, cond: bool) -> void:
	_checks += 1
	if cond:
		print("PASS ", etq)
	else:
		_fallos += 1
		print("FAIL ", etq)
