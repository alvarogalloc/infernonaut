class_name GeneradorNivel
extends RefCounted
## Genera un nivel completo en runtime (no guarda .tscn): salas con
## laberinto DFS, puertas conectadas, antorchas, pinchos, enemigos, meta,
## jugador, cámara y gestor de transición.
##
## Plantillas curadas (0 = la de 5 salas de siempre; 1 = bloque 3x2).
## `generar(semilla, plantilla)` es determinista y verifica que TODO el nivel
## sea un solo componente conexo; si no, reintenta con otra sub-semilla.

const TILE := 60
const RU := Vector2i(32, 18) ## 1 unidad de sala = 32x18 tiles
const PX := Vector2(TILE * RU.x, TILE * RU.y) ## 1920x1080
const FLOOR := Vector2i(0, 0)
const WALL := Vector2i(1, 0)
const PATH := Vector2i(2, 0)
const BLOOD := Vector2i(3, 0)
const STRIDE := 4 ## celda interior 3 tiles + separador de 1
const PUERTA_TILES := 2

const ESC_JUGADOR := 0.16
const ESC_ENEMIGO := 0.175
const ESC_PINCHO := 0.35
const ESC_ANTORCHA := 1.5
const ESC_META := 1.1

const RUTA_CAMARA := "res://scenes/escena_principal/room_camera.tscn"
const RUTA_JUGADOR := "res://scenes/personaje/character_body_2d.tscn"
const RUTA_ENEMIGO := "res://scenes/enemigos/enemigo_1.tscn"
const RUTA_PINCHO := "res://scenes/obstaculos/pincho/pincho.tscn"
const RUTA_ANTORCHA := "res://scenes/torch.tscn"
const RUTA_META := "res://scenes/objetivo/objetivo.tscn"
const RUTA_GESTOR := "res://scenes/escena_principal/transicion_salas.gd"
const RUTA_WIPE := "res://scenes/escena_principal/transicion_wipe.gdshader"
const RUTA_TILES := "res://tile_sets/blockout.png"

var _rng := RandomNumberGenerator.new()
var _ts: TileSet


## Devuelve un Node2D listo para añadir al árbol. plantilla < 0 = aleatoria.
func generar(semilla: int, plantilla: int = -1) -> Node2D:
	if plantilla < 0:
		_rng.seed = semilla
		plantilla = _rng.randi() % 2
	var root: Node2D = null
	for intento in 6:
		_rng.seed = semilla + intento * 7919
		var nivel: Dictionary = _construir(plantilla)
		root = nivel["root"]
		if _conectado(nivel["salas"]):
			return root
	return root # mejor esfuerzo


func _construir(plantilla: int) -> Dictionary:
	_ts = _tileset()
	var def := _plantilla(plantilla)
	var defs: Array = def[0]
	var puertas: Array = def[1]
	var root := Node2D.new()
	root.name = "nivel"

	var salas: Array = []
	for spec in defs:
		var room := Node2D.new()
		room.name = spec[0]
		room.position = Vector2(spec[1] * PX.x, spec[2] * PX.y)
		var layer := TileMapLayer.new()
		layer.name = "blockout"
		layer.tile_set = _ts
		layer.z_index = -11
		_llenar(layer, spec[3], spec[4])
		var centros := _maze(layer, spec[3], spec[4])
		room.add_child(layer)
		root.add_child(room)
		salas.append({"gx": spec[1], "gy": spec[2], "w": spec[3], "h": spec[4], "layer": layer, "room": room, "nombre": spec[0], "centros": centros})

	for d in puertas:
		_abrir_puerta(salas[d[0]], salas[d[1]], d[2])
	for s in salas:
		_conectar_puertas(s)
		_atmosfera(s)

	var arquetipos := _arquetipos(salas, puertas)
	var idx_meta: int = arquetipos.find("meta")
	if idx_meta < 0:
		idx_meta = salas.size() - 1
	var celda_inicio: Vector2i = salas[0].centros[0]
	var celda_meta: Vector2i = salas[idx_meta].centros[0]
	for i in salas.size():
		var protegida := Vector2i(-1, -1)
		if i == 0:
			protegida = celda_inicio
		elif i == idx_meta:
			protegida = celda_meta
		_contenido(salas[i], arquetipos[i], protegida)
	_meta(salas[idx_meta], root, celda_meta)

	var sp := _celda_mundo(salas[0], celda_inicio)
	var cam: Camera2D = load(RUTA_CAMARA).instantiate()
	cam.name = "Camera2D"
	cam.position = sp
	root.add_child(cam)
	var jug: Node2D = load(RUTA_JUGADOR).instantiate()
	jug.name = "personaje"
	jug.position = sp
	jug.scale = Vector2(ESC_JUGADOR, ESC_JUGADOR)
	root.add_child(jug)
	_transicion(root)
	return {"root": root, "salas": salas}


