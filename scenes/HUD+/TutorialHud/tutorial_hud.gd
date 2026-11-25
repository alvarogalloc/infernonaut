extends CanvasLayer
## HUD del tutorial: cada lección abre un panel modal que pausa el juego
## hasta que el jugador pulsa CONTINUAR. Los mensajes puntuales (llave,
## puerta) siguen siendo avisos no bloqueantes.

const LECCIONES := [
	{
		"icono": "res://sprites/ui/raton_der.svg",
		"titulo": "CLIC DERECHO — DASH CORTO",
		"texto": "No hay caminar: cada clic te lanza. Recoge la llave y abre la puerta.",
	},
	{
		"icono": "res://sprites/ui/raton_izq.svg",
		"titulo": "CLIC IZQUIERDO — DASH FUERTE",
		"texto": "Daña enemigos y gasta 1 vial. El guardia de esta sala lleva la llave: mátalo.",
	},
	{
		"icono": "res://sprites/shield.png",
		"titulo": "ESCUDO",
		"texto": "Absorbe un golpe letal. Cruza los pinchos: sin escudo, mueres.",
	},
	{
		"icono": "res://sprites/ui/raton_centro.svg",
		"titulo": "CLIC CENTRAL — DASH SOMBRA",
		"texto": "Atraviesa paredes y aterriza en el último punto libre. Gasta 1 carga.",
	},
	{
		"icono": "res://sprites/key.png",
		"titulo": "EXAMEN FINAL",
		"texto": "Combina escudo y dash sombra. La llave abre la puerta a la arena.",
	},
	{
		"icono": "res://sprites/ui/meta.svg",
		"titulo": "ARENA",
		"texto": "Sobrevive y llega a la meta. Ahí termina el tutorial.",
	},
]

@onready var _fondo: ColorRect = $Fondo
@onready var _panel: PanelContainer = $Panel
@onready var _icono: TextureRect = $Panel/Fila/Icono
@onready var _titulo: Label = $Panel/Fila/Textos/Titulo
@onready var _texto: Label = $Panel/Fila/Textos/Texto
@onready var _continuar: Button = $Panel/Fila/Textos/Continuar
@onready var _mensaje: Label = $Mensaje

var _actual := -1
var _msg_tween: Tween
var _panel_tween: Tween
var _pausado_por_leccion := false
var _mouse_previo := Input.MOUSE_MODE_HIDDEN


func _ready() -> void:
	# Para que el botón siga respondiendo con get_tree().paused = true.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("tutorial_hud")
	_panel.visible = false
	_fondo.visible = false
	_mensaje.modulate.a = 0.0
	_continuar.pressed.connect(_continuar_leccion)


func mostrar_leccion(indice: int) -> void:
	if indice == _actual or indice < 0 or indice >= LECCIONES.size():
		return
	_actual = indice
	var leccion: Dictionary = LECCIONES[indice]
	_icono.texture = load(leccion.icono)
	_titulo.text = leccion.titulo
	_texto.text = leccion.texto
	_abrir()


func _abrir() -> void:
	if not _panel.visible:
		_mouse_previo = Input.mouse_mode
	_panel.visible = true
	_fondo.visible = true
	# En headless nadie puede pulsar CONTINUAR: no bloquear la partida.
	if DisplayServer.get_name() != "headless" and not get_tree().paused:
		get_tree().paused = true
		_pausado_por_leccion = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continuar.grab_focus()
	_fondo.modulate.a = 0.0
	_panel.modulate.a = 0.0
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_panel_tween.tween_property(_fondo, "modulate:a", 1.0, 0.2)
	_panel_tween.tween_property(_panel, "modulate:a", 1.0, 0.25)


func _continuar_leccion() -> void:
	Sfx.seleccionar_opcion(self)
	_panel.visible = false
	_fondo.visible = false
	Input.mouse_mode = _mouse_previo
	if _pausado_por_leccion:
		get_tree().paused = false
		_pausado_por_leccion = false


func _unhandled_input(event: InputEvent) -> void:
	# Mientras la lección está abierta, ESC no debe abrir el menú de pausa.
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func mensaje(texto: String) -> void:
	_mensaje.text = texto
	_mensaje.modulate.a = 1.0
	if _msg_tween != null and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.3)
	_msg_tween.tween_property(_mensaje, "modulate:a", 0.0, 0.4)
