extends CharacterBody2D
## Estados:
##   INACTIVO     -> esperando a que el jugador entre en el área de activación
##   REACCIONANDO -> se dio cuenta del jugador (mismo delay que enemigo_1)
##   HUYENDO      -> se aleja del jugador
##   PREPARANDO   -> parado; marca la posición del jugador y muestra el telégrafo
##   ATACANDO     -> la mano sale hacia el punto marcado; después una pequeña recuperación
##   MUERTO

enum Estado { INACTIVO, REACCIONANDO, HUYENDO, PREPARANDO, ATACANDO, MUERTO }

@export_group("Huida")
@export var velocidad_huida: float = 300.0
@export var tiempo_deteccion: float = 0.6 ## Delay antes de empezar a huir

@export_group("Ataque")
@export var intervalo_ataque: float = 2.5 ## Segundos huyendo antes de detenerse a atacar
@export var tiempo_preparacion: float = 0.7 ## Parado con el telégrafo visible (ventana para esquivar)
@export var tiempo_extension: float = 0.15 ## Lo que tarda la mano en llegar al punto marcado
@export var duracion_ataque: float = 0.5 ## Tiempo total que la hitbox está activa (incluye la extensión)
@export var tiempo_recuperacion: float = 0.5 ## Parado después del ataque, antes de volver a huir
@export var ancho_ataque: float = 120.0
@export var alcance_maximo: float = 1500.0

@export_group("Nodos")
@export var collision: CollisionShape2D
@export var hitboxDead: CollisionShape2D
@export var area_activacion: CollisionShape2D
@export var boca: Marker2D ## Punto de donde sale la mano
@export var hitbox_ataque: Area2D
@export var shape_ataque: CollisionShape2D ## Su shape es local_to_scene (se redimensiona por instancia)
@export var placeholder_ataque: ColorRect ## Visual provisional de la mano
@export var telegrafo: Line2D ## Visual provisional de la advertencia

var jugador: Node2D = null

var _estado: Estado = Estado.INACTIVO
var _tiempo_estado: float = 0.0
var _jugador_en_area: bool = false
var _normal_pared: Vector2 = Vector2.ZERO

# Datos del ataque en curso (se fijan al empezar PREPARANDO)
var _angulo_ataque: float = 0.0
var _largo_ataque: float = 0.0
var _hitbox_activo: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	telegrafo.hide()
	_apagar_hitbox_ataque()


func _physics_process(delta: float) -> void:
	if _estado == Estado.MUERTO:
		return

	# Si el jugador desapareció (escena liberada, etc.) volvemos a reposo
	if _estado != Estado.INACTIVO and not is_instance_valid(jugador):
		_cambiar_estado(Estado.INACTIVO)
		return

	_tiempo_estado += delta

	match _estado:
		Estado.REACCIONANDO:
			if _tiempo_estado >= tiempo_deteccion:
				_cambiar_estado(Estado.HUYENDO)
		Estado.HUYENDO:
			_huir()
			if _tiempo_estado >= intervalo_ataque:
				_cambiar_estado(Estado.PREPARANDO)
		Estado.PREPARANDO:
			if _tiempo_estado >= tiempo_preparacion:
				_cambiar_estado(Estado.ATACANDO)
		Estado.ATACANDO:
			_actualizar_ataque()


func _cambiar_estado(nuevo: Estado) -> void:
	if _estado == Estado.MUERTO:
		return

	_estado = nuevo
	_tiempo_estado = 0.0

	# Limpieza al salir de PREPARANDO / ATACANDO, sin importar por qué se salió
	if nuevo != Estado.PREPARANDO:
		telegrafo.hide()
	if nuevo != Estado.ATACANDO:
		_apagar_hitbox_ataque()

	match nuevo:
		Estado.INACTIVO:
			velocity = Vector2.ZERO
			# ANIMACION: idle
		Estado.REACCIONANDO:
			velocity = Vector2.ZERO
			# ANIMACION: detection
		Estado.HUYENDO:
			pass
			# ANIMACION: correr / huir
		Estado.PREPARANDO:
			velocity = Vector2.ZERO
			_iniciar_telegrafo()
			# ANIMACION: abrir la boca / preparar ataque
		Estado.ATACANDO:
			velocity = Vector2.ZERO
			_iniciar_ataque()
			# ANIMACION: la mano saliendo de la boca
		Estado.MUERTO:
			velocity = Vector2.ZERO
			# ANIMACION: muerte


# ---------------------------------------------------------------- HUIDA

func _huir() -> void:
	var dir := jugador.global_position.direction_to(global_position) # dirección contraria al jugador
	if dir.is_zero_approx():
		dir = Vector2.from_angle(randf() * TAU)

	# Si el frame anterior chocó con una pared y esta dirección empuja contra ella,
	# nos deslizamos a lo largo de la pared (hacia el lado que más nos aleja del jugador).
	if _normal_pared != Vector2.ZERO and dir.dot(_normal_pared) < 0.0:
		var tangente := _normal_pared.orthogonal()
		if tangente.dot(dir) < 0.0:
			tangente = -tangente
		dir = tangente

	velocity = dir * velocidad_huida
	move_and_slide()

	if get_slide_collision_count() > 0:
		_normal_pared = get_slide_collision(0).get_normal()
	else:
		_normal_pared = Vector2.ZERO


