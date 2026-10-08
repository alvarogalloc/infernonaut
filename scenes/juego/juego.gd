extends Node
## Escena principal: orquesta menú -> carga -> nivel generado.
## Los niveles se generan en runtime con GeneradorNivel (semilla aleatoria).

const MENU := preload("res://scenes/juego/menu_principal.tscn")
const CARGA := preload("res://scenes/juego/pantalla_carga.tscn")
const MUERTE := preload("res://scenes/HUD+/PantallaMuerte/pantalla_muerte.tscn")
const PAUSA := preload("res://scenes/HUD+/PantallaPausa/pantalla_pausa.tscn")

var _menu: CanvasLayer = null
var _carga: CanvasLayer = null
var _pausa: CanvasLayer = null
var _nivel: Node2D = null
var _muerto: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mostrar_menu()


func _limpiar() -> void:
	for n in [_menu, _carga, _pausa, _nivel]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_menu = null
	_carga = null
	_pausa = null
	_nivel = null
	_muerto = false
	get_tree().paused = false


func _mostrar_menu() -> void:
	_limpiar()
	_menu = MENU.instantiate()
	add_child(_menu)
	_menu.iniciar_solicitado.connect(_iniciar_partida)


func _iniciar_partida() -> void:
	_limpiar()
	_carga = CARGA.instantiate()
	add_child(_carga)
	# Deja que la pantalla de carga se dibuje antes de generar (bloqueante).
	await get_tree().process_frame
	await get_tree().process_frame
	var generador := GeneradorNivel.new()
	_nivel = generador.generar(randi())
	add_child(_nivel)
	# Mínimo de tiempo en pantalla para que se vea la animación.
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(_carga):
		_carga.queue_free()
		_carga = null
	var jug := get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	if jug != null and not jug.personaje_muerto.is_connected(_on_muerte):
		jug.personaje_muerto.connect(_on_muerte)


func _on_muerte() -> void:
	_muerto = true
	add_child(MUERTE.instantiate())
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _muerto or _nivel == null:
		return
	if _pausa != null:
		_cerrar_pausa()
	else:
		_abrir_pausa()


func _abrir_pausa() -> void:
	_pausa = PAUSA.instantiate()
	add_child(_pausa)
	_pausa.reanudar_solicitado.connect(_cerrar_pausa)
	get_tree().paused = true


func _cerrar_pausa() -> void:
	if _pausa != null:
		_pausa.queue_free()
		_pausa = null
	get_tree().paused = false
