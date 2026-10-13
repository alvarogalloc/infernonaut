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
const FLOOR := Vector2i(0, 0) ## suelo base (suelo1.png)
const WALL := Vector2i(1, 0) ## pared (pared.png)
const PATH := Vector2i(2, 0) ## corredor por pared (suelo1.png)
const BLOOD := Vector2i(3, 0) ## variante de suelo (suelo2.png)
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
const RUTA_COBARDE := "res://scenes/enemigos/cobarde/cobarde.tscn"
const RUTA_PINCHO := "res://scenes/obstaculos/pincho/pincho.tscn"
const RUTA_ANTORCHA := "res://scenes/torch.tscn"
const RUTA_META := "res://scenes/objetivo/objetivo.tscn"
const RUTA_RECOMPENSA := "res://scenes/recompensas/recompensa.tscn"
const RUTA_GESTOR := "res://scenes/escena_principal/transicion_salas.gd"
const RUTA_WIPE := "res://scenes/escena_principal/transicion_wipe.gdshader"
const RUTA_SUELO1 := "res://sprites/suelo1.png"
const RUTA_SUELO2 := "res://sprites/suelo2.png"
const RUTA_PARED := "res://sprites/t3.png"
const RUTA_PUERTA_TEX := "res://sprites/puerta.png"

const ESC_RECOMPENSA := 1.0
const BLOQUEO_PINCHO := 1 ## radio (en tiles) que bloquea un pincho en la BFS
const DESPEJE_PUERTA := TILE * 3.0 ## px: nada de enemigos/pinchos tan cerca del hueco

var _rng := RandomNumberGenerator.new()
var _ts: TileSet
var _n_puerta := 0
var _densidades_activas: Dictionary = {}


## Devuelve un Node2D listo para añadir al árbol. plantilla < 0 = aleatoria.
## `densidades_entidad` = dict parcial de Constantes.DENSIDADES_ENTIDAD
## (0.0 = ninguna, 1.0 = base); las claves que falten usan el valor por
## defecto. Un único dict alimenta el menú y el generador.
func generar(semilla: int, plantilla: int = -1, densidades_entidad: Dictionary = {}) -> Node2D:
	_densidades_activas = Constantes.DENSIDADES_ENTIDAD.duplicate()
	for k in densidades_entidad:
		_densidades_activas[k] = maxf(float(densidades_entidad[k]), 0.0)
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
	_n_puerta = 0
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
		layer.z_index = Constantes.Z_TILEMAP
		_llenar(layer, spec[3], spec[4])
		var centros := _maze(layer, spec[3], spec[4])
		room.add_child(layer)
		root.add_child(room)
		salas.append({"gx": spec[1], "gy": spec[2], "w": spec[3], "h": spec[4], "layer": layer, "room": room, "nombre": spec[0], "centros": centros, "enemigos": [], "cand_pinchos": []})

	var specs_puerta: Array = []
	var puertas_por_sala: Array = [] ## centros de puerta locales a cada sala
	for _i in salas.size():
		puertas_por_sala.append([])
	for d in puertas:
		var spec := _abrir_puerta(salas[d[0]], salas[d[1]], d[2], d[0])
		specs_puerta.append(spec)
		var puerta_global: Vector2 = (salas[d[0]].room as Node2D).position \
				+ Vector2(spec.pos)
		for idx in [d[0], d[1]]:
			puertas_por_sala[idx].append(puerta_global - (salas[idx].room as Node2D).position)
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
		elif arquetipos[i] == "tesoro":
			## La celda de la recompensa queda protegida: sin enemigo/pincho.
			protegida = salas[i].centros[0]
		_contenido(salas[i], arquetipos[i], protegida, puertas_por_sala[i])
	_colocar_pinchos(salas, idx_meta, celda_meta, celda_inicio)
	_meta(salas[idx_meta], root, celda_meta)
	_ganchos_salas(salas, specs_puerta)

	var sp := (salas[0].room as Node2D).position + _celda_local(salas[0], celda_inicio)
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
	src.texture = _atlas()
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


