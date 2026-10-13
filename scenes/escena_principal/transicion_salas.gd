extends Node
## Room transition manager: directional dark wipe, place the player just inside
## the next room beside the door just crossed, wipe back.
##
## FLOW: camera detects the neighbor -> signal -> cover (dark sweeps toward
## travel side) -> player set beside the shared door -> camera snaps
## instantly (hidden in black) -> reveal.
##
## TUNABLES: duracion_cubrir / duracion_revelar (speed), tipo_transicion
## + ease_transicion (tween feel), desplazamiento_puerta (how far past the
## door), margen_seguro (fallback inset), retardo_negro (hold at full black).

@export_group("Velocidad")
@export var duracion_cubrir: float = 0.35 ## seconds: dark sweep in
@export var duracion_revelar: float = 0.45 ## seconds: dark sweep out
@export var retardo_negro: float = 0.05 ## hold at full cover before teleport
@export_group("Tween")
@export var tipo_transicion: Tween.TransitionType = Tween.TRANS_CUBIC
@export var ease_transicion: Tween.EaseType = Tween.EASE_IN_OUT
@export_group("Destino")
@export var desplazamiento_puerta: float = 120.0 ## px dentro de la sala nueva
@export var margen_seguro: float = 180.0 ## fallback: inset desde las paredes
@export var activa: bool = true ## false = camera falls back to slide
@export_group("Anti-caza al entrar")
@export var gracia_anti_caza: float = 1.0 ## s sin caza tras entrar a una sala

const MARGEN_BORDE := 60.0 ## px de seguridad contra las paredes al aparecer

@onready var _pantalla: ColorRect = $Capa/Color
var _ocupada: bool = false
var _seq: int = 0
var _camara: Camera2D = null
var _jugador: Node2D = null


func _ready() -> void:
	add_to_group("transicion_salas")
	_jugador = get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	_camara = get_tree().get_first_node_in_group("camara_jugador")
	if _camara != null and _camara.has_signal("sala_solicitada"):
		_camara.sala_solicitada.connect(_on_sala_solicitada)
	_material().set_shader_parameter("progreso", 0.0)


func _material() -> ShaderMaterial:
	return _pantalla.material as ShaderMaterial


func _on_sala_solicitada(nueva: Node2D) -> void:
	if not activa or _ocupada:
		return
	if _camara == null or _jugador == null:
		return
	if not is_instance_valid(nueva) or not is_instance_valid(_jugador):
		return
	_transicionar(nueva)


func _transicionar(nueva: Node2D) -> void:
	_ocupada = true
	_seq += 1
	_failsafe(_seq) # never leave the screen black if something hangs
	# La sala de ORIGEN se captura aquí, antes de cualquier await: en cuanto
	# cedemos el control, `_cambiar_sala` marca `nueva` como actual y se
	# perdería la puerta compartida (ese era el spawn "aleatorio").
	var vieja: Node2D = _camara.sala_actual()
	# Freeze player input/movement; enemy activation areas untouched.
	if _jugador.has_method("set_transicionando"):
		_jugador.set_transicionando(true)
	var vieja_centro: Vector2 = _camara.sala_centro(vieja)
	var nueva_centro: Vector2 = _camara.sala_centro(nueva)
	_material().set_shader_parameter("direccion", _eje_dominante(nueva_centro - vieja_centro))
	_preparar_caza(vieja, nueva)
	# 1. Cover: darkness chases the travel direction.
	await _barrer(0.0, 1.0, duracion_cubrir)
	if retardo_negro > 0.0:
		await get_tree().create_timer(retardo_negro, true, false, true).timeout
	# 2. Place the player just inside, beside the door just crossed (hidden
	# in black), snap camera.
	if is_instance_valid(_jugador) and _jugador.has_method("teletransportar"):
		_jugador.teletransportar(_punto_entrada(vieja, nueva))
	_camara.fijar_sala(nueva)
	# 3. Reveal: darkness recedes, new room reads from the entry side.
	await _barrer(1.0, 0.0, duracion_revelar)
	if is_instance_valid(_jugador) and _jugador.has_method("set_transicionando"):
		_jugador.set_transicionando(false)
	_ocupada = false


## Failsafe: if a transition hasn't finished in a few seconds (killed
## tween, freed node, whatever), force the overlay transparent and unlock.
## Same generation check so a newer transition is never disturbed.
func _failsafe(marca: int) -> void:
	await get_tree().create_timer(4.0, true, false, true).timeout
	if marca != _seq or not _ocupada:
		return
	if is_instance_valid(_pantalla):
		_material().set_shader_parameter("progreso", 0.0)
	if is_instance_valid(_jugador) and _jugador.has_method("set_transicionando"):
		_jugador.set_transicionando(false)
	_ocupada = false


