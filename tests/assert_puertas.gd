extends SceneTree
## Verifica el cerrado de puertas por enemigos y el parámetro de densidad:
##  - cada conexión crea UNA barrera (hija de la sala dueña)
##  - las salas con enemigos empiezan con las puertas cerradas
##  - al morir TODOS los enemigos de una sala se abren sus puertas
##  - `generar(semilla, plantilla, densidad_enemigos)` escala los enemigos
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_puertas.gd

var _nivel: Node2D
var _espera := 3
var _paso := 0
var _checks := 0
var _fallos := 0
var _sala_prueba: Node = null
var _puertas_prueba: Array = []


func _initialize() -> void:
	_nivel = GeneradorNivel.new().generar(12345, 0)
	root.add_child(_nivel)


func _process(_delta: float) -> bool:
	if _espera > 0:
		_espera -= 1
		return false
	match _paso:
		0:
			_inicial()
			_paso += 1
			return false
		1:
			_tras_abrir()
			_paso += 1
			return false
		_:
			_densidad()
			print("==== ASSERT PUERTAS: ", _checks - _fallos, "/", _checks, " PASS ====")
			print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
			quit(1 if _fallos > 0 else 0)
			return true


func _inicial() -> void:
	var salas := _salas()
	_eq("salas (plantilla 0)", salas.size(), 5)
	var total := 0
	for r in salas:
		total += _puertas(r).size()
	_eq("puertas totales == conexiones", total, 6)

	var todas_cerradas := true
	var hay_prueba := false
	for r in salas:
		var ctrl := _controlador(r)
		if ctrl == null:
			continue
		if ctrl.enemigos_restantes() > 0:
			if ctrl.abierta():
				todas_cerradas = false
			for p in _puertas(r):
				if p.collision_layer == 0:
					todas_cerradas = false
		if not hay_prueba and ctrl.enemigos_restantes() > 0 and _puertas(r).size() > 0:
			_sala_prueba = ctrl
			_puertas_prueba = _puertas(r)
			hay_prueba = true
	_eq("salas con enemigos empiezan cerradas", todas_cerradas, true)
	_ok("hay sala de prueba con puertas", hay_prueba)

	if _sala_prueba != null:
		var cuarto := _sala_prueba.get_parent()
		for e in get_nodes_in_group(Constantes.GRUPO_ENEMIGOS):
			if e.get_parent() == cuarto:
				e.call("_morir")


func _tras_abrir() -> void:
	_eq("sala limpiada -> abierta", _sala_prueba.abierta(), true)
	_eq("restantes 0", _sala_prueba.enemigos_restantes(), 0)
	var off := true
	for p in _puertas_prueba:
		if p.collision_layer != 0:
			off = false
	_eq("colision de puertas desactivada", off, true)


func _densidad() -> void:
	var n0 := _contar_enemigos(GeneradorNivel.new().generar(777, 0, 0.0))
	var n1 := _contar_enemigos(GeneradorNivel.new().generar(777, 0, 1.0))
	var n2 := _contar_enemigos(GeneradorNivel.new().generar(777, 0, 2.0))
	_eq("densidad 0 -> 0 enemigos", n0, 0)
	_ok("densidad 1 -> hay enemigos", n1 > 0)
	_ok("densidad 2 > densidad 1", n2 > n1)


func _salas() -> Array:
	var out: Array = []
	for h in _nivel.get_children():
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


func _puertas(room: Node) -> Array:
	var out: Array = []
	for c in room.get_children():
		if c.has_method("abrir"):
			out.append(c)
	return out


func _controlador(room: Node) -> Node:
	return room.get_node_or_null("controlador_sala")


func _contar_enemigos(nivel: Node) -> int:
	var n := 0
	for h in nivel.get_children():
		if h.name.contains("enemigo"):
			n += 1
		n += _contar_enemigos(h)
	return n


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
