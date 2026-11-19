extends Node2D
## Niveles curados (sin generación procedural):
##   modo "tutorial" -> seis salas en fila, una lección por sala.
##   modo "maze"     -> mazmorra demo de 9 salas en rejilla 3x3.
##   solo_arena      -> únicamente la arena del tutorial.
## Los mapas son fijos (30x16 interior) y se construyen una vez.

signal completado

const TILE := 60
const COLS := 32
const FILAS := 18
const PX := Vector2(COLS * TILE, FILAS * TILE)
const FILA_PUERTA := 9 ## tiles y, y+1 del hueco entre salas

const FLOOR := Vector2i(0, 0)
const WALL := Vector2i(1, 0)
const BLOOD := Vector2i(3, 0)

const RUTA_CAMARA := "res://scenes/escena_principal/room_camera.tscn"
const RUTA_JUGADOR := "res://scenes/personaje/character_body_2d.tscn"
const RUTA_ENEMIGO := "res://scenes/enemigos/enemigo_1.tscn"
const RUTA_COBARDE := "res://scenes/enemigos/cobarde/cobarde.tscn"
const RUTA_PINCHO := "res://scenes/obstaculos/pincho/pincho.tscn"
const RUTA_ANTORCHA := "res://scenes/torch.tscn"
const RUTA_META := "res://scenes/objetivo/objetivo.tscn"
const RUTA_RECOMPENSA := "res://scenes/recompensas/recompensa.tscn"
const RUTA_LLAVE := "res://scenes/nivel/llave.tscn"
const RUTA_GESTOR := "res://scenes/escena_principal/transicion_salas.gd"
const RUTA_WIPE := "res://scenes/escena_principal/transicion_wipe.gdshader"
const RUTA_SUELO1 := "res://sprites/suelo1.png"
const RUTA_SUELO2 := "res://sprites/suelo2.png"
const RUTA_PARED := "res://sprites/t3.png"
const RUTA_PUERTA_TEX := "res://sprites/door.png"
const RUTA_HUD := "res://scenes/HUD+/TutorialHud/tutorial_hud.tscn"
const RUTA_HINT := "res://scenes/HUD+/ActionHint/action_hint.tscn"
const RUTA_MINIMAPA := "res://scenes/HUD+/Minimapa/minimapa.gd"

const ESC_JUGADOR := 0.16
const ESC_ENEMIGO := 0.175
const ESC_PINCHO := 0.35
const ESC_ANTORCHA := 1.5
const ESC_META := 1.1

## Leyenda: P jugador, K llave, R escudo, S dash sombra, X pincho,
## E enemigo melee, C cobarde, T antorcha, M meta, # muro, , suelo con sangre.
const MAPAS := [
	[
		"..............................",
		"..............................",
		"................###...........",
		"................#.............",
		"......###.......#.............",
		"......#.........#.............",
		"......#.........#.............",
		".............,................",
		".........P...............K....",
		"..............................",
		"................###...........",
		"................#.............",
		"................#.............",
		"....,...........#.............",
		"........T.......#.........T...",
		"..............................",
	],
	[
		"..............................",
		"..............................",
		"..P...........................",
		"..............................",
		"........####........###.......",
		"........####........###.......",
		"..............................",
		"...............,..............",
		"........................L.....",
		"...............,..............",
		"........####........###.......",
		"........####........###.......",
		"..............................",
		"..............................",
		"....T.....................T...",
		"..............................",
	],
	[
		"..............#...............",
		"..............#...............",
		"..............#...............",
		"..............#...............",
		"..............#...............",
		"..............#...,...........",
		"..............X...............",
		"..............X...............",
		"..P..R........X.........K.....",
		"..............X...............",
		"..............X...............",
		"..............#...............",
		"..............#.....,.........",
		"..............#...............",
		"....T.........#..........T....",
		"..............#...............",
	],
	[
		"..............##..............",
		"..............##..............",
		"..............##..............",
		"..............##..............",
		"..............##....,.........",
		"..............##..............",
		"..............##..............",
		"..............##..............",
		"..P..S........##.........K....",
		"..............##..............",
		"..............##..............",
		"..............##..............",
		"..............##......,.......",
		"..............##..............",
		"....T.........##..........T...",
		"..............##..............",
	],
	[
		"..............#...##..........",
		"..............#...##..........",
		"..............#...##..........",
		"..............#...##..........",
		"..........,...#...##..........",
		"..............#...##..........",
		"..............X...##..........",
		"..............X...##..........",
		"....P...R.....XS..##.....K....",
		"..............X...##..........",
		"..............X...##..........",
		"..............#...##..........",
		"..........,...#...##..........",
		"..............#...##..........",
		"....T......T..#...##.......T..",
		"..............#...##..........",
	],
	[
		"..........#.......#...........",
		"..........#.......#...........",
		"..........#.......#...........",
		"..........#...........,.......",
		"............X.................",
		"...................C..........",
		"..............................",
		"......S.......................",
		"...P.....,....E...........M...",
		"......R.......................",
		"..............................",
		"..............................",
		"........X.#..........X........",
		"..........#.......#...,.......",
		".....T....#....T..#.....T.....",
		"..........#.......#...........",
	],
]

