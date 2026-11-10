extends CharacterBody2D

## Se emite UNA vez cuando el enemigo muere. En el tutorial, el guardia
## de la lección de dash fuerte lo usa para soltar su llave.
signal murio

@export var area_2d : Area2D
@export var min_speed: float = 100.0
@export var max_speed: float = 400.0
@export var animacion: AnimatedSprite2D
@export var activate : Area2D
@export var area_environment : Area2D
@export var area_activacion : CollisionShape2D
@export var hitboxDead : CollisionShape2D
@export var collision : CollisionShape2D
## Segundos sin ver al jugador (fuera del área y sin línea de vista) para
## abandonar la persecución. Evita el "parpadeo" al cruzar una puerta.
@export var tiempo_perder_vista: float = 1.5

@export_group("Patrulla")
## RayCast2D hacia arriba / abajo. Solo UNO está activo a la vez: el del
## sentido en que camina. Al chocar con una pared se apaga y se enciende el otro.
@export var ray_arriba: RayCast2D
@export var ray_abajo: RayCast2D
@export var velocidad_patrulla: float = 80.0
## Distancia extra (px) más allá del borde del cuerpo a la que el rayo detecta la pared.
@export var margen_pared: float = 30.0
## Nombres de las animaciones de caminata en sprite_frames_enemigo1.tres.
## Si todavía no existen, se queda en "idle" sin dar error.
@export var anim_caminar_arriba: StringName = &"walk_up"
@export var anim_caminar_abajo: StringName = &"walk_down"
@export_group("")

var speed: float

## Variables para controlar la persecución
var jugador: Node2D = null
var persiguiendo: bool = false
var esta_muerto: bool = false #Estado de muerte
@onready var _muerte_particles := get_node_or_null("MuerteParticles")

var _jugador_en_area: bool = false
var _tiempo_sin_ver: float = 0.0
var _ultimo_visto := Vector2.ZERO
var _caza_bloqueada_hasta := -1 ## gracia anti-caza: no inicia la caza hasta (ms)

## Patrulla: se sortea UNA vez por instancia (0 = quieto, 1 = patrulla).
var patrulla_activa: bool = false
var _dir_patrulla: int = 1 ## -1 = arriba, 1 = abajo
var _detectando: bool = false ## true mientras suena la animación "detection"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(Constantes.GRUPO_ENEMIGOS)
	speed = randf_range(min_speed, max_speed)
	patrulla_activa = bool(randi_range(0, 1))
	_dir_patrulla = -1 if randi_range(0, 1) == 0 else 1
	_configurar_rayos()
	_reanudar_patrulla()

func _physics_process(delta: float) -> void:
	# Si está muerto, detenemos por completo cualquier cálculo de movimiento
	if esta_muerto:
		return

	var viendo := false
	if persiguiendo and jugador != null and is_instance_valid(jugador):
		viendo = Vision.ve_a(self, jugador)
		# Persigue el último punto donde vio al jugador; si hay línea de
		# vista lo refresca cada frame, si no acumula tiempo para rendirse.
		if viendo:
			_ultimo_visto = jugador.global_position
			_tiempo_sin_ver = 0.0
		else:
			_tiempo_sin_ver += delta
			if _tiempo_sin_ver >= tiempo_perder_vista and not _jugador_en_area:
				_perder_jugador()
		if persiguiendo:
			velocity = global_position.direction_to(_ultimo_visto) * speed
	else:
		velocity = Vector2.ZERO
		if patrulla_activa and not _detectando:
			_patrullar()
		# Si siguió en el área pero falló la detección inicial (pared), la
		# re-intenta en cuanto gana la línea de vista.
		if not _detectando and not _caza_pausada() and _jugador_en_area and is_instance_valid(jugador) and Vision.ve_a(self, jugador):
			_iniciar_persecucion()

	move_and_slide()


# ---------------------------------------------------------------- Patrulla

