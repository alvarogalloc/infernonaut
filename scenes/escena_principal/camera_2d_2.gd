@tool
extends Camera2D
## Cámara con enfoque suave al jugador y cambio de habitación vía transición con wipe.
## Objetivo: tamaño estándar para el viewport, ajustable automáticamente a salas mxn.
## Mantener solo lo necesario: seguir jugador, detectar cambio de sala y comunicar con gestor.

@export var animar: bool = true
@export var duracion_transicion: float = 0.45
@export var tipo_transicion: Tween.TransitionType = Tween.TRANS_CUBIC
## Cuánto se encoge por lado la zona que dispara el cambio respecto al
## cuarto. Con valores > 0 el cambio ocurre más adentro (en la puerta).
@export var margen_trigger: Vector2 = Vector2(128, 128):
	set(v):
		margen_trigger = v
		queue_redraw()
@export var puerta_margen: float = 64.0
## Sacudida tras el dash (solo activa si el jugador pone dash_kick > 0).
@export var kick_max: float = 40.0 ## px máx de patada direccional
@export var kick_recuperacion: float = 300.0 ## px/s de caída de la patada
@export var shake_max: float = 16.0 ## px máx de temblor
@export var shake_decay: float = 1.5 ## caída del temblor por segundo
@export var mostrar_areas: bool = false ## dibujar triggers/salas también en juego
## Ajuste de vista: zoom fijo para que 1 unidad de sala (1x1) llene el viewport.
@export var viewport_base: Vector2 = Vector2(1920, 1080) ## tamaño de ventana (px)
## 1x1 sala en px: 32x18 tiles de 60px. Salas mayores = pan, no zoom-out.
@export var tamano_unidad: Vector2 = Vector2(1920, 1080)
@export var smooth_speed: float = 10.0 ## lerp suave al seguir jugador
@export var lock_to_room: bool = true ## false = sigue libre (experimental)

## Se emite al detectar un cuarto nuevo. El gestor de transicion la usa
## para el wipe + teletransporte; sin gestor, la camara desliza sola.
signal sala_solicitada(nueva: Node2D)

var _jugador: Node2D = null
var _habitaciones: Array[Node2D] = []
var _rect_cache: Dictionary = {}
var _actual: Node2D = null
var _tween: Tween = null
var _kick: Vector2 = Vector2.ZERO
var _trauma: float = 0.0
var _ruido := FastNoiseLite.new()
var _ruido_t: int = 0
var _target_pos: Vector2 = Vector2.ZERO
var _room_zoom: Vector2 = Vector2.ONE


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("camara_jugador") # el dash llama a patada_dash() por grupo
	set_as_top_level(true)
	make_current()
	position_smoothing_enabled = false
	_ruido.seed = randi()
	_ruido.frequency = 5.0
	_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coleccionar_habitaciones()
	_centrar_en_jugador(true)


## Enfoque al jugador suavemente. Cuando cambia de habitación, delega a gestor (wipe).
## Para encuadre por sala: ajusta zoom/posición para que el rect de sala + padding
## quepa en viewport_base (mantiene relación aspecto).
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Kick/shake mínimo (se puede simplificar luego)
	if _kick == Vector2.ZERO and _trauma <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		# seguir jugador: foco con clamp según el tipo de sala
		if _jugador != null and is_instance_valid(_jugador):
			_target_pos = _foco(_jugador.global_position)
		global_position = global_position.lerp(_target_pos, smooth_speed * delta)
		return
	# ... código existente de kick/shake truncado abajo: simplificar
	_ruido_t += 1
	_kick = _kick.move_toward(Vector2.ZERO, kick_recuperacion * delta)
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var temblor := Vector2(
		_ruido.get_noise_2d(_ruido.seed, _ruido_t),
		_ruido.get_noise_2d(_ruido.seed + 100, _ruido_t)
	) * shake_max * _trauma * _trauma
	offset = _kick + temblor
	if _jugador != null:
		_target_pos = _foco(_jugador.global_position)
	global_position = global_position.lerp(_target_pos, smooth_speed * delta)


