extends CharacterBody2D

@export var area_2d : Area2D
@export var min_speed: float = 100.0
@export var max_speed: float = 400.0

var speed: float

@export var activate : Area2D
@export var area_activacion : CollisionShape2D

# Variables para controlar la persecución
var jugador: Node2D = null
var persiguiendo: bool = false

func _ready() -> void:
	speed = randf_range(min_speed, max_speed) #para que se inicialicen con velocidad diferente
	print (speed)
	pass

func _physics_process(_delta: float) -> void:
	# Solo se mueve si esta en modo persecución y esta el jugador localizado
	if persiguiendo and jugador != null:
		# direction_to() calcula automáticamente un vector normalizado hacia el objetivo
		var direction = global_position.direction_to(jugador.global_position)
		velocity = direction * speed
	else:
		# Si no está persiguiendo a nadie, se queda quieto
		velocity = Vector2.ZERO 
		
	move_and_slide()

#Funcion para detectar la hitbox de ataque del personaje, detecta el area2d del ataque
func _on_area_2d_area_entered(_area: Area2D) -> void:
	if _area.is_in_group("ataque_personaje"):
		queue_free() 


func _on_activate_body_entered(body: Node2D) -> void:
	if body.is_in_group("personajes"):
		# Guardamos la referencia del personaje que acaba de entrar al área
		jugador = body
		persiguiendo = true
		jugador.personaje_muerto.connect(_on_jugador_muerto)
		
		area_activacion.set_deferred("disabled", true)
		


# Esta es la función que se ejecutará en el enemigo cuando el jugador muera
func _on_jugador_muerto() -> void:
	# Detenemos la persecución
	persiguiendo = false
	velocity = Vector2.ZERO