## Coloca y dimensiona los rayos según la colisión del cuerpo, así siguen
## bien aunque cambies el tamaño de la CollisionShape2D. Empiezan apagados.
func _configurar_rayos() -> void:
	var mitad_alto := 250.0
	if collision.shape is RectangleShape2D:
		mitad_alto = (collision.shape as RectangleShape2D).size.y * 0.5 * absf(collision.scale.y)
	var largo := mitad_alto + margen_pared
	ray_arriba.position = collision.position
	ray_abajo.position = collision.position
	ray_arriba.target_position = Vector2(0.0, -largo)
	ray_abajo.target_position = Vector2(0.0, largo)
	_desactivar_rayos()


func _desactivar_rayos() -> void:
	ray_arriba.enabled = false
	ray_abajo.enabled = false


## Enciende SOLO el rayo del sentido actual.
func _activar_rayo_actual() -> void:
	ray_arriba.enabled = _dir_patrulla < 0
	ray_abajo.enabled = _dir_patrulla > 0


func _rayo_actual() -> RayCast2D:
	return ray_arriba if _dir_patrulla < 0 else ray_abajo


## Camina en el sentido actual hasta que su rayo toque una pared; entonces
## apaga ese rayo, enciende el opuesto y cambia de dirección.
func _patrullar() -> void:
	var rayo := _rayo_actual()
	rayo.force_raycast_update()
	if rayo.is_colliding():
		_dir_patrulla *= -1
		_activar_rayo_actual()
		rayo = _rayo_actual()
		rayo.force_raycast_update()
		# Pared a ambos lados (pasillo sin espacio): se queda quieto.
		if rayo.is_colliding():
			velocity = Vector2.ZERO
			_animar_patrulla()
			return
	velocity = Vector2(0.0, _dir_patrulla * velocidad_patrulla)
	_animar_patrulla()


func _animar_patrulla() -> void:
	if velocity.y < 0.0:
		_reproducir(anim_caminar_arriba)
	elif velocity.y > 0.0:
		_reproducir(anim_caminar_abajo)
	else:
		_reproducir(&"idle")


## Reproduce `nombre` si existe en el SpriteFrames; si no, cae a "idle".
func _reproducir(nombre: StringName) -> void:
	if not animacion.sprite_frames.has_animation(nombre):
		nombre = &"idle"
	if animacion.animation != nombre or not animacion.is_playing():
		animacion.play(nombre)


## Vuelve al reposo: patrulla si le tocó patrullar, idle si le tocó estar quieto.
func _reanudar_patrulla() -> void:
	if esta_muerto or persiguiendo:
		return
	if patrulla_activa:
		_activar_rayo_actual()
	else:
		_desactivar_rayos()
		animacion.play("idle")


## true mientras dura la gracia anti-caza (transición de sala): el enemigo
## ve al jugador pero NO inicia ni retoma la caza hasta que expire.
func _caza_pausada() -> bool:
	return Time.get_ticks_msec() < _caza_bloqueada_hasta


## Pausa el inicio/retome de la caza hasta `reanudar_en_ticks` (ms absoluto).
func pausar_caza(reanudar_en_ticks: int) -> void:
	_caza_bloqueada_hasta = reanudar_en_ticks


## Vuelve al estado de reposo (patrulla/idle): se llama al abandonar la sala
## para que al re-entrar nadie siga persiguiendo al jugador.
func detener_persecucion() -> void:
	_detectando = false
	if persiguiendo:
		persiguiendo = false
		velocity = Vector2.ZERO
		_tiempo_sin_ver = 0.0
		_ultimo_visto = Vector2.ZERO
		area_activacion.set_deferred("disabled", false)
	if jugador != null and is_instance_valid(jugador) \
			and jugador.personaje_muerto.is_connected(_on_jugador_muerto):
		jugador.personaje_muerto.disconnect(_on_jugador_muerto)
	jugador = null
	_jugador_en_area = false
	_reanudar_patrulla()


