#LA _ ES LA CONVENCION DE QUE UN PARAMETRO SOLO SE USA EN SI MISMO
extends CharacterBody2D

## Movimiento = dashes discretos interpolados con Tween (no velocidad
## continua): cada click lanza un dash hacia el cursor, recortado al alcance.
## El Tween anima `_dash_prog` 0->1 (easing) y física aplica esa posición
## interpolada con move_and_slide, así las paredes siguen bloqueando.

## 1 tile = 60 px = 2 m (ver readme.txt). Todo el alcance se define en tiles.
const TILE_PX := 60.0

var _muerto : bool = false
var target_position = Vector2.ZERO #destino del dash actual (lo leen tests/gestor)

var max_cargas : int = 3
var cargas_actuales : int = 3
var tiempo_recarga : float = 1.0 # Segundos que tarda en rellenarse un contenedor
var timer_recarga : Timer # Timer que crearemos por código

@export var bloodHud : Control

var dash_lento : bool = false
var dash_rapido : bool = false

## Bloqueo durante la transicion entre salas: ignora clicks y congela
## el movimiento. Solo lo toca el gestor de transicion (no enemigos).
var transicionando : bool = false


##Señal que se va a emitir para la escenaprincipal
signal personaje_muerto #podemos hacer que emita una señal con la palabra signal, seguida del nombre de la señal

#EXPORTACION VARIABLES, PARA IMPORTAR LOS NODOS HIJOS Y PODER MODIFICARLOS DESDE AQUI
@export var animacion : AnimatedSprite2D #para el animated sprite del personaje
@export var area_idle: Area2D #para la hitbox del personaje cuando esta IDLE
@export var area_dash: Area2D #para la hitbox del personaje cuando esta haciendo dash

@export var area_environment : Area2D ##para que colisione con objetos del escenario como los pinchos

@export var emisionidle: CollisionShape2D #para desactivar la hitbox del personaje
@export var emisiondash: CollisionShape2D #para desactivar la hitbox del dash

@export var reticula : Sprite2D #para el sprite de la reticula

@export_group("Dash Alcance (unidades de juego)")
## Dash fuerte (click izq, ataque): 10 tiles = 600 px = 20 m
@export var dash_fuerte_tiles: float = 10.0
## Dash normal (click der, movimiento): 5 tiles = 300 px = 10 m
@export var dash_normal_tiles: float = 5.0

@export_group("Dash Tween")
@export var dash_fuerte_dur: float = 0.30 ## s de un dash fuerte a máxima distancia
@export var dash_normal_dur: float = 0.22 ## s de un dash normal a máxima distancia
@export var dash_min_factor: float = 0.6 ## fracción mínima de duración (dashes cortos)
@export var dash_squash: float = 0.30 ## estiramiento direccional del sprite al salir
@export var dash_recoil: float = 0.30 ## aplastado de aterrizaje
@export var dash_hitstop: float = 0.0 ## congelado total al arrancar (0 = off)
@export var dash_kick: float = 0.0 ## patada de cámara hacia el dash, px (0 = off)

@export_group("Dash Color / Feedback")
@export var color_fuerte: Color = Color(1.0, 0.16, 0.12) ## dash fuerte = ROJO
@export var color_normal: Color = Color(0.25, 0.55, 1.0) ## dash normal = AZUL
@export var vibracion_fuerte: float = 0.6 ## rumble del gamepad en dash fuerte (0 = off)
@export var vibracion_normal: float = 0.25 ## rumble del gamepad en dash normal (0 = off)
@export var sfx_fuerte: AudioStream ## placeholder quien (ver sfx/)
@export var sfx_normal: AudioStream

var _dashing : bool = false
var _dash_fuerte : bool = false
var _dash_from : Vector2 = Vector2.ZERO
var _dash_to : Vector2 = Vector2.ZERO
var _dash_prog : float = 0.0
var _dash_tween : Tween
var _dash_dir : Vector2 = Vector2.ZERO
var _squash_tween : Tween
var _hitstop_active : bool = false
const COLA_MAX := 4
var _cola : Array[Vector2] = [] ## polling de dashes cortos
var dashes_lanzados : int = 0 ## contador (tests/telemetría)
@onready var _dash_particles: GPUParticles2D = get_node_or_null("DashParticles")
@onready var _sfx: AudioStreamPlayer = get_node_or_null("DashSfx")