## Patada direccional del dash (Celeste: shake sesgado al dash, 3-4px…
## aqui escalado al tamaño de sala). Llamado por grupo desde el jugador.
func patada_dash(direccion: Vector2, fuerza: float) -> void:
	_kick = (_kick + direccion.normalized() * fuerza).limit_length(kick_max)
	_trauma = clampf(_trauma + 0.35, 0.0, 1.0)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_coleccionar_habitaciones()
		queue_redraw()
		return
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES) as Node2D
		if _jugador == null:
			return
		_target_pos = _jugador.global_position
		_centrar_en_jugador(true)
		return
	if _habitaciones.is_empty():
		_coleccionar_habitaciones()
		if _habitaciones.is_empty():
			return
	var pos := _jugador.global_position
	if _actual == null or not is_instance_valid(_actual):
		_actual = _habitacion_de(pos)
		if _actual != null:
			_enfocar_sala(_actual)
			_target_pos = _foco(pos)
		return
	# detectar vecino
	for cuarto in _habitaciones:
		if cuarto != _actual and is_instance_valid(cuarto) and _trigger_de(cuarto).has_point(pos):
			_cambiar_sala(cuarto)
			return
	var vecina := _sala_vecina(pos, _actual)
	if vecina != null:
		_cambiar_sala(vecina)


## Cambio a la siguiente habitación.
## - Emite señal para transición suave (wipe) si el gestor existe.
## - Si no hay gestor, hace una transición suave instantánea siguiendo al jugador? no.
## Ahora: siempre que haya gestor activo, delegamos a él. Si no, encuadre suave.
func _cambiar_sala(nueva: Node2D) -> void:
	if nueva == _actual:
		return
	# Emitir ANTES de mover _actual: el gestor lee sala_actual() para
	# calcular la dirección del wipe (si no, siempre da 0 y el barrido
	# sale siempre hacia la derecha).
	sala_solicitada.emit(nueva)
	_actual = nueva
	# El gestor (transicion_salas) hará el wipe + teletransporte + fijar_sala.
	# Si no hay gestor activo, la cámara desliza sola.
	if not _transicion_activa():
		_enfocar_sala(nueva)
		_target_pos = _foco(_jugador.global_position)
		_ir_a(_target_pos)


func _transicion_activa() -> bool:
	var m := get_tree().get_first_node_in_group("transicion_salas")
	return m != null and is_instance_valid(m) and m.get("activa") == true


## API publica para el gestor de transicion.
func sala_actual() -> Node2D:
	return _actual


## true si `punto` cae dentro del marco (rect+puerta_margen) de OTRA sala.
## Lo usa el gestor para no soltar al jugador encima del marco de la sala
## de la que viene (salas con pisos solapados -> ping-pong de transiciones).
func en_marco_ajeno(punto: Vector2, excluir: Node2D) -> bool:
	return _sala_vecina(punto, excluir) != null


func sala_rect(cuarto: Node2D) -> Rect2:
	if cuarto == null or not is_instance_valid(cuarto):
		return Rect2()
	return _rect_cacheado(cuarto)


func sala_centro(cuarto: Node2D) -> Vector2:
	if cuarto == null or not is_instance_valid(cuarto):
		return global_position
	return _centro(cuarto)


## Encuadre instantaneo en la sala (llamado en negro durante el wipe).
func fijar_sala(cuarto: Node2D) -> void:
	if cuarto == null or not is_instance_valid(cuarto):
		return
	_actual = cuarto
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_enfocar_sala(cuarto)
	var foco := _centro(cuarto)
	if _jugador != null and is_instance_valid(_jugador):
		foco = _foco(_jugador.global_position)
	global_position = foco
	_target_pos = global_position


