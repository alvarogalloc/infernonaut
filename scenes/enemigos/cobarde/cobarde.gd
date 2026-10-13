extends CharacterBody2D

## Cobarde: huye del jugador y, cada `intervalo_ataque` segundos, se detiene,
## marca en el suelo 3 zonas "detrás de él" (hacia el jugador) y lanza 3
## proyectiles arqueados que caen en esas zonas e infligen daño de área.
## Los telégrafos se ven desde el viento hasta aterrizar: el dodge es posicional.

signal murio ## Se emite una vez al morir (Sala abre las puertas).

enum Estado { INACTIVO, REACCIONANDO, HUYENDO, PREPARANDO, ATACANDO, MUERTO }

@export_group("Huida")
@export var velocidad_huida: float = 380.0
@export var tiempo_deteccion: float = 0.6
## Segundos sin ver al jugador (ni área) para volver a INACTIVO.
@export var tiempo_perder_vista: float = 1.5

@export_group("Ataque")
@export var intervalo_ataque: float = 2.2 ## Segundos huyendo antes de atacar
@export var tiempo_preparacion: float = 0.6 ## Telégrafos visibles antes de disparar
@export var tiempo_vuelo: float = 0.9 ## Lo que tarda un proyectil en caer
@export var altura_tiro: float = 240.0
@export var radio_dano: float = 90.0 ## Radio de la zona que daña al aterrizar
@export var separacion_objetivos: float = 110.0
@export var distancia_base: float = 240.0 ## Distancia al primer objetivo

@export_group("Nodos")
@export var collision: CollisionShape2D
@export var hitboxDead: CollisionShape2D
@export var area_activacion: CollisionShape2D
@export var boca: Marker2D ## Punto de lanzamiento de los proyectiles

const RUTA_PROYECTIL := "res://scenes/enemigos/cobarde/proyectil_cobarde.gd"
const RUTA_TELEGRAFO := "res://scenes/enemigos/cobarde/telegrafo.gd"

var jugador: Node2D = null
var esta_muerto := false ## API común con enemigo_1.gd (Sala.configurar)
var _estado: Estado = Estado.INACTIVO
var _tiempo_estado: float = 0.0
var _jugador_en_area: bool = false
var _tiempo_sin_ver: float = 0.0
var _ultimo_visto := Vector2.ZERO
var _normal_pared: Vector2 = Vector2.ZERO
var _objetivos: Array = [] ## Puntos de impacto (globales) del ataque en curso
var _telegrafos: Array = []
var _proyectiles: Array = []
var _caza_bloqueada_hasta := -1 ## gracia anti-caza: no reacciona hasta (ms)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(Constantes.GRUPO_ENEMIGOS)


func _physics_process(delta: float) -> void:
	if _estado == Estado.MUERTO:
		return
	if _estado != Estado.INACTIVO and not is_instance_valid(jugador):
		_cambiar_estado(Estado.INACTIVO)
		return
	_tiempo_estado += delta
	match _estado:
		Estado.INACTIVO:
			# Solo reacciona si además lo ve: una pared delante no dispara
			# la detección, aunque el jugador esté dentro del área.
			if not _caza_pausada() and _jugador_en_area and Vision.ve_a(self, jugador):
				_cambiar_estado(Estado.REACCIONANDO)
		Estado.REACCIONANDO:
			_actualizar_vista(delta)
			if _tiempo_sin_ver >= tiempo_perder_vista:
				_cambiar_estado(Estado.INACTIVO)
			elif _tiempo_estado >= tiempo_deteccion:
				_cambiar_estado(Estado.HUYENDO)
		Estado.HUYENDO:
			_actualizar_vista(delta)
			_huir()
			if _tiempo_sin_ver >= tiempo_perder_vista:
				_cambiar_estado(Estado.INACTIVO)
			elif _tiempo_estado >= intervalo_ataque:
				_cambiar_estado(Estado.PREPARANDO)
		Estado.PREPARANDO:
			if _tiempo_estado >= tiempo_preparacion:
				_cambiar_estado(Estado.ATACANDO)


func _cambiar_estado(nuevo: Estado) -> void:
	if _estado == Estado.MUERTO:
		return
	_estado = nuevo
	_tiempo_estado = 0.0
	_tiempo_sin_ver = 0.0
	if nuevo != Estado.PREPARANDO and nuevo != Estado.ATACANDO:
		_limpiar_marcadores()
	match nuevo:
		Estado.INACTIVO:
			velocity = Vector2.ZERO
		Estado.REACCIONANDO:
			velocity = Vector2.ZERO
		Estado.HUYENDO:
			pass
		Estado.PREPARANDO:
			velocity = Vector2.ZERO
			_marcar_objetivos()
		Estado.ATACANDO:
			velocity = Vector2.ZERO
			_lanzar_ataque()
		Estado.MUERTO:
			velocity = Vector2.ZERO
			_limpiar_marcadores()


# ---------------------------------------------------------------- HUIDA

## Actualiza memoria de vista. Devuelve true si el jugador es visible.
func _actualizar_vista(delta: float) -> void:
	if is_instance_valid(jugador) and Vision.ve_a(self, jugador):
		_ultimo_visto = jugador.global_position
		_tiempo_sin_ver = 0.0
	else:
		_tiempo_sin_ver += delta


