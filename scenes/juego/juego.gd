extends Node
## Escena principal: orquesta menú -> carga -> nivel generado.
## Los niveles se generan en runtime con GeneradorNivel. La semilla la fija
## el menú; reiniciar (pausa o muerte) vuelve a generar la MISMA semilla.

const MENU := preload("res://scenes/juego/menu_principal.tscn")
const CARGA := preload("res://scenes/juego/pantalla_carga.tscn")
const MUERTE := preload("res://scenes/HUD+/PantallaMuerte/pantalla_muerte.tscn")
const PAUSA := preload("res://scenes/HUD+/PantallaPausa/pantalla_pausa.tscn")

@export_group("Densidades de entidad")
## Escalas aplicadas al generar el nivel (1.0 = normal, 0.0 = sin esa entidad,
## 2.0 = el doble). Se ajustan desde el inspector de juego.tscn.
@export var densidad_enemigo_mele: float = 1.0
@export var densidad_cobarde: float = 1.0
@export var densidad_pincho: float = 1.0
@export var densidad_antorcha: float = 1.0
@export var densidad_recompensa: float = 1.0

var _menu: CanvasLayer = null
var _carga: CanvasLayer = null
var _pausa: CanvasLayer = null
var _muerte: CanvasLayer = null
var _nivel: Node2D = null
var _muerto: bool = false
var _semilla := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mostrar_menu()


func _limpiar() -> void:
	for n in [_menu, _carga, _pausa, _muerte, _nivel]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_menu = null
	_carga = null
	_pausa = null
	_muerte = null
	_nivel = null
	_muerto = false
	get_tree().paused = false


func _mostrar_menu() -> void:
	_limpiar()
	_menu = MENU.instantiate()
	add_child(_menu)
	_menu.iniciar_solicitado.connect(_iniciar_partida)


func _iniciar_partida(semilla: int) -> void:
	_limpiar()
	_semilla = semilla
	_carga = CARGA.instantiate()
	add_child(_carga)
	# Deja que la pantalla de carga se dibuje antes de generar (bloqueante).
	await get_tree().process_frame
	await get_tree().process_frame
	var generador := GeneradorNivel.new()
	_nivel = generador.generar(_semilla, -1, _densidades())
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
	_muerte = MUERTE.instantiate()
	add_child(_muerte)
	_muerte.reiniciar_solicitado.connect(_reiniciar)
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
	_pausa.reiniciar_solicitado.connect(_reiniciar)
	get_tree().paused = true


func _cerrar_pausa() -> void:
	if _pausa != null:
		_pausa.queue_free()
		_pausa = null
	get_tree().paused = false


## Reinicio desde pausa o muerte: nueva partida con la MISMA semilla.
func _reiniciar() -> void:
	_iniciar_partida(_semilla)


## Densidades de entidad tomadas de los exports del inspector.
func _densidades() -> Dictionary:
	return {
		"densidad_enemigo_mele": densidad_enemigo_mele,
		"densidad_cobarde": densidad_cobarde,
		"densidad_pincho": densidad_pincho,
		"densidad_antorcha": densidad_antorcha,
		"densidad_recompensa": densidad_recompensa,
	}
