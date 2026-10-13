extends CharacterBody2D

## Se emite UNA vez cuando el enemigo muere. Lo usa el controlador de sala
## (Sala) para abrir las puertas cuando no quedan enemigos vivos.
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

var speed: float

## Variables para controlar la persecución
var jugador: Node2D = null
var persiguiendo: bool = false
var esta_muerto: bool = false #Estado de muerte
@onready var _muerte_particles := get_node_or_null("MuerteParticles")

var _jugador_en_area: bool = false
var _tiempo_sin_ver: float = 0.0
var _ultimo_visto := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(Constantes.GRUPO_ENEMIGOS)
	speed = randf_range(min_speed, max_speed)
	animacion.play("idle")

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
		# Si siguió en el área pero falló la detección inicial (pared), la
		# re-intenta en cuanto gana la línea de vista.
		if _jugador_en_area and is_instance_valid(jugador) and Vision.ve_a(self, jugador):
			_iniciar_persecucion()

	move_and_slide()


func _iniciar_persecucion() -> void:
	if persiguiendo or esta_muerto or not is_instance_valid(jugador):
		return
	if not Vision.ve_a(self, jugador):
		return
	persiguiendo = true
	_ultimo_visto = jugador.global_position
	_tiempo_sin_ver = 0.0
	if not jugador.personaje_muerto.is_connected(_on_jugador_muerto):
		jugador.personaje_muerto.connect(_on_jugador_muerto)
	area_activacion.set_deferred("disabled", true)


func _perder_jugador() -> void:
	persiguiendo = false
	velocity = Vector2.ZERO
	animacion.play("idle")
	_tiempo_sin_ver = 0.0
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
	if not body.is_in_group(Constantes.GRUPO_PERSONAJES) or esta_muerto or persiguiendo:
		return
	jugador = body
	_jugador_en_area = true
	animacion.play("detection")
	await get_tree().create_timer(0.6).timeout
	# se verifica si el enemigo murió mientras esperábamos
	if esta_muerto:
		return
	animacion.play("idle") # animación que se reproduce cuando está persiguiendo
	# Solo persigue si hay línea de vista: una pared delante en el momento
	# de entrar no dispara la caza (el re-intento lo hace _physics_process).
	_iniciar_persecucion()


func _on_activate_body_exited(body: Node2D) -> void:
	if body != jugador:
		return
	_jugador_en_area = false
	# La decisión real de abandonar (con gracia) la toma _physics_process.


func _on_jugador_muerto() -> void:
	persiguiendo = false
	velocity = Vector2.ZERO
	animacion.play("idle") #se puede poner animacion para cuando el jugador muera


func _on_environment_area_entered(_area: Area2D) -> void:
	_morir()