const PUERTAS := [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5]]

## Mazmorra demo: 9 salas en rejilla 3x3 (mapas fijos, sin generación).
const POS_MAZE := [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(2, 1),
	Vector2i(0, 2),
	Vector2i(1, 2),
	Vector2i(2, 2),
]

const MAPAS_MAZE := [
	[
		"..............",
		"..............",
		".....E....C...",
		"......R.......",
		"..............",
		"..............",
		"..............",
	],
	[
		"..............",
		".....C........",
		"..............",
		"......R..L....",
		"..............",
		"..............",
		"..............",
	],
	[
		"..............",
		"........#..C..",
		"........#.....",
		"...S...#..R...",
		"........#.....",
		"........#..K..",
		"..............",
	],
	[
		"..........#...",
		"..........#...",
		"..............",
		"...P..K.......",
		"..............",
		"..........#...",
		"..........#...",
	],
	[
		"..............",
		"...##....##...",
		"..........C...",
		"......L.......",
		"..............",
		"...##....##...",
		"..............",
	],
	[
		"..............",
		"........#..E..",
		"........#.....",
		"........#..K..",
		"........#.....",
		"........#.....",
		"..............",
	],
	[
		"..............",
		"..............",
		"..............",
		"...R......E...",
		"..............",
		"..............",
		"..............",
	],
	[
		".........#....",
		".........#....",
		"..R......X..K.",
		".........X....",
		".........X....",
		".........#....",
		"..............",
	],
	[
		"..............",
		"..............",
		"..R....E......",
		"...........M..",
		"..........C...",
		"..............",
		"..............",
	],
]

const PUERTAS_MAZE := [
	[3, 4, "E", 3, 1],
	[1, 4, "S", 7, 1],
	[1, 2, "E", 3, 1],
	[4, 5, "E", 3, 0],
	[4, 7, "S", 7, 0],
	[0, 3, "S", 7, 0],
	[3, 6, "S", 7, 0],
	[6, 7, "E", 3, 0],
	[7, 8, "E", 3, 3],
]

const ACCIONES_MAZE := [
	{"icono": "res://sprites/ui/escudo.svg", "accion": "escudo"},
	{"icono": "res://sprites/ui/raton_izq.svg", "accion": "fuerte"},
	{"icono": "res://sprites/ui/raton_centro.svg", "accion": "sombra"},
	{"icono": "res://sprites/ui/raton_der.svg", "accion": "normal"},
	{"icono": "res://sprites/ui/raton_izq.svg", "accion": "fuerte"},
	{"icono": "res://sprites/ui/raton_centro.svg", "accion": "sombra"},
	{"icono": "res://sprites/ui/escudo.svg", "accion": "escudo"},
	{"icono": "res://sprites/ui/escudo.svg", "accion": "escudo"},
	{"icono": "res://sprites/ui/meta.svg", "accion": "meta"},
]



@export var solo_arena := false
@export var modo := "tutorial" ## "tutorial" | "maze"

var _ts: TileSet
var _cols := COLS
var _filas := FILAS
var _px := PX
var _mapas: Array = MAPAS
var _puertas: Array = PUERTAS
var _info: Array = []
var _jugador: Node2D = null
var _hud: Node = null
var _hint: Node = null
var _minimapa: Control = null
var _leccion := -1
var _spawn := -1
var _n_puerta := 0


func _ready() -> void:
	_ts = _tileset()
	_mapas = MAPAS_MAZE if modo == "maze" else MAPAS
	_puertas = PUERTAS_MAZE if modo == "maze" else PUERTAS
	if modo == "maze":
		_cols = 16
		_filas = 9
		_px = Vector2(_cols * TILE, _filas * TILE)
	_info.resize(_mapas.size())
	if solo_arena:
		var i := MAPAS.size() - 1
		_crear_sala(i, Vector2.ZERO)
	else:
		for i in _mapas.size():
			var pos := Vector2.ZERO
			if modo == "maze":
				pos = Vector2(POS_MAZE[i].x * _px.x, POS_MAZE[i].y * _px.y)
			else:
				pos = Vector2(i * _px.x, 0.0)
			_crear_sala(i, pos)
		for d in _puertas:
			_crear_puerta(d)
	_spawn_jugador(_info[_spawn].sala.position + _info[_spawn].inicio)
	_hud = load(RUTA_HUD).instantiate()
	add_child(_hud)
	if modo == "maze":
		_hint = load(RUTA_HINT).instantiate()
		add_child(_hint)
	var oscuro := CanvasModulate.new()
	oscuro.color = Color(0.62, 0.58, 0.64)
	add_child(oscuro)
	_crear_minimapa()