func _draw() -> void:
	if not Engine.is_editor_hint() and not mostrar_areas:
		return
	if not is_inside_tree() or get_parent() == null:
		return
	for cuarto in _habitaciones:
		if not is_instance_valid(cuarto):
			continue
		var sala := _a_local(_rect_de(cuarto))
		var zona := _a_local(_trigger_de(cuarto))
		var puerta := _a_local(_rect_cacheado(cuarto).grow(puerta_margen))
		draw_rect(sala, Color(0.2, 1.0, 0.4, 0.10), true) # relleno cuarto
		draw_rect(sala, Color(0.2, 1.0, 0.4, 0.9), false, 8.0) # borde cuarto
		draw_rect(zona, Color(1.0, 0.8, 0.2, 0.10), true) # relleno trigger
		draw_rect(zona, Color(1.0, 0.8, 0.2, 0.9), false, 6.0) # borde trigger
		draw_rect(puerta, Color(0.4, 0.6, 1.0, 0.9), false, 4.0) # marco puerta


## Rect global -> coordenadas locales del nodo (para _draw de la cámara).
func _a_local(r: Rect2) -> Rect2:
	return Rect2(to_local(r.position), r.size)


func _ir_a(destino: Vector2) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animar:
		global_position = destino
		return
	_tween = create_tween().set_trans(tipo_transicion).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", destino, duracion_transicion)


func _centrar_en_jugador(forzar: bool = false) -> void:
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES) as Node2D
	if _jugador == null:
		return
	_actual = _habitacion_de(_jugador.global_position)
	if _actual != null:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_enfocar_sala(_actual)
		global_position = _foco(_jugador.global_position)
		_target_pos = global_position
	elif forzar:
		global_position = _jugador.global_position
		_target_pos = global_position


func _coleccionar_habitaciones() -> void:
	_habitaciones.clear()
	_rect_cache.clear()
	var padre := get_parent()
	if padre == null:
		return
	# Cada hijo del nivel que contenga un TileMapLayer es una habitación.
	# Así no hay que configurar nada por cuarto ni mantener un ROOM_SIZE a mano.
	for hijo in padre.get_children():
		if hijo is Node2D and _tiene_tilemap(hijo):
			_habitaciones.append(hijo)


func _tiene_tilemap(nodo: Node) -> bool:
	if nodo is TileMapLayer:
		return true
	for hijo in nodo.get_children():
		if _tiene_tilemap(hijo):
			return true
	return false


## Rect global que ocupa una habitación (unión de sus TileMapLayers).
## Cacheado: get_used_rect() cada frame x N cuartos era el coste mayor.
func _rect_cacheado(cuarto: Node2D) -> Rect2:
	if _rect_cache.has(cuarto):
		return _rect_cache[cuarto]
	var rect := Rect2()
	var primero := true
	for capa in _capas(cuarto):
		if capa.tile_set == null:
			continue
		var celdas := capa.get_used_rect()
		# Capa vacía: get_used_rect() = (0,0,0,0) y merge() metería el
		# punto (0,0) global en el rect de la sala, ensuciando triggers.
		if celdas.size == Vector2i.ZERO:
			continue
		var media_celda := Vector2(capa.tile_set.tile_size) * 0.5
		var origen := capa.to_global(capa.map_to_local(celdas.position)) - media_celda
		var tam := Vector2(celdas.size) * Vector2(capa.tile_set.tile_size)
		var r := Rect2(origen, tam)
		if primero:
			rect = r
			primero = false
		else:
			rect = rect.merge(r)
	_rect_cache[cuarto] = rect
	return rect


## Rect global que ocupa una habitación (unión de sus TileMapLayers).
func _rect_de(cuarto: Node2D) -> Rect2:
	return _rect_cacheado(cuarto)


## Zona que dispara el cambio: el cuarto encogido por el margen.
## Lo de fuera (puertas/pasillos) lo cubre _sala_vecina con puerta_margen.
func _trigger_de(cuarto: Node2D) -> Rect2:
	var rect := _rect_de(cuarto)
	return rect.grow_individual(-margen_trigger.x, -margen_trigger.y, -margen_trigger.x, -margen_trigger.y)