## Tween shader progreso; PROCESS-mode so a pause/death screen can't
## freeze us on a black frame.
func _barrer(desde: float, hasta: float, duracion: float) -> void:
	_material().set_shader_parameter("progreso", desde)
	if duracion <= 0.0:
		_material().set_shader_parameter("progreso", hasta)
		return
	var tween := create_tween().set_trans(tipo_transicion).set_ease(ease_transicion)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_material(), "shader_parameter/progreso", hasta, maxf(duracion, 0.05))
	await tween.finished


## Punto de aparición al cruzar una puerta: JUNTO a la puerta compartida, unos
## píxeles dentro de la sala nueva (no al centro). `vieja`/`nueva` son las dos
## salas del cruce; el borde y la fila de la puerta salen del solape de sus
## rects, la misma geometría con la que el generador abrió la puerta.
func _punto_entrada(vieja: Node2D, nueva: Node2D) -> Vector2:
	if vieja == null or not is_instance_valid(vieja) or vieja == nueva:
		return _punto_seguro(nueva)
	var rn: Rect2 = _camara.sala_rect(nueva)
	var rv: Rect2 = _camara.sala_rect(vieja)
	if rn.size == Vector2.ZERO or rv.size == Vector2.ZERO:
		return _camara.sala_centro(nueva)
	var separacion := rn.get_center() - rv.get_center()
	var p: Vector2
	if absf(separacion.x) >= absf(separacion.y):
		# Vecinas en X: borde vertical compartido, fila = centro del solape.
		var y := (maxf(rn.position.y, rv.position.y) + minf(rn.end.y, rv.end.y)) * 0.5
		var x := (rn.position.x + desplazamiento_puerta) if separacion.x > 0.0 \
				else (rn.end.x - desplazamiento_puerta)
		p = Vector2(x, y)
	else:
		# Vecinas en Y: borde horizontal compartido, columna = centro del solape.
		var x := (maxf(rn.position.x, rv.position.x) + minf(rn.end.x, rv.end.x)) * 0.5
		var y := (rn.position.y + desplazamiento_puerta) if separacion.y > 0.0 \
				else (rn.end.y - desplazamiento_puerta)
		p = Vector2(x, y)
	return Vector2(
		clampf(p.x, rn.position.x + MARGEN_BORDE, rn.end.x - MARGEN_BORDE),
		clampf(p.y, rn.position.y + MARGEN_BORDE, rn.end.y - MARGEN_BORDE)
	)


## Fallback (sin sala previa reconocible): clamp de la posición a la sala
## nueva encogida por el margen, alejándolo del marco de otras salas para no
## provocar ping-pong de transiciones.
func _punto_seguro(nueva: Node2D) -> Vector2:
	var rect: Rect2 = _camara.sala_rect(nueva).grow(-margen_seguro)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return _camara.sala_centro(nueva)
	var p: Vector2 = _jugador.global_position
	p = Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	var centro: Vector2 = _camara.sala_centro(nueva)
	for _i in 8:
		if not _camara.en_marco_ajeno(p, nueva):
			break
		p = p.lerp(centro, 0.5)
	return p


## Al empezar la transición: la sala que se abandona deja de perseguir; la
## sala nueva suelta cualquier caza en curso y no vuelve a iniciarla durante
## cubrir+revelar+gracia. Entrar a una sala nunca es una muerte instantánea.
func _preparar_caza(vieja: Node2D, nueva: Node2D) -> void:
	if vieja != null and is_instance_valid(vieja):
		_detener_caza_sala(vieja)
	var reanudar := Time.get_ticks_msec() \
		+ int((duracion_cubrir + retardo_negro + duracion_revelar + gracia_anti_caza) * 1000.0)
	for e in _enemigos_de_sala(nueva):
		if e.has_method("detener_persecucion"):
			e.detener_persecucion()
		if e.has_method("pausar_caza"):
			e.pausar_caza(reanudar)


func _detener_caza_sala(sala: Node) -> void:
	for e in _enemigos_de_sala(sala):
		if e.has_method("detener_persecucion"):
			e.detener_persecucion()


## Enemigos vivos de una sala (por grupo), a cualquier profundidad.
func _enemigos_de_sala(sala: Node) -> Array:
	var out: Array = []
	_cosechar_enemigos(sala, out)
	return out


func _cosechar_enemigos(nodo: Node, out: Array) -> void:
	if nodo.is_in_group(Constantes.GRUPO_ENEMIGOS):
		out.append(nodo)
	for hijo in nodo.get_children():
		_cosechar_enemigos(hijo, out)


## Snap travel direction to 4-way so the wipe reads cleanly.
func _eje_dominante(v: Vector2) -> Vector2:
	if v.length() < 1.0:
		return Vector2.RIGHT
	if absf(v.x) >= absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))
