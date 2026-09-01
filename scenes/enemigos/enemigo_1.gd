extends CharacterBody2D

@export var area_2d : Area2D
@export var min_speed: float = 100.0
@export var max_speed: float = 400.0
@export var animacion: AnimatedSprite2D

var speed: float

@export var activate : Area2D
@export var area_activacion : CollisionShape2D
@export var hitboxDead : CollisionShape2D
@export var collision : CollisionShape2D

# Variables para controlar la persecución
var jugador: Node2D = null
var persiguiendo: bool = false
var esta_muerto: bool = false #Estado de muerte

func _ready() -> void:
	speed = randf_range(min_speed, max_speed)
	print(speed)

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

# Detecta el golpe que mata al enemigo
func _on_area_2d_area_entered(_area: Area2D) -> void:
	if _area.is_in_group("ataque_personaje") and not esta_muerto:
		esta_muerto = true
		persiguiendo = false
		animacion.play("butcher")
		
		# set_deferred le dice a Godot que desactive la colisión de forma segura cuando termine el frame de físicas actual.
		collision.set_deferred("disabled", true)
		hitboxDead.set_deferred("disabled", true)
		area_activacion.set_deferred("disabled", true)

func _on_activate_body_entered(body: Node2D) -> void:
	if body.is_in_group("personajes") and not esta_muerto:
		jugador = body
		animacion.play("detection")
		var timer : Timer = Timer.new()
		add_child(timer)
		timer.start(0.6)
		
		await timer.timeout
		
		# se verifica si el enemigo murió 
		if esta_muerto:
			timer.queue_free() # se borra el timer
			return
			
		persiguiendo = true
		jugador.personaje_muerto.connect(_on_jugador_muerto)
		
		area_activacion.set_deferred("disabled", true)
		timer.queue_free() 

func _on_jugador_muerto() -> void:
	persiguiendo = false
	velocity = Vector2.ZERO