## Atlas 240x60 en runtime: cada sprite (256 px) escalado a un tile de 60 px.
func _atlas() -> ImageTexture:
	var img := Image.create_empty(TILE * 4, TILE, false, Image.FORMAT_RGBA8)
	_blit(img, FLOOR, RUTA_SUELO1)
	_blit(img, WALL, RUTA_PARED)
	_blit(img, PATH, RUTA_SUELO1)
	_blit(img, BLOOD, RUTA_SUELO2)
	return ImageTexture.create_from_image(img)


func _blit(img: Image, celda: Vector2i, ruta: String) -> void:
	var sub := (load(ruta) as Texture2D).get_image()
	sub.convert(Image.FORMAT_RGBA8)
	sub.resize(TILE, TILE, Image.INTERPOLATE_LANCZOS)
	img.blit_rect(sub, Rect2i(0, 0, TILE, TILE), Vector2i(celda.x * TILE, 0))


func _llenar(layer: TileMapLayer, w: int, h: int) -> void:
	var cols := w * RU.x
	var rows := h * RU.y
	for y in rows:
		for x in cols:
			var borde := x == 0 or y == 0 or x == cols - 1 or y == rows - 1
			layer.set_cell(Vector2i(x, y), 0, WALL if borde else _suelo())


## Suelo aleatorio: mezcla suelo1.png (FLOOR) y suelo2.png (BLOOD).
func _suelo() -> Vector2i:
	return BLOOD if _rng.randf() < 0.5 else FLOOR


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
			layer.set_cell(Vector2i(sx, 1 + a.y * STRIDE + dy), 0, _suelo())
	else:
		var sy: int = maxi(a.y, b.y) * STRIDE
		for dx in 3:
			layer.set_cell(Vector2i(1 + a.x * STRIDE + dx, sy), 0, _suelo())


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


