#LA _ ES LA CONVENCION DE QUE UN PARAMETRO SOLO SE USA EN SI MISMO
extends CharacterBody2D

var _velocidad : float = 750.0 #velocidad para el dash
var _velocidad_lenta : float = 400.0 #velocidad para el movimiento lento
var _muerto : bool = false #variable que controla si muere

var target_position = Vector2.ZERO #la posicion de donde se dirige el personaje, se inicia como un vector en 0

var punto_origen : Vector2 = Vector2.ZERO #el punto de origen
var radio_maximo : float = 300.0 #El radio del circulo en el que puedes hacer dash (mas grande)
var radio_minimo : float = 120.0 #El radio del circulo a donde te puedes mover (mas pequeño)


var max_cargas : int = 3
var cargas_actuales : int = 3
var tiempo_recarga : float = 2.0 # Segundos que tarda en rellenarse un contenedor
var timer_recarga : Timer # Timer que crearemos por código

@export var bloodHud : Control

var dash_lento
var dash_rapido


##Señal que se va a emitir para la escenaprincipal
signal personaje_muerto #podemos hacer que emita una señal con la palabra signal, seguida del nombre de la señal
#esta señal la podemos emitir cuando el personaje muera, eso se hace hasta abajo con el nombre de la señal y .
	##para hacer esa conexion de la emision de la señal a la escena principal, SE TIENE QUE METER EN UN GRUPO EL PERSONAJE 

#FUNCIONES PARA LA LOGICA DEL TWEEN (slow in slow out)
var _velocidad_actual : float = 0.0
var tween_dash = Tween

#EXPORTACION VARIABLES, PARA IMPORTAR LOS NODOS HIJOS Y PODER MODIFICARLOS DESDE AQUI
@export var animacion : AnimatedSprite2D #para el animated sprite del personaje
@export var area_idle: Area2D #para la hitbox del personaje cuando esta IDLE, detecta cosas que entran ahi
@export var area_dash: Area2D #para la hitbox del personaje cuando esta haciendo dash, detecta lo que entra ahi

@export var emisionidle: CollisionShape2D #para desactivar la hitbox del personaje
@export var emisiondash: CollisionShape2D #para desactivar la hitbox del dash

@export var reticula : Sprite2D #para el sprite de la reticula

#FUNCION _ready()
##SE EJECUTA UNA SOLA VEZ CADA QUE SE INICIA (sirve para iniciar grupos, hacer concexiones, obtener posicion inicial, e inicializar booleanos)
func _ready():
	add_to_group("personajes") #el grupo del personaje, se usa para conectarlo a la escena principal
	area_idle.body_entered.connect(_on_area_2d_body_entered_idle)
	target_position = global_position
	
	timer_recarga = Timer.new()
	timer_recarga.wait_time = tiempo_recarga
	timer_recarga.one_shot = true
	# Conectamos la señal timeout del timer a nuestra función
	timer_recarga.timeout.connect(_on_timer_recarga_timeout) 
	add_child(timer_recarga)



func _process(_delta):
	if bloodHud != null:
		var porcentaje = 0.0
		# Si el timer está corriendo, calculamos el porcentaje de 0 a 100
		if not timer_recarga.is_stopped():
			porcentaje = (1.0 - (timer_recarga.time_left / tiempo_recarga)) * 100.0
		
		# Le enviamos los datos a la escena de UI
		bloodHud.actualizar_cargas(cargas_actuales, porcentaje)


func _physics_process(_delta):
	if _muerto == true:
		return
	
	var distance = global_position.distance_to(target_position)
	
	if distance > 10.0:
		var direction = global_position.direction_to(target_position)
		
		# --- Elegimos la animación según la dirección dominante del dash ---
		_actualizar_animacion_direccional(direction)
		
		if dash_rapido == true and dash_lento == false:
			velocity = direction * _velocidad
			emisionidle.set_deferred("disabled", true)
			emisiondash.set_deferred("disabled", false)
		elif dash_rapido == false and dash_lento == true:
			velocity = direction * _velocidad_lenta
			emisionidle.set_deferred("disabled", false)
			emisiondash.set_deferred("disabled", true)
		
		move_and_slide()
		reticula.global_position = target_position
	else:
		velocity = Vector2.ZERO
		animacion.play("idle")
		emisionidle.set_deferred("disabled", false)
		emisiondash.set_deferred("disabled", true)
		
		var mouse_offset = get_global_mouse_position() - global_position
		reticula.global_position = global_position + mouse_offset.limit_length(radio_maximo)


