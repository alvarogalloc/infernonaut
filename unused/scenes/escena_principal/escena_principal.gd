extends Node

const PANTALLA_MUERTE := preload("res://scenes/HUD+/PantallaMuerte/pantalla_muerte.tscn")
const PANTALLA_PAUSA := preload("res://scenes/HUD+/PantallaPausa/pantalla_pausa.tscn")

var _pantalla_pausa_actual: CanvasLayer = null
var _juego_terminado: bool = false # true cuando ya se murió, para que ESC deje de pausar


func _ready() -> void:
	# Para que este nodo siga escuchando el ESC aunque el juego esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El jugador se agrega solo al grupo "personajes" en su propio _ready(),
	# y los nodos hijos siempre terminan su _ready() antes que el padre,
	# así que para cuando llegamos aquí ya está en el grupo.
	var jugador := get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	if jugador:
		jugador.personaje_muerto.connect(_on_personaje_muerto)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _juego_terminado:
		return
	if _pantalla_pausa_actual:
		_cerrar_pausa()
	else:
		_abrir_pausa()


func _abrir_pausa() -> void:
	if _pantalla_pausa_actual or _juego_terminado:
		return
	_pantalla_pausa_actual = PANTALLA_PAUSA.instantiate()
	add_child(_pantalla_pausa_actual)
	_pantalla_pausa_actual.reanudar_solicitado.connect(_cerrar_pausa)
	get_tree().paused = true


func _cerrar_pausa() -> void:
	if _pantalla_pausa_actual:
		_pantalla_pausa_actual.queue_free()
		_pantalla_pausa_actual = null

	get_tree().paused = false


func _on_personaje_muerto() -> void:
	_juego_terminado = true
	_cerrar_pausa() # por si murió justo mientras el juego estaba en pausa

	add_child(PANTALLA_MUERTE.instantiate())
	get_tree().paused = true