## Contenido curado por arquetipo: el core solo PROPONE una celda candidata;
## quién puede ocuparla lo deciden las reglas composables (_resolver_colocacion),
## no este código. Así el core queda mínimo y añadir/ajustar una condición de
## mundo = añadir una regla, sin tocar el generador.
## `protegida` = celda sin enemigo/pincho; `puertas_locales` = centros de puerta.
## Los pinchos se validan aparte (_colocar_pinchos) para no bloquear el paso.
## Cada tipo se escala con su densidad (Constantes.DENSIDADES_ENTIDAD);
## densidad 0.0 = ese tipo no aparece.
func _contenido(s: Dictionary, tipo: String, protegida: Vector2i, puertas_locales: Array) -> void:
	var room: Node2D = s.room
	var centros: Array = s.centros
	var base_enemigos := 2
	var base_pinchos := 1
	match tipo:
		"inicio":
			base_enemigos = 1
			base_pinchos = 0
		"combate":
			base_enemigos = 4
			base_pinchos = 1
		"trampa":
			base_enemigos = 2
			base_pinchos = 3
		"tesoro":
			base_enemigos = 2
			base_pinchos = 1
		"meta":
			base_enemigos = 3
			base_pinchos = 1
	var max_enemigos_sala := int(ceil(base_enemigos * _densidades_activas["densidad_enemigo_mele"]))
	var max_pinchos_sala := int(ceil(base_pinchos * _densidades_activas["densidad_pincho"]))
	var max_antorchas_sala := int(ceil(4.0 * _densidades_activas["densidad_antorcha"]))
	var num_enemigos_actual := 0
	var num_pinchos_actual := 0
	var num_antorchas_actual := 0
	var k := 0
	while k < centros.size() and (num_enemigos_actual < max_enemigos_sala or num_pinchos_actual < max_pinchos_sala or num_antorchas_actual < max_antorchas_sala):
		var celda: Vector2i = centros[k]
		var colocacion := _resolver_colocacion({
			"sala": s, "celda": celda, "pos": _celda_local(s, celda),
			"protegida": protegida, "puertas": puertas_locales, "tipo": tipo,
		})
		if colocacion.is_empty():
			k += 1
			continue
		var p: Vector2 = colocacion.pos
		if num_antorchas_actual < max_antorchas_sala and k % 3 == 0:
			if _densidades_activas["densidad_antorcha"] > 0.0:
				var ant := _pone(room, RUTA_ANTORCHA, "antorcha_%d" % k, p + Vector2(0, -TILE * 0.5), ESC_ANTORCHA)
				ant.z_index = Constantes.Z_ANTORCHA
			num_antorchas_actual += 1
		elif num_enemigos_actual < max_enemigos_sala and k % 2 == 1:
			if _densidades_activas["densidad_enemigo_mele"] > 0.0:
				var usa_variante_cobarde: bool = _densidades_activas["densidad_cobarde"] > 0.0 \
						and tipo in ["combate", "tesoro"] and num_enemigos_actual == 0 \
						and _rng.randf() < clampf(Constantes.PROB_COBARDE * _densidades_activas["densidad_cobarde"], 0.0, 1.0)
				var en := _pone(room, RUTA_COBARDE if usa_variante_cobarde else RUTA_ENEMIGO, "%s_enemigo_%d" % [s.nombre, k], p, ESC_ENEMIGO)
				s.enemigos.append(en)
				num_enemigos_actual += 1
		elif num_pinchos_actual < max_pinchos_sala and k % 2 == 0:
			if _densidades_activas["densidad_pincho"] > 0.0:
				s.cand_pinchos.append(celda)
				num_pinchos_actual += 1
		k += 1
	var densidad_recompensa: float = _densidades_activas["densidad_recompensa"]
	if tipo == "tesoro" and _rng.randf() < densidad_recompensa:
		var rec: Node2D = load(RUTA_RECOMPENSA).instantiate()
		rec.name = "recompensa"
		rec.tipo = "escudo" if _rng.randf() < 0.5 else "dash_sombra"
		rec.position = _celda_local(s, protegida)
		room.add_child(rec)


## --- Colocación por reglas (worldgen) ---------------------------------
## El core propone una celda y pregunta a estas reglas composables, en orden.
## Cada regla recibe la "plaza" {sala, celda, pos, protegida, puertas, tipo}:
##   true    -> pasa
##   false   -> rechazada; el core prueba la SIGUIENTE celda candidata
##   Vector2 -> muta la posición propuesta y se sigue con las demás reglas
## Añadir una condición de colocación = añadir una función a esta lista.
func _reglas_colocacion() -> Array:
	return [
		_regla_dentro_de_la_sala,
		_regla_fuera_de_protegida,
		_regla_lejos_de_puertas,
	]


func _resolver_colocacion(plaza: Dictionary) -> Dictionary:
	for regla in _reglas_colocacion():
		var r: Variant = regla.call(plaza)
		if r == false:
			return {}
		if r is Vector2:
			plaza.pos = r
	return plaza


## El contenido nunca cae en el marco de paredes: muta la posición hacia dentro.
func _regla_dentro_de_la_sala(plaza: Dictionary) -> Variant:
	var s: Dictionary = plaza.sala
	var dentro := Vector2(
		clampf(plaza.pos.x, TILE, (s.w * RU.x - 1) * TILE),
		clampf(plaza.pos.y, TILE, (s.h * RU.y - 1) * TILE)
	)
	return dentro if dentro != plaza.pos else true


## La celda protegida (inicio/meta/recompensa) queda limpia.
func _regla_fuera_de_protegida(plaza: Dictionary) -> bool:
	return plaza.celda != plaza.protegida


## Nada a menos de DESPEJE_PUERTA px del hueco de una puerta: entrar por la
## puerta (spawn junto a ella) nunca cae sobre un enemigo/pincho/antorcha.
func _regla_lejos_de_puertas(plaza: Dictionary) -> bool:
	for dp in plaza.puertas:
		if plaza.pos.distance_to(dp) < DESPEJE_PUERTA:
			return false
	return true