func _capas(nodo: Node) -> Array[TileMapLayer]:
	var lista: Array[TileMapLayer] = []
	_recolectar_capas(nodo, lista)
	return lista


func _recolectar_capas(nodo: Node, lista: Array[TileMapLayer]) -> void:
	if nodo is TileMapLayer:
		lista.append(nodo)
	for hijo in nodo.get_children():
		_recolectar_capas(hijo, lista)


## Zoom FIJO: una unidad de sala (1x1) llena el viewport. Las salas más
## grandes hacen pan (ver _foco), nunca zoom-out — patrón Isaac/Zelda.
func _enfocar_sala(_cuarto: Node2D) -> void:
	var z := Vector2(
		viewport_base.x / maxf(tamano_unidad.x, 1.0),
		viewport_base.y / maxf(tamano_unidad.y, 1.0)
	)
	zoom = z
	_room_zoom = zoom


## Mitad del área visible en px de mundo.
func _vista_media() -> Vector2:
	var z := zoom
	return Vector2(
		viewport_base.x / maxf(z.x, 0.001),
		viewport_base.y / maxf(z.y, 0.001)
	) * 0.5


## Punto que debe mirar la cámara. Sigue al jugador solo en los ejes donde
## la sala supera el viewport; en el resto fija el centro (regla del GDD):
## 1x1 fija, nx1 fija en Y y sigue en X, 1xn fija en X, nxm sigue ambos.
func _foco(p: Vector2) -> Vector2:
	if _actual == null or not is_instance_valid(_actual):
		return p
	var r := _rect_de(_actual)
	var m := _vista_media()
	var c := r.get_center()
	var f := p
	if r.size.x <= m.x * 2.0:
		f.x = c.x
	else:
		f.x = clampf(p.x, r.position.x + m.x, r.end.x - m.x)
	if r.size.y <= m.y * 2.0:
		f.y = c.y
	else:
		f.y = clampf(p.y, r.position.y + m.y, r.end.y - m.y)
	return f


func _centro(cuarto: Node2D) -> Vector2:
	return _rect_de(cuarto).get_center()


## Cuarto cuyo trigger contiene el punto, o el más cercano si está en una puerta/pasillo.
## (Solo se usa al iniciar; en juego las salas son "sticky", ver _sala_vecina.)
func _habitacion_de(punto: Vector2) -> Node2D:
	for cuarto in _habitaciones:
		if _trigger_de(cuarto).has_point(punto):
			return cuarto
	var mejor: Node2D = null
	var mejor_dist := INF
	for cuarto in _habitaciones:
		var d := punto.distance_squared_to(_centro(cuarto))
		if d < mejor_dist:
			mejor_dist = d
			mejor = cuarto
	return mejor


## Sala vecina cuyo marco (rect completo + puerta_margen) contiene el punto.
## Es lo que dispara el cambio al cruzar una puerta — patron de los
## dungeon crawlers con puertas (isaac_room_transition: Door Area2D que
## emite la transicion al entrar, aqui sin nodos extra porque las salas
## ya son hermanas estaticas). null si sigues en la actual o en el vacio.
## Si varios marcos solapan (juntas de salas), gana el centro mas cercano,
## no el primero en orden de arbol (eso elegia la sala equivocada).
func _sala_vecina(punto: Vector2, actual: Node2D) -> Node2D:
	var mejor: Node2D = null
	var mejor_dist := INF
	for cuarto in _habitaciones:
		if cuarto == actual or not is_instance_valid(cuarto):
			continue
		if _rect_cacheado(cuarto).grow(puerta_margen).has_point(punto):
			var d := punto.distance_squared_to(_centro(cuarto))
			if d < mejor_dist:
				mejor_dist = d
				mejor = cuarto
	return mejor
