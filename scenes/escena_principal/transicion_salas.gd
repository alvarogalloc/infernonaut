extends Node
## Room transition manager: directional dark wipe, teleport to a safe
## spot in the next room, wipe back. Sweet and explicit — no physics
## corridors, no enemy-activation coupling (that logic is untouched).
##
## FLOW: camera detects the neighbor -> signal -> cover (dark sweeps toward
## travel side) -> player teleports inside the new room's safe frame ->
## camera snaps instantly (hidden in black) -> reveal.
##
## TUNABLES: duracion_cubrir / duracion_revelar (speed), tipo_transicion
## + ease_transicion (tween feel), margen_seguro (spawn inset from walls),
## retardo_negro (hold at full black).

@export_group("Velocidad")
@export var duracion_cubrir: float = 0.35 ## seconds: dark sweep in
@export var duracion_revelar: float = 0.45 ## seconds: dark sweep out
@export var retardo_negro: float = 0.05 ## hold at full cover before teleport
@export_group("Tween")
@export var tipo_transicion: Tween.TransitionType = Tween.TRANS_CUBIC
@export var ease_transicion: Tween.EaseType = Tween.EASE_IN_OUT
@export_group("Destino")
@export var margen_seguro: float = 180.0 ## spawn inset from room walls
@export var activa: bool = true ## false = camera falls back to slide

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
	# Freeze player input/movement; enemy activation areas untouched.
	if _jugador.has_method("set_transicionando"):
		_jugador.set_transicionando(true)
	var vieja_centro: Vector2 = _camara.sala_centro(_camara.sala_actual())
	var nueva_centro: Vector2 = _camara.sala_centro(nueva)
	_material().set_shader_parameter("direccion", _eje_dominante(nueva_centro - vieja_centro))
	# 1. Cover: darkness chases the travel direction.
	await _barrer(0.0, 1.0, duracion_cubrir)
	if retardo_negro > 0.0:
		await get_tree().create_timer(retardo_negro, true, false, true).timeout
	# 2. Teleport into the safe frame (hidden in black), snap camera.
	if is_instance_valid(_jugador) and _jugador.has_method("teletransportar"):
		_jugador.teletransportar(_punto_seguro(nueva))
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


## Safe spawn: player position clamped into the new room shrunk by the
## safe margin. Crossing a door lands right inside it; jumping across
## the map lands on the nearest safe edge. Falls back to center.
## Anti-ping-pong: if the landing is still inside another room's detection
## frame (rooms whose floors overlap near the door), walk it toward the
## new room's center until it is clear. Otherwise the camera re-detects
## the room just left and the wipe loops forever.
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


## Snap travel direction to 4-way so the wipe reads cleanly.
func _eje_dominante(v: Vector2) -> Vector2:
	if v.length() < 1.0:
		return Vector2.RIGHT
	if absf(v.x) >= absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))
