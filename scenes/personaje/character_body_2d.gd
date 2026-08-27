#LA _ ES LA CONVENCION DE QUE UN PARAMETRO SOLO SE USA EN SI MISMO

extends CharacterBody2D
var _velocidad : float = 1000.0 #velocidad para el dash
var _velocidad_lenta : float = 500.0 #velocidad para el movimiento lento
var _muerto : bool = false #variable que controla si muere

var target_position = Vector2.ZERO #la posicion de donde se dirige el personaje, se inicia como un vector en 0

var punto_origen : Vector2 = Vector2.ZERO #el punto de origen
var radio_maximo : float = 300.0 #El radio del circulo en el que puedes hacer dash (mas grande)
var radio_minimo : float = 120.0 #El radio del circulo a donde te puedes mover (mas pequeño)



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
##TAL VEZ FALTA UNA HITBOX PARA CUANDO HACE EL DASH CORTO

@export var emisionidle: CollisionShape2D #para desactivar la hitbox del personaje
@export var emisiondash: CollisionShape2D #para desactivar la hitbox del dash

@export var reticula : Sprite2D #para el sprite de la reticula

#FUNCION _ready()
##SE EJECUTA UNA SOLA VEZ CADA QUE SE INICIA (sirve para iniciar grupos, hacer concexiones, obtener posicion inicial, e inicializar booleanos)
func _ready():
	add_to_group("personajes") #el grupo del personaje, se usa para conectarlo a la escena principal
	area_idle.body_entered.connect(_on_area_2d_body_entered_idle)
	target_position = global_position


#FUNCION _physics_process(_delta) 
## ES LA QUE SE EJECUTA CADA FRAME, SIRVE PARA HACER COMPROBACIONES CONSTANTES, MOVIMIENTO DEL PERSONAJE. ETC
func _physics_process(_delta):
	if _muerto == true:
		return
	
	var distance = global_position.distance_to(target_position)
	
	if velocity.x != 0:
		animacion.play("dash")
		if dash_rapido == true and dash_lento ==false:
			emisionidle.set_deferred("disabled", true)
			emisiondash.set_deferred("disabled", false)
		elif dash_rapido == false and dash_lento ==true:
			emisionidle.set_deferred("disabled", false)
			emisiondash.set_deferred("disabled", true)
	else:
		animacion.play("idle")
		emisionidle.set_deferred("disabled", false)
		emisiondash.set_deferred("disabled", true)
	
	# Si estamos a más de 5 píxeles de distancia, nos movemos 
	# (esto evita que el personaje "tiemble" al llegar al punto exacto)
	if distance > 10.0:
		# Calculamos la dirección hacia el objetivo
		var direction = global_position.direction_to(target_position)	
		# Asignamos la velocidad (dirección * rapidez) y movemos al personaje
		if dash_rapido == true and dash_lento ==false:
			velocity = direction * _velocidad
		elif dash_rapido== false and dash_lento==true:
			velocity = direction*_velocidad_lenta
		move_and_slide()
		reticula.global_position = target_position

	else:
		# Si ya llegó, detenemos el movimiento
		velocity = Vector2.ZERO
		var mouse_offset = get_global_mouse_position() - global_position
		reticula.global_position = global_position + mouse_offset.limit_length(radio_maximo)

##FUNCION PARA EL MOVIMIENTO DEL MOUSE
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Vector desde el personaje hasta el click (SIN limitar la posición absoluta)
		var vector_desplazamiento = get_global_mouse_position() - global_position
		# Ahora sí limitamos el desplazamiento, que es lo que tiene sentido limitar
		vector_desplazamiento = vector_desplazamiento.limit_length(radio_maximo)
		target_position = global_position + vector_desplazamiento
		dash_rapido=true
		dash_lento = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# Vector desde el personaje hasta el click (SIN limitar la posición absoluta)
		var vector_desplazamiento = get_global_mouse_position() - global_position
		# Ahora sí limitamos el desplazamiento, que es lo que tiene sentido limitar
		vector_desplazamiento = vector_desplazamiento.limit_length(radio_minimo)
		target_position = global_position + vector_desplazamiento
		dash_rapido = false
		dash_lento=true 
	

##FUNCION PARA CUANDO MUERE, es decir cuando la hitbox detecta algo que entra
func _on_area_2d_body_entered_idle(_body: Node2D) -> void:
	print("xddddd")
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