## Trampas/pinchos: instakill -> NUNCA se colocan sobre el corredor
## garantizado salida->meta (la ruta principal queda despejada, así una sala
## no puede volverse imposible), y además se valida que no corten la
## conexión por otra vía. Nuevos obstáculos: reutiliza cand_pinchos o añade
## su lista de candidatas; la invariante la garantiza _ruta_principal.
func _colocar_pinchos(salas: Array, idx_meta: int, celda_meta: Vector2i, celda_inicio: Vector2i) -> void:
	var meta: Vector2i = Vector2i((salas[idx_meta].room as Node2D).position) / TILE + celda_meta
	var inicio: Vector2i = Vector2i((salas[0].room as Node2D).position) / TILE + celda_inicio
	var ruta := _ruta_principal(salas, inicio, meta)
	var bloqueados := {}
	for s in salas:
		for celda_candidata in s.cand_pinchos:
			var celda_global_pincho: Vector2i = Vector2i((s.room as Node2D).position / TILE) + celda_candidata
			if ruta.has(celda_global_pincho):
				continue
			if _pincho_ok(salas, inicio, meta, bloqueados, s, celda_candidata):
				_crear_pincho(s, celda_candidata)
				_marcar_pincho(bloqueados, s, celda_candidata)


func _crear_pincho(s: Dictionary, celda: Vector2i) -> void:
	_pone(s.room, RUTA_PINCHO, "%s_pincho_%d" % [s.nombre, celda.x * 1000 + celda.y], _celda_local(s, celda), ESC_PINCHO)


func _marcar_pincho(bloqueados: Dictionary, s: Dictionary, celda: Vector2i) -> void:
	var g := Vector2i((s.room as Node2D).position / TILE) + celda
	for dy in range(-BLOQUEO_PINCHO, BLOQUEO_PINCHO + 1):
		for dx in range(-BLOQUEO_PINCHO, BLOQUEO_PINCHO + 1):
			bloqueados[g + Vector2i(dx, dy)] = true


func _pincho_ok(salas: Array, inicio: Vector2i, meta: Vector2i, bloqueados: Dictionary, s: Dictionary, celda: Vector2i) -> bool:
	var copia := bloqueados.duplicate()
	_marcar_pincho(copia, s, celda)
	return _alcanza_evitando(salas, inicio, meta, copia)


## true si desde `inicio` se llega a `meta` sin pisar tiles bloqueados.
func _alcanza_evitando(salas: Array, inicio: Vector2i, meta: Vector2i, bloqueados: Dictionary) -> bool:
	var walk := _caminables(salas)
	if not walk.has(inicio) or not walk.has(meta):
		return false
	var visto := {inicio: true}
	var cola: Array = [inicio]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while cola.size() > 0:
		var c: Vector2i = cola.pop_back()
		for d in dirs:
			var n: Vector2i = c + d
			if walk.has(n) and not bloqueados.has(n) and not visto.has(n):
				visto[n] = true
				cola.append(n)
	return visto.has(meta)


## Tiles transitables (todo tile que no es pared) en coordenadas globales.
func _caminables(salas: Array) -> Dictionary:
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
	return walk


## Un corredor de tiles garantizado salida->meta (BFS con padres). Los
## obstáculos solo se colocan FUERA de él: el camino del jugador nunca se
## bloquea. Devuelve {} si no hay conexión (no debería pasar: el nivel se
## generó conexo).
func _ruta_principal(salas: Array, inicio: Vector2i, meta: Vector2i) -> Dictionary:
	var walk := _caminables(salas)
	if not walk.has(inicio) or not walk.has(meta):
		return {}
	var padres := {inicio: inicio}
	var cola: Array = [inicio]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while cola.size() > 0:
		var c: Vector2i = cola.pop_back()
		if c == meta:
			var ruta := {}
			var cur := meta
			while true:
				ruta[cur] = true
				if cur == inicio:
					break
				cur = padres[cur]
			return ruta
		for d in dirs:
			var n: Vector2i = c + d
			if walk.has(n) and not padres.has(n):
				padres[n] = c
				cola.append(n)
	return {}


