extends CharacterBody2D

@export var area_2d : Area2D
@export var min_speed: float = 100.0
@export var max_speed: float = 400.0
@export var animacion: AnimatedSprite2D

var speed: float

@export var activate : Area2D

@export var area_environment : Area2D

@export var area_activacion : CollisionShape2D
@export var hitboxDead : CollisionShape2D
@export var collision : CollisionShape2D

# Variables para controlar la persecución
var jugador: Node2D = null
var persiguiendo: bool = false
var esta_muerto: bool = false #Estado de muerte

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	speed = randf_range(min_speed, max_speed)


func _physics_process(_delta: float) -> void:
	# Si está muerto, detenemos por completo cualquier cálculo de movimiento
	if esta_muerto:
		return

	if persiguiendo and jugador != null:
		animacion.play("idle")
		var direction = global_position.direction_to(jugador.global_position)
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()


func trigger_dim_light() -> void:
	# registra un tween que apaga la luz del enemigo caído.
	# Ya no hace queue_free() al terminar por lo que el cadáver se queda en la habitación en vez de desaparecer.
	var tween = create_tween()
	const dim_duration=1.5
	tween.tween_property($enemy_emission, "energy", 0.0, dim_duration)
	tween.tween_property($enemy_emission, "texture_scale", 0.0, dim_duration)


## FUNCION UNICA DE MUERTE: antes estaba duplicada en
## _on_area_2d_area_entered y _on_environment_area_entered.
## El "if esta_muerto: return" evita procesar la muerte dos veces
## si ambas hitboxes se activan casi al mismo tiempo.
func _morir() -> void:
	if esta_muerto:
		return

	esta_muerto = true
	trigger_dim_light()
	persiguiendo = false
	animacion.play("butcher")

	# set_deferred le dice a Godot que desactive la colisión de forma segura cuando termine el frame de físicas actual.
	collision.set_deferred("disabled", true)
	hitboxDead.set_deferred("disabled", true)
	area_activacion.set_deferred("disabled", true)


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
	if not body.is_in_group(Constantes.GRUPO_PERSONAJES) or esta_muerto:
		return

	jugador = body
	animacion.play("detection")

	await get_tree().create_timer(0.6).timeout

	# se verifica si el enemigo murió mientras esperábamos
	if esta_muerto:
		return

	persiguiendo = true
	jugador.personaje_muerto.connect(_on_jugador_muerto)
	area_activacion.set_deferred("disabled", true)


func _on_jugador_muerto() -> void:
	persiguiendo = false
	velocity = Vector2.ZERO


func _on_environment_area_entered(_area: Area2D) -> void:
	_morir()