#FUNCION _ready()
func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(Constantes.GRUPO_PERSONAJES) #el grupo del personaje, se usa para conectarlo a la escena principal
	area_idle.body_entered.connect(_on_area_2d_body_entered_idle)
	target_position = global_position
	timer_recarga = Timer.new()
	timer_recarga.wait_time = tiempo_recarga
	timer_recarga.one_shot = true
	timer_recarga.timeout.connect(_on_timer_recarga_timeout)
	add_child(timer_recarga)


func _process(delta):
	if bloodHud != null:
		var porcentaje = 0.0
		if not timer_recarga.is_stopped():
			porcentaje = (1.0 - (timer_recarga.time_left / tiempo_recarga)) * 100.0
		bloodHud.actualizar_cargas(cargas_actuales, porcentaje)


func _physics_process(delta):
	if _muerto:
		return
	if transicionando:
		velocity = Vector2.ZERO
		return
	if _dashing:
		_aplicar_dash(delta)
	else:
		_reposo()


## Reposo: idle, hitboxes de reposo y retícula. Antes no reponía el idle,
## por eso el sprite se quedaba clavado en la animación de dash.
func _reposo() -> void:
	_on_dash_end()
	emisionidle.set_deferred("disabled", false)
	emisiondash.set_deferred("disabled", true)
	if animacion != null and animacion.animation != &"idle":
		animacion.play("idle")
	_reticula_idle()


## Aplica la posición interpolada por el Tween con colisión. move_and_slide
## DESLIZA a lo largo de las paredes: el dash no se corta al chocar, sigue su
## recorrido pegado al muro y termina al completar la interpolación.
func _aplicar_dash(delta: float) -> void:
	_actualizar_animacion_direccional(_dash_from.direction_to(_dash_to))
	var deseada := _dash_from.lerp(_dash_to, _dash_prog)
	velocity = (deseada - global_position) / maxf(delta, 0.001)
	# Solo el dash fuerte daña (hitbox de dash); el normal es vulnerable.
	emisionidle.set_deferred("disabled", _dash_fuerte)
	emisiondash.set_deferred("disabled", not _dash_fuerte)
	move_and_slide()
	reticula.global_position = _dash_to
	if _dash_prog >= 1.0:
		_fin_dash()


func _reticula_idle() -> void:
	var mouse_offset = get_global_mouse_position() - global_position
	reticula.global_position = global_position + mouse_offset.limit_length(_alcance(true))


# para decidir cual animacion
func _actualizar_animacion_direccional(direction: Vector2) -> void:
	var umbral_vertical : float = 0.5
	if direction.y < -umbral_vertical:
		animacion.play("dash_back")
	elif direction.y > umbral_vertical:
		animacion.play("dash_front")
	else:
		animacion.play("dash")
	if direction.x < 0:
		animacion.flip_h = true
	elif direction.x > 0:
		animacion.flip_h = false

##FUNCION PARA EL MOVIMIENTO DEL MOUSE
func _input(event):
	if transicionando or _muerto:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	# CLICK IZQUIERDO: dash fuerte, hace daño (gasta viales)
	if event.button_index == MOUSE_BUTTON_LEFT:
		_intentar_dash_fuerte()
	# CLICK DERECHO: dash normal, solo movimiento (no gasta viales)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_encolar_dash(get_global_mouse_position())


## Polling de dashes cortos: hasta COLA_MAX en cola, se ejecutan uno tras otro.
func _encolar_dash(punto: Vector2) -> void:
	if _muerto or transicionando:
		return
	if not _dashing and _cola.is_empty():
		dash_hacia(punto, false)
	elif _cola.size() < COLA_MAX:
		_cola.append(punto)