# --------------------------------------------------------------- ATAQUE

## Fija a dónde irá la mano (posición del jugador EN ESTE MOMENTO, no lo sigue)
## y muestra el telégrafo para que el jugador pueda esquivar.
func _iniciar_telegrafo() -> void:
	var origen := boca.global_position
	var hacia := jugador.global_position - origen
	_largo_ataque = clampf(hacia.length(), 20.0, alcance_maximo)
	_angulo_ataque = hacia.angle()

	hitbox_ataque.global_rotation = _angulo_ataque
	telegrafo.width = ancho_ataque
	telegrafo.points = PackedVector2Array([Vector2.ZERO, Vector2(_largo_ataque, 0.0)])
	telegrafo.show()


func _iniciar_ataque() -> void:
	_hitbox_activo = true
	_establecer_largo_ataque(0.0)
	placeholder_ataque.show()
	shape_ataque.set_deferred("disabled", false)


func _actualizar_ataque() -> void:
	if _hitbox_activo:
		# La mano crece desde la boca hasta el punto marcado
		var progreso := 1.0
		if tiempo_extension > 0.0:
			progreso = clampf(_tiempo_estado / tiempo_extension, 0.0, 1.0)
		_establecer_largo_ataque(_largo_ataque * progreso)

		if _tiempo_estado >= duracion_ataque:
			_apagar_hitbox_ataque()

	# Terminó el ataque + recuperación: volver a huir (o a reposo si el jugador ya se fue)
	if _tiempo_estado >= duracion_ataque + tiempo_recuperacion:
		if _jugador_en_area:
			_cambiar_estado(Estado.HUYENDO)
		else:
			_cambiar_estado(Estado.INACTIVO)


## Redimensiona la hitbox y el placeholder. La hitbox sale desde la boca (origen local 0,0)
## y se extiende en +X; el nodo ya está rotado hacia el objetivo.
func _establecer_largo_ataque(largo: float) -> void:
	largo = maxf(largo, 1.0)
	(shape_ataque.shape as RectangleShape2D).size = Vector2(largo, ancho_ataque)
	shape_ataque.position = Vector2(largo * 0.5, 0.0)
	placeholder_ataque.position = Vector2(0.0, -ancho_ataque * 0.5)
	placeholder_ataque.size = Vector2(largo, ancho_ataque)


func _apagar_hitbox_ataque() -> void:
	_hitbox_activo = false
	shape_ataque.set_deferred("disabled", true)
	placeholder_ataque.hide()


## La mano toca al jugador. Se detecta el area "idle" del personaje, que ya se
## desactiva durante el dash fuerte, así que el dash fuerte atraviesa la mano.
func _on_hitbox_ataque_area_entered(area: Area2D) -> void:
	var objetivo := area.get_parent()
	if objetivo and objetivo.is_in_group(Constantes.GRUPO_PERSONAJES):
		objetivo.morir()


# ---------------------------------------------------------------- MUERTE

func trigger_dim_light() -> void:
	var luz := get_node_or_null("enemy_emission") as PointLight2D
	if luz == null:
		return
	var tween := create_tween()
	const dim_duration := 1.5
	tween.tween_property(luz, "energy", 0.0, dim_duration)
	tween.tween_property(luz, "texture_scale", 0.0, dim_duration)


func _morir() -> void:
	if _estado == Estado.MUERTO:
		return

	_cambiar_estado(Estado.MUERTO) # también apaga la hitbox de ataque y el telégrafo
	trigger_dim_light()

	collision.set_deferred("disabled", true)
	hitboxDead.set_deferred("disabled", true)
	area_activacion.set_deferred("disabled", true)


# Detecta el golpe (dash fuerte) que mata al enemigo
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

func _on_activate_body_entered(body: Node2D) -> void:
	if _estado == Estado.MUERTO or not body.is_in_group(Constantes.GRUPO_PERSONAJES):
		return

	jugador = body
	_jugador_en_area = true

	if not jugador.personaje_muerto.is_connected(_on_jugador_muerto):
		jugador.personaje_muerto.connect(_on_jugador_muerto)

	if _estado == Estado.INACTIVO:
		_cambiar_estado(Estado.REACCIONANDO)


func _on_activate_body_exited(body: Node2D) -> void:
	if body != jugador:
		return

	_jugador_en_area = false

	# Si estaba huyendo, deja de hacerlo. Si está en pleno ataque lo termina
	# (ver _actualizar_ataque) y luego pasa a reposo.
	if _estado == Estado.REACCIONANDO or _estado == Estado.HUYENDO:
		_cambiar_estado(Estado.INACTIVO)


func _on_jugador_muerto() -> void:
	_jugador_en_area = false
	_cambiar_estado(Estado.INACTIVO)
