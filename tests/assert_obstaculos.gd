extends SceneTree
## Nuevo enfoque de obstáculos y mapa de entidades:
##  - el corredor garantizado salida->meta nunca lleva pinchos encima
##  - aun evitando todos los pinchos, la meta sigue alcanzable
##  - el mapa de entidades permite apagar tipos para una semilla
## Uso: godot --headless --script res://tests/assert_obstaculos.gd

var _checks := 0
var _fallos := 0
var _paso := 0
var _i := 0
var _casos: Array = []

const TILE := 60
const WALL := Vector2i(1, 0)


func _initialize() -> void:
	for sem in range(1, 21):
		_casos.append([sem, sem % 2])


func _process(_delta: float) -> bool:
	if _paso == 0:
		_paso = 1
		return false
	if _i >= _casos.size():
		_mapa_entidades()
		print("==== ASSERT OBSTACULOS: ", _checks - _fallos, "/", _checks, " PASS ====")
		print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
		quit(1 if _fallos > 0 else 0)
		return true
	var caso: Array = _casos[_i]
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
		_eq(etq + " jugador/meta", jug != null and meta != null, true)
		return
	var inicio := Vector2i(jug.position / TILE)
	var meta_celda := Vector2i(meta.position / TILE)
	var salas := _salas(nivel)
	var gen := GeneradorNivel.new()
	var ruta := gen._ruta_principal(salas, inicio, meta_celda)
	_ok(etq + " corredor existe", not ruta.is_empty())
	# Ningún pincho sobre el corredor garantizado.
	var pinchos := _tiles_pinchos(nivel)
	var encima := 0
	for g in pinchos:
		if ruta.has(g):
			encima += 1
	_eq(etq + " pinchos fuera del corredor", encima, 0)
	# Y aun bloqueando todos los pinchos la meta es alcanzable.
	var bloqueados := {}
	for g in pinchos:
		bloqueados[g] = true
	var alcanzable := gen._alcanza_evitando(salas, inicio, meta_celda, bloqueados)
	_eq(etq + " meta alcanzable evitando pinchos", alcanzable, true)


## Apagar una entidad con densidad 0.0 la quita del nivel entero.
func _mapa_entidades() -> void:
	var escenas := {
		"densidad_pincho": "pincho.tscn",
		"densidad_antorcha": "torch.tscn",
		"densidad_enemigo_mele": "enemigo_1.tscn",
		"densidad_cobarde": "cobarde.tscn",
	}
	for clave in escenas:
		var cfg := {clave: 0.0}
		var nivel := GeneradorNivel.new().generar(7, 0, cfg)
		root.add_child(nivel)
		var n := _contar_escena(nivel, escenas[clave])
		_eq("densidad %s = 0.0 elimina la entidad" % clave, n, 0)
		root.remove_child(nivel)
		nivel.free()


func _tiles_pinchos(nivel: Node2D) -> Array:
	var out: Array = []
	for sala in nivel.get_children():
		if not (sala is Node2D):
			continue
		for c in sala.get_children():
			if c.name.contains("pincho"):
				out.append(Vector2i(c.global_position / TILE))
	return out


func _contar_escena(nodo: Node, sub: String) -> int:
	var n := 0
	for h in nodo.get_children():
		if h.scene_file_path.contains(sub):
			n += 1
		n += _contar_escena(h, sub)
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
	_checks += 1
	if cond:
		print("PASS ", etq)
	else:
		_fallos += 1
		print("FAIL ", etq)