func _pone(padre: Node, ruta: String, nombre: String, pos: Vector2, esc: float) -> Node2D:
	var n: Node2D = load(ruta).instantiate()
	n.name = nombre
	n.position = pos
	n.scale = Vector2(esc, esc)
	padre.add_child(n)
	return n


func _meta(s: Dictionary, root: Node, celda: Vector2i) -> void:
	var meta: Node2D = load(RUTA_META).instantiate()
	meta.name = "meta"
	meta.position = (s.room as Node2D).position + _celda_local(s, celda)
	meta.scale = Vector2(ESC_META, ESC_META)
	root.add_child(meta)


## Centro (en píxeles) de `celda`, LOCAL a la sala (para nodos hijos de la
## sala). Para nodos hijos de `root` súmale `room.position`.
func _celda_local(_s: Dictionary, celda: Vector2i) -> Vector2:
	return Vector2(celda) * TILE + Vector2(TILE, TILE) * 0.5


## Excava el hueco de la puerta en ambas salas y devuelve la geometría de
## la barrera (dueño = índice de la sala `a`). La barrera es un nodo hijo de
## la sala `a`; su `pos` es local a esa sala.
func _abrir_puerta(a: Dictionary, b: Dictionary, lado: String, dueno: int) -> Dictionary:
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
		return {
			"dueno": dueno,
			"pos": Vector2(a.w * RU.x * TILE, (centro - a.gy * RU.y) * TILE),
			"tam": Vector2(PUERTA_TILES * TILE, PUERTA_TILES * TILE),
		}
	var lo := maxi(a.gx, b.gx) * RU.x
	var hi := mini(a.gx + a.w, b.gx + b.w) * RU.x
	var centro := (lo + hi) / 2
	for col in PUERTA_TILES:
		var gcx := centro - PUERTA_TILES / 2 + col
		la.erase_cell(Vector2i(gcx - a.gx * RU.x, a.h * RU.y - 1))
		lb.erase_cell(Vector2i(gcx - b.gx * RU.x, 0))
	return {
		"dueno": dueno,
		"pos": Vector2((centro - a.gx * RU.x) * TILE, a.h * RU.y * TILE),
		"tam": Vector2(PUERTA_TILES * TILE, PUERTA_TILES * TILE),
	}


## Crea las barreras (hijas de su sala dueña) y un controlador Sala por
## sala. Cada Sala abre sus puertas cuando mueren todos sus enemigos.
func _ganchos_salas(salas: Array, specs: Array) -> void:
	var por_sala: Array = []
	for _i in salas.size():
		por_sala.append([])
	for spec in specs:
		var p := _crear_puerta(spec)
		(salas[spec.dueno].room as Node).add_child(p)
		por_sala[spec.dueno].append(p)
	for i in salas.size():
		var s: Dictionary = salas[i]
		var ctrl := Sala.new()
		ctrl.name = "controlador_sala"
		(s.room as Node).add_child(ctrl)
		ctrl.configurar(s.enemigos, por_sala[i])


func _crear_puerta(spec: Dictionary) -> Puerta:
	var p := Puerta.new()
	p.name = "puerta_%d" % _n_puerta
	_n_puerta += 1
	p.position = spec.pos
	p.collision_layer = 8 ## capa "pared" (project.godot)
	p.collision_mask = 0
	p.z_index = Constantes.Z_PUERTA
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = spec.tam
	forma.shape = rect
	p.add_child(forma)
	var spr := Sprite2D.new()
	spr.texture = load(RUTA_PUERTA_TEX)
	p.add_child(spr)
	return p


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
	var walk := _caminables(salas)
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