# para decidir cual animacion
func _actualizar_animacion_direccional(direction: Vector2) -> void:
	# Umbral para decidir si el movimiento es "mas vertical" que "horizontal"
	# entre mas cerca de 1.0, mas estricto es para entrar en front/back
	var umbral_vertical : float = 0.5
	
	if direction.y < -umbral_vertical:
		# Se mueve principalmente hacia arriba -> se aleja de la cámara
		animacion.play("dash_back")
	elif direction.y > umbral_vertical:
		# Se mueve principalmente hacia abajo -> se acerca a la cámara
		animacion.play("dash_front")
	else:
		# Movimiento principalmente horizontal
		animacion.play("dash")
	
	# El flip horizontal se mantiene independiente de qué animación se use,
	# asi el personaje sigue viendo hacia donde se mueve en horizontal
	if direction.x < 0:
		animacion.flip_h = true
	elif direction.x > 0:
		animacion.flip_h = false

##FUNCION PARA EL MOVIMIENTO DEL MOUSE
func _input(event):
	# CLICK IZQUIERDO: Hace daño (Requiere y gasta viales)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if cargas_actuales > 0: # Solo atacamos si hay cargas
			cargas_actuales -= 1 # Gastamos una carga
			
			# Iniciamos el Timer de recarga si no estaba corriendo ya
			if timer_recarga.is_stopped():
				
				timer_recarga.start()
			
			var vector_desplazamiento = get_global_mouse_position() - global_position
			vector_desplazamiento = vector_desplazamiento.limit_length(radio_maximo)
			target_position = global_position + vector_desplazamiento
			dash_rapido = true
			dash_lento = false
		else:
			# aqui hay que poner un sonido o efecto visual de que no puedes atacar
			pass
	# CLICK DERECHO: Movimiento normal (No gasta viales)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var vector_desplazamiento = get_global_mouse_position() - global_position
		vector_desplazamiento = vector_desplazamiento.limit_length(radio_minimo)
		target_position = global_position + vector_desplazamiento
		dash_rapido = false
		dash_lento = true


# --- funcion para cuando el timer termina
func _on_timer_recarga_timeout():
	if cargas_actuales < max_cargas:
		cargas_actuales += 1 # Recuperamos un vial
		
		# Si todavía nos faltan viales por recuperar, reiniciamos el Timer
		if cargas_actuales < max_cargas:
			timer_recarga.start()


##FUNCION PARA CUANDO MUERE, es decir cuando la hitbox detecta algo que entra
func _on_area_2d_body_entered_idle(_body: Node2D) -> void:
	animacion.modulate = Color(18.892, 0.0, 0.0, 1.0)
	_muerto = true
	animacion.stop()
	
	var timer : Timer = Timer.new() #variable timer de tipo Timer que le asignamos un contador con Timer.new()
	#esto para que la emision de la señal NO SEA INMEDIATA, y podamos ver el color rojo
	add_child(timer)
	timer.start(0.5)
	await timer.timeout #se espera hasta que el tiempo se acabe, se usa el .timeout para cuando el tiempo se acabe, y await para que espere
	
	##LINEA QUE HACE LO DEL TIMER EN UNA LINEA, ES MUY UTIL###
	# await get.tree().create_timer(0.5).timeout #
	## con esa linea estamos directamente creando un timer, y esperar a que el tiempo termine##
	
	#LA FUNCION .EMIT() ES PARA SEÑALES
	personaje_muerto.emit() #el personaje muerto EMITE una SEÑAL
	##hay que conseguir que la escenaprincipal tenga una referencia al personaje PARA PODER CONECTARSE A ESTA SEÑAL EMITIDA
