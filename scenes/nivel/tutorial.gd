extends Node2D
## Tutorial curado (sin generación procedural): seis salas en fila.
## Cada sala enseña una acción y esconde una llave; la puerta al este la
## consume. Los mapas son fijos (30x16 interior) y se construyen una vez.
##
## Uso: desde juego.gd, instanciar y añadir al árbol. `solo_arena = true`
## construye únicamente la arena (modo desbloqueado tras el tutorial).

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

@export var solo_arena := false

var _ts: TileSet
var _info: Array = []
var _jugador: Node2D = null
var _hud: Node = null
var _leccion := -1


func _ready() -> void:
	_ts = _tileset()
	_info.resize(MAPAS.size())
	if solo_arena:
		var i := MAPAS.size() - 1
		_crear_sala(i, Vector2.ZERO)
		_spawn_jugador(_info[i].inicio)
	else:
		for i in MAPAS.size():
			_crear_sala(i, Vector2(i * PX.x, 0.0))
		for d in PUERTAS:
			_crear_puerta(d[0], d[1])
		_spawn_jugador(_info[0].inicio)
	_hud = load(RUTA_HUD).instantiate()
	add_child(_hud)
	var oscuro := CanvasModulate.new()
	oscuro.color = Color(0.82, 0.78, 0.82)
	add_child(oscuro)


func _process(_delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		return
	var indice := MAPAS.size() - 1 if solo_arena \
			else clampi(int(_jugador.global_position.x / PX.x), 0, MAPAS.size() - 1)
	if indice != _leccion:
		_leccion = indice
		if _hud != null:
			_hud.call("mostrar_leccion", indice)


func _crear_sala(indice: int, pos: Vector2) -> void:
	var mapa: Array = MAPAS[indice]
	assert(mapa.size() == FILAS - 2, "mapa %d: filas" % indice)
	var sala := Node2D.new()
	sala.name = "sala_%d" % indice
	sala.position = pos
	add_child(sala)
	var capa := TileMapLayer.new()
	capa.name = "blockout"
	capa.tile_set = _ts
	capa.z_index = Constantes.Z_TILEMAP
	sala.add_child(capa)

	var inicio := Vector2.ZERO
	for y in FILAS:
		if y > 0 and y < FILAS - 1:
			assert(mapa[y - 1].length() == COLS - 2, "mapa %d fila %d" % [indice, y - 1])
		for x in COLS:
			var celda := Vector2i(x, y)
			var borde := x <= 0 or y <= 0 or x >= COLS - 1 or y >= FILAS - 1
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
	_info[indice] = {"sala": sala, "capa": capa, "inicio": inicio}


func _crear_puerta(de: int, a: int) -> void:
	var la: TileMapLayer = _info[de].capa
	var lb: TileMapLayer = _info[a].capa
	# El hueco se pisa con suelo (sin colisión); la puerta es la única barrera.
	la.set_cell(Vector2i(COLS - 1, FILA_PUERTA), 0, FLOOR)
	la.set_cell(Vector2i(COLS - 1, FILA_PUERTA + 1), 0, FLOOR)
	lb.set_cell(Vector2i(0, FILA_PUERTA), 0, FLOOR)
	lb.set_cell(Vector2i(0, FILA_PUERTA + 1), 0, FLOOR)

	var p := Puerta.new()
	p.name = "puerta_%d" % de
	p.position = Vector2(PX.x, (FILA_PUERTA + 1) * TILE)
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
	if de == PUERTAS[-1][0] and Progreso.tutorial_completado():
		p.abrir()


func _spawn_jugador(pos: Vector2) -> void:
	_jugador = load(RUTA_JUGADOR).instantiate()
	_jugador.position = pos
	_jugador.scale = Vector2(ESC_JUGADOR, ESC_JUGADOR)
	add_child(_jugador)
	var cam: Camera2D = load(RUTA_CAMARA).instantiate()
	cam.position = pos
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