func _huir() -> void:
	var origen := _ultimo_visto if _tiempo_sin_ver > 0.0 else jugador.global_position
	var dir := origen.direction_to(global_position)
	if dir.is_zero_approx():
		dir = Vector2.from_angle(randf() * TAU)
	if _normal_pared != Vector2.ZERO and dir.dot(_normal_pared) < 0.0:
		var tangente := _normal_pared.orthogonal()
		if tangente.dot(dir) < 0.0:
			tangente = -tangente
		dir = tangente
	velocity = dir * velocidad_huida
	move_and_slide()
	_normal_pared = get_slide_collision(0).get_normal() if get_slide_collision_count() > 0 else Vector2.ZERO


# --------------------------------------------------------------- ATAQUE

## 3 objetivos en abanico "detrás de él" (hacia el jugador): en la dirección
## contraria a su huida, escalonados en distancia y desplazados en perpendicular.
func _marcar_objetivos() -> void:
	_objetivos.clear()
	var dir := jugador.global_position.direction_to(global_position)
	if dir.is_zero_approx():
		dir = Vector2.from_angle(randf() * TAU)
	var perp := dir.orthogonal()
	for i in 3:
		var lateral := (-1.0 + i) * separacion_objetivos
		var t := global_position + dir * (distancia_base + i * separacion_objetivos) + perp * lateral
		_objetivos.append(t)
		var tel: Node2D = _instanciar_script(RUTA_TELEGRAFO)
		tel.set("radio", radio_dano)
		# El telégrafo vive en la sala, NO como hijo del cobarde: así no hereda
		# su escala (0.175) ni su transform. Se coloca por global_position
		# DESPUÉS de entrar al árbol (antes duplicaba el offset del padre).
		get_parent().add_child(tel)
		tel.global_position = t
		_telegrafos.append(tel)


func _lanzar_ataque() -> void:
	for t in _objetivos:
		var pro: Node2D = _instanciar_script(RUTA_PROYECTIL)
		pro.radio_dano = radio_dano
		pro.configurar(boca.global_position, t, tiempo_vuelo, altura_tiro)
		pro.aterrizo.connect(_limpiar_marcadores)
		get_tree().root.add_child(pro)
		_proyectiles.append(pro)


## Los scripts son sencillos (Node2D puro) y no tienen .tscn.
static func _instanciar_script(ruta: String) -> Node2D:
	var n := Node2D.new()
	n.set_script(load(ruta))
	return n


func _limpiar_marcadores() -> void:
	for tel in _telegrafos:
		if is_instance_valid(tel):
			tel.queue_free()
	_telegrafos.clear()
	for p in _proyectiles:
		if is_instance_valid(p) and p.aterrizo.is_connected(_limpiar_marcadores):
			p.aterrizo.disconnect(_limpiar_marcadores)
	_proyectiles.clear()


# ---------------------------------------------------------------- MUERTE

func _morir() -> void:
	if _estado == Estado.MUERTO:
		return
	_cambiar_estado(Estado.MUERTO)
	esta_muerto = true
	collision.set_deferred("disabled", true)
	hitboxDead.set_deferred("disabled", true)
	area_activacion.set_deferred("disabled", true)
	murio.emit()


func _on_area_2d_area_entered(_area: Area2D) -> void:
	if not _area.is_in_group(Constantes.GRUPO_ATAQUE_PERSONAJE) or _estado == Estado.MUERTO:
		return
	_morir()
	var jugador_actual := get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	if jugador_actual:
		jugador_actual.recargar_carga_por_kill()


func _on_environment_area_entered(_area: Area2D) -> void:
	_morir()


# ------------------------------------------------------ AREA DE ACTIVACION

## true mientras dura la gracia anti-caza (transición de sala): registra al
## jugador pero NO reacciona hasta que expire.
func _caza_pausada() -> bool:
	return Time.get_ticks_msec() < _caza_bloqueada_hasta


## Pausa la reacción de caza hasta `reanudar_en_ticks` (ms absoluto).
func pausar_caza(reanudar_en_ticks: int) -> void:
	_caza_bloqueada_hasta = reanudar_en_ticks


## Vuelve, limpio, al estado INACTIVO (suelta al jugador y sus marcadores).
func detener_persecucion() -> void:
	if _estado != Estado.MUERTO:
		_cambiar_estado(Estado.INACTIVO)
	if jugador != null and is_instance_valid(jugador) \
			and jugador.personaje_muerto.is_connected(_on_jugador_muerto):
		jugador.personaje_muerto.disconnect(_on_jugador_muerto)
	jugador = null
	_jugador_en_area = false


func _on_activate_body_entered(body: Node2D) -> void:
	if _estado == Estado.MUERTO or not body.is_in_group(Constantes.GRUPO_PERSONAJES):
		return
	jugador = body
	_jugador_en_area = true
	if not jugador.personaje_muerto.is_connected(_on_jugador_muerto):
		jugador.personaje_muerto.connect(_on_jugador_muerto)
	# El paso a REACCIONANDO lo decide _physics_process según la línea de
	# vista: entrar al área con una pared delante no dispara la detección.


func _on_activate_body_exited(body: Node2D) -> void:
	if body != jugador:
		return
	_jugador_en_area = false
	if _estado == Estado.REACCIONANDO or _estado == Estado.HUYENDO:
		_cambiar_estado(Estado.INACTIVO)


func _on_jugador_muerto() -> void:
	_jugador_en_area = false
	_cambiar_estado(Estado.INACTIVO)