func _plantilla(p: int) -> Array:
	if p == 1:
		return [
			[["sala_A", 0, 0, 1, 1], ["sala_B", 1, 0, 1, 1], ["sala_C", 2, 0, 1, 1], ["sala_D", 0, 1, 1, 1], ["sala_E", 1, 1, 2, 1], ["sala_F", 0, 2, 1, 2]],
			[[0, 1, "E"], [1, 2, "E"], [0, 3, "S"], [1, 4, "S"], [2, 4, "S"], [3, 5, "S"]],
		]
	return [
		[["sala_1x1", 0, 0, 1, 1], ["sala_2x1", 1, 0, 2, 1], ["sala_1x2", 1, 1, 1, 2], ["sala_2x2", 2, 1, 2, 2], ["sala_3x1", 0, 3, 3, 1]],
		[[0, 1, "E"], [1, 2, "S"], [1, 3, "S"], [2, 3, "E"], [2, 4, "S"], [3, 4, "S"]],
	]


## Arquetipos de sala por distancia a la sala inicial (inicio/meta/...).
func _arquetipos(salas: Array, puertas: Array) -> Array:
	var n := salas.size()
	var adj: Array = []
	for _i in n:
		adj.append([])
	for d in puertas:
		adj[d[0]].append(d[1])
		adj[d[1]].append(d[0])
	var dist: Array = []
	dist.resize(n)
	dist.fill(-1)
	dist[0] = 0
	var cola: Array = [0]
	while cola.size() > 0:
		var c: int = cola.pop_front()
		for v in adj[c]:
			if dist[v] < 0:
				dist[v] = dist[c] + 1
				cola.append(v)
	var lejos := 0
	for i in n:
		if dist[i] > dist[lejos]:
			lejos = i
	var tipos: Array = []
	for i in n:
		var t := "combate"
		if i == 0:
			t = "inicio"
		elif i == lejos:
			t = "meta"
		else:
			t = ["tesoro", "combate", "trampa"][i % 3]
		tipos.append(t)
	return tipos


func _tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 8)
	var src := TileSetAtlasSource.new()
	src.texture = load(RUTA_TILES)
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for c in [FLOOR, WALL, PATH, BLOOD]:
		src.create_tile(c)
	var td := src.get_tile_data(WALL, 0)
	td.add_collision_polygon(0)
	var h := TILE * 0.5
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)
	]))
	return ts


func _llenar(layer: TileMapLayer, w: int, h: int) -> void:
	var cols := w * RU.x
	var rows := h * RU.y
	for y in rows:
		for x in cols:
			var borde := x == 0 or y == 0 or x == cols - 1 or y == rows - 1
			layer.set_cell(Vector2i(x, y), 0, WALL if borde else FLOOR)