## Lanza el siguiente dash encolado (si lo hay). Idempotente.
func _siguiente_dash() -> void:
	while not _cola.is_empty() and not _dashing and not _muerto and not transicionando:
		var punto: Vector2 = _cola.pop_front()
		dash_hacia(punto, false)


## Alcance de cada dash en px, derivado de las unidades (tiles).
func _alcance(es_fuerte: bool) -> float:
	return (dash_fuerte_tiles if es_fuerte else dash_normal_tiles) * TILE_PX


## API pública: lanza un dash hacia `destino`, recortado al alcance del tipo.
func dash_hacia(destino: Vector2, es_fuerte: bool) -> void:
	if _muerto or transicionando or _dashing:
		return
	var desp := (destino - global_position).limit_length(_alcance(es_fuerte))
	# Clicks casi en el sitio no disparan dash: evita tweens/dashes fantasma.
	if desp.length() < 10.0:
		return
	_dash_from = global_position
	_dash_to = global_position + desp
	target_position = _dash_to
	dash_rapido = es_fuerte
	dash_lento = not es_fuerte
	_lanzar_dash(es_fuerte)


## Dash fuerte: solo se ejecuta si hay cargas, y consume una
func _intentar_dash_fuerte() -> void:
	if cargas_actuales <= 0:
		return
	cargas_actuales -= 1
	if timer_recarga.is_stopped():
		timer_recarga.start()
	dash_hacia(get_global_mouse_position(), true)