## Minimapa mínimo en la esquina superior derecha: visitadas encendidas.
func _crear_minimapa() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 40
	var mini: Control = load(RUTA_MINIMAPA).new()
	mini.anchor_left = 1.0
	mini.anchor_right = 1.0
	mini.offset_left = -230.0
	mini.offset_right = -10.0
	mini.offset_top = 10.0
	mini.offset_bottom = 190.0
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(mini)
	add_child(capa)
	mini.call("configurar", _info, _spawn)
	_minimapa = mini


func _process(_delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		return
	var indice := -1
	if solo_arena:
		indice = MAPAS.size() - 1
	else:
		var gx := int(floor(_jugador.global_position.x / _px.x))
		var gy := int(floor(_jugador.global_position.y / _px.y))
		for i in _info.size():
			if _info[i].gx == gx and _info[i].gy == gy:
				indice = i
				break
	if indice < 0 or indice == _leccion:
		return
	_leccion = indice
	if _minimapa != null:
		_minimapa.call("marcar", indice)
	if _hud != null:
		if modo == "maze" and _hint != null:
			_hint.call("mostrar", ACCIONES_MAZE[indice])
		else:
			_hud.call("mostrar_leccion", indice)


func _crear_sala(indice: int, pos: Vector2) -> void:
	var mapa: Array = _mapas[indice]
	assert(mapa.size() == _filas - 2, "mapa %d: filas" % indice)
	var sala := Node2D.new()
	sala.name = "sala_%d" % indice
	sala.position = pos
	sala.add_to_group(Constantes.GRUPO_SALAS)
	add_child(sala)
	var capa := TileMapLayer.new()
	capa.name = "blockout"
	capa.tile_set = _ts
	capa.z_index = Constantes.Z_TILEMAP
	sala.add_child(capa)

	var inicio := Vector2.ZERO
	for y in _filas:
		if y > 0 and y < _filas - 1:
			assert(mapa[y - 1].length() == _cols - 2, "mapa %d fila %d" % [indice, y - 1])
		for x in _cols:
			var celda := Vector2i(x, y)
			var borde := x <= 0 or y <= 0 or x >= _cols - 1 or y >= _filas - 1
			var c := "#" if borde else String(mapa[y - 1][x - 1])
			var tile := WALL
			if c == ",":
				tile = BLOOD
			elif c != "#":
				tile = FLOOR
			capa.set_cell(celda, 0, tile)
			match c:
				"P":
					inicio = _centro(celda)
					if _spawn < 0:
						_spawn = indice
				"K":
					_pone(sala, RUTA_LLAVE, _centro(celda), 1.0)
				"R":
					_pone_recompensa(sala, _centro(celda), "escudo")
				"S":
					_pone_recompensa(sala, _centro(celda), "dash_sombra")
				"X":
					_pone(sala, RUTA_PINCHO, _centro(celda), ESC_PINCHO)
				"E":
					_pone(sala, RUTA_ENEMIGO, _centro(celda), ESC_ENEMIGO)
				"C":
					_pone(sala, RUTA_COBARDE, _centro(celda), ESC_ENEMIGO)
				"L":
					var guardia := _pone(sala, RUTA_ENEMIGO, _centro(celda), ESC_ENEMIGO)
					guardia.connect("murio", _soltar_llave.bind(sala, guardia))
				"T":
					var t := _pone(sala, RUTA_ANTORCHA,
							_centro(celda) + Vector2(0, -TILE * 0.5), ESC_ANTORCHA)
					t.z_index = Constantes.Z_ANTORCHA
				"M":
					var meta: Node2D = _pone(sala, RUTA_META, _centro(celda), ESC_META)
					meta.name = "meta"
					meta.objetivo_alcanzado.connect(_on_meta)
	_info[indice] = {"sala": sala, "capa": capa, "inicio": inicio, "gx": int(pos.x / _px.x), "gy": int(pos.y / _px.y)}


func _crear_puerta(d: Array) -> void:
	var de: int = d[0]
	var a: int = d[1]
	var lado: String = d[2] if d.size() > 2 else "E"
	var coord: int = d[3] if d.size() > 3 else FILA_PUERTA
	var llaves: int = d[4] if d.size() > 4 else 1
	var la: TileMapLayer = _info[de].capa
	var lb: TileMapLayer = _info[a].capa
	var p := Puerta.new()
	p.name = "puerta_%d" % _n_puerta
	_n_puerta += 1
	p.llaves_requeridas = llaves
	p.lado = lado
	p.mostrar_aviso = modo != "maze"
	if lado == "E":
		la.set_cell(Vector2i(_cols - 1, coord), 0, FLOOR)
		la.set_cell(Vector2i(_cols - 1, coord + 1), 0, FLOOR)
		lb.set_cell(Vector2i(0, coord), 0, FLOOR)
		lb.set_cell(Vector2i(0, coord + 1), 0, FLOOR)
		p.position = Vector2(_px.x, (coord + 1) * TILE)
	else: ## "S": puerta en el borde sur de `de` y norte de `a`
		la.set_cell(Vector2i(coord, _filas - 1), 0, FLOOR)
		la.set_cell(Vector2i(coord + 1, _filas - 1), 0, FLOOR)
		lb.set_cell(Vector2i(coord, 0), 0, FLOOR)
		lb.set_cell(Vector2i(coord + 1, 0), 0, FLOOR)
		p.position = Vector2((coord + 1) * TILE, _px.y)
	p.collision_layer = 8 ## capa "pared"
	p.collision_mask = 0
	p.z_index = Constantes.Z_PUERTA
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE * 2, TILE * 2)
	forma.shape = rect
	p.add_child(forma)
	var spr := Sprite2D.new()
	spr.texture = load(RUTA_PUERTA_TEX)
	p.add_child(spr)
	_info[de].sala.add_child(p)
	if modo != "maze" and de == PUERTAS[-1][0] and Progreso.tutorial_completado():
		p.abrir()


