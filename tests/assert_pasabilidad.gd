extends SceneTree
## Regla de pasabilidad de pinchos: aunque los pinchos matan al tocar, nunca
## cortan el camino salida->meta. Se re-verifica con BFS bloqueando cada pincho
## (±1 tile) para ambas plantillas y varias semillas.
## Uso: godot --headless --script res://tests/assert_pasabilidad.gd

var _checks := 0
var _fallos := 0
var _paso := 0
var _i := 0
var _seeds: Array = []

const TILE := 60
const WALL := Vector2i(1, 0)


func _initialize() -> void:
	for sem in range(1, 41):
		_seeds.append([sem, sem % 2])


func _process(_delta: float) -> bool:
	if _paso == 0:
		_paso = 1
		return false
	if _i >= _seeds.size():
		print("==== ASSERT PASABILIDAD: ", _checks - _fallos, "/", _checks, " PASS ====")
		print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
		quit(1 if _fallos > 0 else 0)
		return true
	var caso: Array = _seeds[_i]
	_i += 1
	var nivel := GeneradorNivel.new().generar(caso[0], caso[1])
	root.add_child(nivel)
	_verificar(nivel, caso)
	root.remove_child(nivel)
	nivel.free()
	return false


func _verificar(nivel: Node2D, caso: Array) -> void:
	var etq := "sem %d p%d" % [caso[0], caso[1]]
	var jug := nivel.get_node_or_null("personaje")
	var meta := nivel.get_node_or_null("meta")
	if jug == null or meta == null:
		_eq(etq + " jugador/meta presentes", jug != null and meta != null, true)
		return
	var inicio := Vector2i(jug.position / TILE)
	var meta_celda := Vector2i(meta.position / TILE)
	var salas := _salas(nivel)
	var bloqueados := {}
	for s in salas:
		_marcar_pinchos(s.room, bloqueados)
	# Nota: los enemigos tienen un CollisionShape2D llamado "pinchos" debajo
	# de su nodo "environment". Sólo contamos los pinchos reales del
	# generador (hijos directos de la sala).
	var ok := GeneradorNivel.new()._alcanza_evitando(salas, inicio, meta_celda, bloqueados)
	_eq(etq + " meta alcanzable evitando pinchos", ok, true)


func _marcar_pinchos(nodo: Node, bloqueados: Dictionary) -> int:
	var n := 0
	# Sólo pinchos del generador: el nodo raíz del pincho es hijo directo de
	# la sala. Los enemigos tienen un CollisionShape2D "pinchos" bajo su
	# área "environment" que NO es un obstáculo del suelo.
	if nodo.name.contains("pincho") and nodo.get_parent() is Node2D \
			and _capa(nodo.get_parent()) != null:
		var g := Vector2i(nodo.global_position / TILE)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				bloqueados[g + Vector2i(dx, dy)] = true
		n += 1
	for c in nodo.get_children():
		n += _marcar_pinchos(c, bloqueados)
	return n


func _salas(nivel: Node2D) -> Array:
	var out: Array = []
	for h in nivel.get_children():
		if h is Node2D:
			var layer := _capa(h)
			if layer != null:
				out.append({"room": h, "layer": layer})
	return out


func _capa(nodo: Node) -> TileMapLayer:
	if nodo is TileMapLayer:
		return nodo
	for c in nodo.get_children():
		var l := _capa(c)
		if l != null:
			return l
	return null


func _eq(etq: String, real, esperado) -> void:
	_checks += 1
	if real == esperado:
		print("PASS ", etq)
	else:
		_fallos += 1
		print("FAIL ", etq, " real=", real, " esperado=", esperado)


func _ok(etq: String, cond: bool) -> void:
	if cond:
		print("PASS ", etq)
	else:
		_fallos += 1
		print("FAIL ", etq)