## Arranca el Tween que interpola `_dash_prog` 0->1. La duración escala con
## la distancia (dashes cortos no se sienten lentos) con ease-out para salir
## rápido y aterrizar suave.
func _lanzar_dash(es_fuerte: bool) -> void:
	_dashing = true
	_dash_fuerte = es_fuerte
	_dash_prog = 0.0
	dashes_lanzados += 1
	var dist := _dash_from.distance_to(_dash_to)
	var base := dash_fuerte_dur if es_fuerte else dash_normal_dur
	var dur := base * clampf(dist / _alcance(es_fuerte), dash_min_factor, 1.0)
	if _dash_tween != null and _dash_tween.is_valid():
		_dash_tween.kill()
	_dash_tween = create_tween()
	_dash_tween.tween_property(self, "_dash_prog", 1.0, dur) \
		.set_trans(Tween.TRANS_QUINT if es_fuerte else Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	_on_dash_start_snappy()


## Llamado por el gestor de transicion entre salas.
func set_transicionando(v: bool) -> void:
	transicionando = v
	if v:
		# Matar el dash pendiente: sin esto, al liberar la transicion el
		# jugador reanuda hacia el objetivo viejo (detras de la puerta) y
		# rebota entre salas en un ping-pong de transiciones.
		_parar_dash()
		target_position = global_position


## Teletransporte a la zona segura del cuarto nuevo.
func teletransportar(destino: Vector2) -> void:
	_parar_dash()
	global_position = destino
	target_position = destino
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	if animacion != null:
		animacion.scale = Vector2.ONE


## Corta el dash en curso (transición, teletransporte, muerte).
func _parar_dash() -> void:
	if _dash_tween != null and _dash_tween.is_valid():
		_dash_tween.kill()
	_dash_tween = null
	_dashing = false
	dash_rapido = false
	dash_lento = false
	velocity = Vector2.ZERO
	_cola.clear()
	_on_dash_end()


## Fin de dash normal (o por pared): limpia estado y da feedback de llegada.
func _fin_dash() -> void:
	if not _dashing:
		return
	_dashing = false
	dash_rapido = false
	dash_lento = false
	target_position = global_position
	velocity = Vector2.ZERO
	_on_llegada()
	_siguiente_dash()


## Arranque: estiramiento direccional, emisión de partículas del color del
## dash, sonido y vibración. Golpe de cámara/hitstop quedan como tunables.
func _on_dash_start_snappy() -> void:
	_dash_dir = (_dash_to - _dash_from).normalized()
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2.RIGHT
	var col := color_fuerte if _dash_fuerte else color_normal
	# 1. Estiramiento direccional (solo el sprite, nunca el cuerpo).
	if animacion != null and dash_squash > 0.0:
		_kill_squash()
		var st := dash_squash * (1.0 if _dash_fuerte else 0.65)
		if absf(_dash_dir.x) >= absf(_dash_dir.y):
			animacion.scale = Vector2(1.0 + st, 1.0 - st * 0.6)
		else:
			animacion.scale = Vector2(1.0 - st * 0.6, 1.0 + st)
		_squash_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_squash_tween.tween_property(animacion, "scale", Vector2.ONE, 0.25)
	# 2. Polvo/trail hacia atrás, teñido con el color del dash.
	if _dash_particles != null:
		var mat := _dash_particles.process_material as ParticleProcessMaterial
		if mat != null:
			mat.direction = Vector3(-_dash_dir.x, -_dash_dir.y, 0.0)
			mat.color = col
		_dash_particles.restart()
		_dash_particles.emitting = true
	# 3. Sonido del dash (placeholder).
	if _sfx != null:
		var stream := sfx_fuerte if _dash_fuerte else sfx_normal
		if stream != null:
			_sfx.stream = stream
			_sfx.play()
	# 5. Rumble del gamepad (no-op sin mando).
	var vib := vibracion_fuerte if _dash_fuerte else vibracion_normal
	if vib > 0.0:
		Input.start_joy_vibration(0, vib * 0.5, vib, 0.18)
	# 6. Hitstop (opcional).
	if dash_hitstop > 0.0 and not _hitstop_active:
		_hitstop_active = true
		Engine.time_scale = 0.05
		await get_tree().create_timer(dash_hitstop, true, false, true).timeout
		Engine.time_scale = 1.0
		_hitstop_active = false
	# 7. Patada de cámara (opcional).
	if dash_kick > 0.0:
		get_tree().call_group("camara_jugador", "patada_dash", _dash_dir, dash_kick)


## Llegada: asentado con aplastado. Cierra el dash y da ritmo a la navegación.
func _on_llegada() -> void:
	if animacion != null and dash_recoil > 0.0:
		_kill_squash()
		animacion.scale = Vector2(1.0 - dash_recoil * 0.4, 1.0 + dash_recoil * 0.4)
		_squash_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_squash_tween.tween_property(animacion, "scale", Vector2.ONE, 0.18)


func _kill_squash() -> void:
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
		animacion.scale = Vector2.ONE


## End of dash: stop dust, restore sprite. Idempotent (runs every idle frame).
func _on_dash_end() -> void:
	if _dash_particles != null and _dash_particles.emitting:
		_dash_particles.emitting = false


# --- funcion unica para dar una carga, sin importar de donde venga
func _agregar_carga() -> void:
	if cargas_actuales >= max_cargas:
		return
	cargas_actuales += 1
	if cargas_actuales < max_cargas:
		timer_recarga.start()
	else:
		timer_recarga.stop()


## funcion para cuando el timer termina (recarga por tiempo)
func _on_timer_recarga_timeout() -> void:
	_agregar_carga()


## Recarga por matar un enemigo. La llama el enemigo cuando el jugador lo mata de un dash.
func recargar_carga_por_kill() -> void:
	_agregar_carga()


## FUNCION UNICA DE MUERTE
func _morir() -> void:
	if _muerto:
		return
	_muerto = true
	_parar_dash() # corta dash y polvo
	Engine.time_scale = 1.0
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	if animacion != null:
		animacion.scale = Vector2.ONE
	animacion.modulate = Constantes.COLOR_MUERTE
	animacion.stop()
	await get_tree().create_timer(Constantes.TIEMPO_FADE_MUERTE).timeout
	personaje_muerto.emit()


##FUNCION PARA CUANDO MUERE, es decir cuando la hitbox detecta algo que entra
func _on_area_2d_body_entered_idle(_body: Node2D) -> void:
	_morir()

func _on_environment_area_entered(_area: Area2D) -> void:
	_morir()