func _spawn_jugador(pos: Vector2) -> void:
	_jugador = load(RUTA_JUGADOR).instantiate()
	_jugador.position = pos
	_jugador.scale = Vector2(ESC_JUGADOR, ESC_JUGADOR)
	add_child(_jugador)
	var cam: Camera2D = load(RUTA_CAMARA).instantiate()
	cam.position = pos
	cam.set("tamano_unidad", _px)
	add_child(cam)
	_transicion()


func _transicion() -> void:
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
	add_child(gestor)


## El enemigo de la lección de dash fuerte suelta la llave al morir.
## Diferido: añadir áreas durante el flush de física del golpe es ilegal.
func _soltar_llave(sala: Node, enemigo: Node2D) -> void:
	_soltar_llave_diferido.call_deferred(sala, enemigo.position)


func _soltar_llave_diferido(sala: Node, pos: Vector2) -> void:
	_pone(sala, RUTA_LLAVE, pos, 1.0)
	get_tree().call_group("tutorial_hud", "mensaje", "EL ENEMIGO SOLTÓ UNA LLAVE")


func _on_meta() -> void:
	completado.emit()


func _pone(padre: Node, ruta: String, pos: Vector2, esc: float) -> Node2D:
	var n: Node2D = load(ruta).instantiate()
	n.position = pos
	n.scale = Vector2(esc, esc)
	padre.add_child(n)
	return n


func _pone_recompensa(padre: Node, pos: Vector2, tipo: String) -> void:
	var rec: Node2D = load(RUTA_RECOMPENSA).instantiate()
	rec.tipo = tipo
	rec.position = pos
	padre.add_child(rec)


func _centro(celda: Vector2i) -> Vector2:
	return Vector2(celda) * TILE + Vector2(TILE, TILE) * 0.5


func _tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 8)
	var src := TileSetAtlasSource.new()
	src.texture = _atlas()
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for c in [FLOOR, WALL, BLOOD]:
		src.create_tile(c)
	var td := src.get_tile_data(WALL, 0)
	td.add_collision_polygon(0)
	var h := TILE * 0.5
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)
	]))
	return ts


## Atlas 240x60 en runtime: cada sprite (256 px) escalado a un tile de 60 px.
## Misma composición que el generador deprecado para que el arte sea coherente.
func _atlas() -> ImageTexture:
	var img := Image.create_empty(TILE * 4, TILE, false, Image.FORMAT_RGBA8)
	_blit(img, FLOOR, RUTA_SUELO1)
	_blit(img, WALL, RUTA_PARED)
	_blit(img, BLOOD, RUTA_SUELO2)
	return ImageTexture.create_from_image(img)


func _blit(img: Image, celda: Vector2i, ruta: String) -> void:
	var sub := (load(ruta) as Texture2D).get_image()
	sub.convert(Image.FORMAT_RGBA8)
	sub.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
	img.blit_rect(sub, Rect2i(0, 0, TILE, TILE), Vector2i(celda.x * TILE, 0))