func _maze(layer: TileMapLayer, w: int, h: int) -> Array:
	var cols := w * RU.x
	var rows := h * RU.y
	var nx := (cols - 2) / STRIDE
	var ny := (rows - 2) / STRIDE
	for k in range(1, nx):
		for y in range(1, rows - 1):
			layer.set_cell(Vector2i(k * STRIDE, y), 0, WALL)
	for k in range(1, ny):
		for x in range(1, cols - 1):
			layer.set_cell(Vector2i(x, k * STRIDE), 0, WALL)
	var visitadas := {}
	var pila: Array = [Vector2i(0, 0)]
	visitadas[Vector2i(0, 0)] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while pila.size() > 0:
		var c: Vector2i = pila[-1]
		var vecinos: Array = []
		for d in dirs:
			var nn: Vector2i = c + d
			if nn.x < 0 or nn.y < 0 or nn.x >= nx or nn.y >= ny or visitadas.has(nn):
				continue
			vecinos.append(nn)
		if vecinos.is_empty():
			pila.pop_back()
			continue
		var elegido: Vector2i = vecinos[_rng.randi() % vecinos.size()]
		_abrir_celdas(layer, c, elegido)
		visitadas[elegido] = true
		pila.append(elegido)
	var centros: Array = []
	for j in ny:
		for i in nx:
			centros.append(Vector2i(2 + i * STRIDE, 2 + j * STRIDE))
	# Barajar para repartir contenido sin sesgo posicional.
	for i in range(centros.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var tmp = centros[i]
		centros[i] = centros[j]
		centros[j] = tmp
	return centros


func _abrir_celdas(layer: TileMapLayer, a: Vector2i, b: Vector2i) -> void:
	if a.x != b.x:
		var sx: int = maxi(a.x, b.x) * STRIDE
		for dy in 3:
			layer.set_cell(Vector2i(sx, 1 + a.y * STRIDE + dy), 0, FLOOR)
	else:
		var sy: int = maxi(a.y, b.y) * STRIDE
		for dx in 3:
			layer.set_cell(Vector2i(1 + a.x * STRIDE + dx, sy), 0, FLOOR)


func _conectar_puertas(s: Dictionary) -> void:
	var layer: TileMapLayer = s.layer
	var cols: int = s.w * RU.x
	var rows: int = s.h * RU.y
	for x in cols:
		if layer.get_cell_source_id(Vector2i(x, 0)) == -1:
			_despejar(layer, Vector2i(x, 1), Vector2i(0, 1), cols, rows)
		if layer.get_cell_source_id(Vector2i(x, rows - 1)) == -1:
			_despejar(layer, Vector2i(x, rows - 2), Vector2i(0, -1), cols, rows)
	for y in rows:
		if layer.get_cell_source_id(Vector2i(0, y)) == -1:
			_despejar(layer, Vector2i(1, y), Vector2i(1, 0), cols, rows)
		if layer.get_cell_source_id(Vector2i(cols - 1, y)) == -1:
			_despejar(layer, Vector2i(cols - 2, y), Vector2i(-1, 0), cols, rows)


func _despejar(layer: TileMapLayer, celda: Vector2i, dir: Vector2i, cols: int, rows: int) -> void:
	var c := celda
	for _i in 80:
		if c.x <= 0 or c.y <= 0 or c.x >= cols - 1 or c.y >= rows - 1:
			return
		if layer.get_cell_source_id(c) == -1:
			return
		var atlas := layer.get_cell_atlas_coords(c)
		if atlas == FLOOR or atlas == BLOOD or atlas == PATH:
			return
		layer.set_cell(c, 0, PATH)
		c += dir


func _atmosfera(s: Dictionary) -> void:
	var layer: TileMapLayer = s.layer
	var cols: int = s.w * RU.x
	var rows: int = s.h * RU.y
	for y in rows:
		for x in cols:
			if layer.get_cell_atlas_coords(Vector2i(x, y)) == FLOOR and _rng.randf() < 0.09:
				layer.set_cell(Vector2i(x, y), 0, BLOOD)


## Contenido curado por arquetipo. `protegida` = celda sin enemigo/pincho.
func _contenido(s: Dictionary, tipo: String, protegida: Vector2i) -> void:
	var room: Node2D = s.room
	var centros: Array = s.centros
	var max_e := 2
	var max_p := 1
	match tipo:
		"inicio":
			max_e = 1
			max_p = 0
		"combate":
			max_e = 4
			max_p = 1
		"trampa":
			max_e = 2
			max_p = 3
		"tesoro":
			max_e = 2
			max_p = 1
		"meta":
			max_e = 3
			max_p = 1
	var ne := 0
	var np := 0
	var nt := 0
	var k := 0
	while k < centros.size() and (ne < max_e or np < max_p or nt < 4):
		var celda: Vector2i = centros[k]
		if celda == protegida:
			k += 1
			continue
		var p := _celda_mundo(s, celda)
		if nt < 4 and k % 3 == 0:
			_pone(room, RUTA_ANTORCHA, "antorcha_%d" % k, p + Vector2(0, -TILE * 0.5), ESC_ANTORCHA)
			nt += 1
		elif ne < max_e and k % 2 == 1:
			_pone(room, RUTA_ENEMIGO, "%s_enemigo_%d" % [s.nombre, k], p, ESC_ENEMIGO)
			ne += 1
		elif np < max_p and k % 2 == 0:
			_pone(room, RUTA_PINCHO, "%s_pincho_%d" % [s.nombre, k], p, ESC_PINCHO)
			np += 1
		k += 1


func _pone(padre: Node, ruta: String, nombre: String, pos: Vector2, esc: float) -> void:
	var n: Node2D = load(ruta).instantiate()
	n.name = nombre
	n.position = pos
	n.scale = Vector2(esc, esc)
	padre.add_child(n)


func _meta(s: Dictionary, root: Node, celda: Vector2i) -> void:
	var meta: Node2D = load(RUTA_META).instantiate()
	meta.name = "meta"
	meta.position = _celda_mundo(s, celda)
	meta.scale = Vector2(ESC_META, ESC_META)
	root.add_child(meta)


func _celda_mundo(s: Dictionary, celda: Vector2i) -> Vector2:
	var room: Node2D = s.room
	return room.position + Vector2(celda) * TILE + Vector2(TILE, TILE) * 0.5


func _abrir_puerta(a: Dictionary, b: Dictionary, lado: String) -> void:
	var la: TileMapLayer = a.layer
	var lb: TileMapLayer = b.layer
	if lado == "E":
		var lo := maxi(a.gy, b.gy) * RU.y
		var hi := mini(a.gy + a.h, b.gy + b.h) * RU.y
		var centro := (lo + hi) / 2
		for fila in PUERTA_TILES:
			var gry := centro - PUERTA_TILES / 2 + fila
			la.erase_cell(Vector2i(a.w * RU.x - 1, gry - a.gy * RU.y))
			lb.erase_cell(Vector2i(0, gry - b.gy * RU.y))
	else:
		var lo := maxi(a.gx, b.gx) * RU.x
		var hi := mini(a.gx + a.w, b.gx + b.w) * RU.x
		var centro := (lo + hi) / 2
		for col in PUERTA_TILES:
			var gcx := centro - PUERTA_TILES / 2 + col
			la.erase_cell(Vector2i(gcx - a.gx * RU.x, a.h * RU.y - 1))
			lb.erase_cell(Vector2i(gcx - b.gx * RU.x, 0))


func _transicion(root: Node) -> void:
	var gestor := Node.new()
	gestor.name = "TransicionSalas"
	gestor.set_script(load(RUTA_GESTOR))
	var capa := CanvasLayer.new()
	capa.name = "Capa"
	capa.layer = 50
	var color := ColorRect.new()
	color.name = "Color"
	color.anchor_right = 1.0
	color.anchor_bottom = 1.0
	color.grow_horizontal = Control.GROW_DIRECTION_BOTH
	color.grow_vertical = Control.GROW_DIRECTION_BOTH
	color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(RUTA_WIPE)
	mat.set_shader_parameter("progreso", 0.0)
	mat.set_shader_parameter("direccion", Vector2(1.0, 0.0))
	color.material = mat
	capa.add_child(color)
	gestor.add_child(capa)
	root.add_child(gestor)


## true si todos los tiles transitables (no-pared) son un solo componente.
func es_conexo(nivel: Node2D) -> bool:
	var salas: Array = []
	for h in nivel.get_children():
		if h is Node2D:
			var layer := _primera_capa(h)
			if layer != null:
				salas.append({"room": h, "layer": layer})
	return _conectado(salas)


func _primera_capa(n: Node) -> TileMapLayer:
	if n is TileMapLayer:
		return n
	for c in n.get_children():
		var l := _primera_capa(c)
		if l != null:
			return l
	return null


func _conectado(salas: Array) -> bool:
	var walk := {}
	for s in salas:
		var layer: TileMapLayer = s.layer
		var base := Vector2i((s.room as Node2D).position / TILE)
		var used: Rect2i = layer.get_used_rect()
		for y in range(used.position.y, used.end.y):
			for x in range(used.position.x, used.end.x):
				var cel := Vector2i(x, y)
				if layer.get_cell_atlas_coords(cel) != WALL:
					walk[base + cel] = true
	var claves := walk.keys()
	if claves.is_empty():
		return false
	var visto := {}
	var cola: Array = [claves[0]]
	visto[claves[0]] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while cola.size() > 0:
		var c: Vector2i = cola.pop_back()
		for d in dirs:
			var n: Vector2i = c + d
			if walk.has(n) and not visto.has(n):
				visto[n] = true
				cola.append(n)
	return visto.size() == claves.size()