func _iniciar_persecucion() -> void:
	if _caza_pausada() or persiguiendo or esta_muerto or not is_instance_valid(jugador):
		return
	if not Vision.ve_a(self, jugador):
		return
	persiguiendo = true
	_detectando = false
	_desactivar_rayos()
	_ultimo_visto = jugador.global_position
	_tiempo_sin_ver = 0.0
	if not jugador.personaje_muerto.is_connected(_on_jugador_muerto):
		jugador.personaje_muerto.connect(_on_jugador_muerto)
	area_activacion.set_deferred("disabled", true)


func _perder_jugador() -> void:
	persiguiendo = false
	velocity = Vector2.ZERO
	_tiempo_sin_ver = 0.0
	_reanudar_patrulla()
	# Re-activar la detección por si el jugador vuelve a entrar.
	area_activacion.set_deferred("disabled", false)
	if jugador != null and is_instance_valid(jugador) \
			and jugador.personaje_muerto.is_connected(_on_jugador_muerto):
		jugador.personaje_muerto.disconnect(_on_jugador_muerto)


func _emitir_muerte() -> void:
	# Partículas de muerte (sangre). Ya no hace queue_free() al terminar:
	# el cadáver se queda en la sala.
	if _muerte_particles != null:
		_muerte_particles.restart()
		_muerte_particles.emitting = true


## FUNCION UNICA DE MUERTE: antes estaba duplicada en
## _on_area_2d_area_entered y _on_environment_area_entered.
## El "if esta_muerto: return" evita procesar la muerte dos veces
## si ambas hitboxes se activan casi al mismo tiempo.
func _morir() -> void:
	if esta_muerto:
		return

	esta_muerto = true
	_desactivar_rayos()
	_emitir_muerte()
	persiguiendo = false
	animacion.play("butcher")

	# set_deferred le dice a Godot que desactive la colisión de forma segura cuando termine el frame de físicas actual.
	collision.set_deferred("disabled", true)
	hitboxDead.set_deferred("disabled", true)
	area_activacion.set_deferred("disabled", true)

	murio.emit()


# Detecta el golpe que mata al enemigo
func _on_area_2d_area_entered(_area: Area2D) -> void:
	if not _area.is_in_group(Constantes.GRUPO_ATAQUE_PERSONAJE) or esta_muerto:
		return

	_morir()

	# Recargar viales.
	# Se busca por grupo (no se usa la variable "jugador") porque el
	# enemigo puede morir de un dash sin haber activado nunca la
	# persecución, y en ese caso "jugador" seguiría siendo null.
	var jugador_actual := get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	if jugador_actual:
		jugador_actual.recargar_carga_por_kill()


func _on_activate_body_entered(body: Node2D) -> void:
	if not body.is_in_group(Constantes.GRUPO_PERSONAJES) or esta_muerto or persiguiendo or _detectando:
		return
	jugador = body
	_jugador_en_area = true
	# Detecta al jugador: ambos rayos se apagan y se frena mientras "detection".
	_detectando = true
	_desactivar_rayos()
	velocity = Vector2.ZERO
	animacion.play("detection")
	await get_tree().create_timer(0.6).timeout
	# se verifica si el enemigo murió (o se reseteó) mientras esperábamos
	if esta_muerto or not _detectando:
		return
	_detectando = false
	animacion.play("idle") # animación que se reproduce cuando está persiguiendo
	# Solo persigue si hay línea de vista: una pared delante en el momento
	# de entrar no dispara la caza (el re-intento lo hace _physics_process).
	_iniciar_persecucion()
	# Sin línea de vista no hubo caza: vuelve a lo que estaba haciendo.
	if not persiguiendo:
		_reanudar_patrulla()


func _on_activate_body_exited(body: Node2D) -> void:
	if body != jugador:
		return
	_jugador_en_area = false
	# La decisión real de abandonar (con gracia) la toma _physics_process.


func _on_jugador_muerto() -> void:
	persiguiendo = false
	velocity = Vector2.ZERO
	_reanudar_patrulla() # se puede poner animacion para cuando el jugador muera


func _on_environment_area_entered(_area: Area2D) -> void:
	_morir()
