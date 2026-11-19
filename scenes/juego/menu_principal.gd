extends CanvasLayer
## Menú principal: Jugar (pregunta si quiere tutorial) y Salir.
## Incluye música de fondo (en bucle, con fade-in) y fondo con parallax
## (ver menu_parallax.gd). La música se corta sola cuando juego.gd libera
## el menú al empezar la partida.

signal tutorial_solicitado
signal maze_solicitada

const VOLUMEN_MUSICA_DB := -6.0
const FADE_IN_MUSICA := 2.0
const SONIDO_INICIO := preload("res://assets/menu/iniciar-partida.wav")

@onready var _musica: AudioStreamPlayer = $Musica


func _ready() -> void:
	$BotonJugar.pressed.connect(_on_jugar)
	$BotonSalir.pressed.connect(get_tree().quit)
	$BotonJugar.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_iniciar_musica()


func _iniciar_musica() -> void:
	# Bucle: al terminar vuelve a empezar (funciona sin tocar el import del .wav).
	_musica.finished.connect(_musica.play)
	_musica.volume_db = -40.0
	_musica.play()
	create_tween().tween_property(_musica, "volume_db", VOLUMEN_MUSICA_DB, FADE_IN_MUSICA)


func _on_jugar() -> void:
	var dialogo := ConfirmationDialog.new()
	dialogo.title = "INFERNONAUT"
	dialogo.dialog_text = "¿Quieres jugar el tutorial?"
	dialogo.ok_button_text = "Sí, jugar tutorial"
	# El botón Cancel y la cruz (X) emiten la misma señal "canceled", por eso
	# antes la cruz empezaba la partida. Ocultamos Cancel y usamos un botón
	# personalizado para "sin tutorial": así "canceled" solo significa "cerrar".
	dialogo.get_cancel_button().hide()
	dialogo.add_button("No, jugar sin tutorial", false, "sin_tutorial")
	dialogo.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialogo)
	dialogo.confirmed.connect(_empezar.bind(dialogo, true))
	dialogo.custom_action.connect(_on_accion_dialogo.bind(dialogo))
	dialogo.canceled.connect(_cerrar_dialogo.bind(dialogo))
	dialogo.popup_centered()


func _on_accion_dialogo(accion: StringName, dialogo: Window) -> void:
	if accion == &"sin_tutorial":
		_reproducir_sonido_inicio()
		_empezar(dialogo, false)


## Cruz (X) o Escape: solo cierra la ventana y deja al jugador en el menú.
func _cerrar_dialogo(dialogo: Window) -> void:
	dialogo.queue_free()
	$BotonJugar.grab_focus()


## El sonido se reproduce en un reproductor propio colgado de la raíz del
## árbol: el menú se libera al empezar la partida y, si el sonido viviera
## aquí, se cortaría de golpe.
func _reproducir_sonido_inicio() -> void:
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = SONIDO_INICIO
	reproductor.process_mode = Node.PROCESS_MODE_ALWAYS
	reproductor.finished.connect(reproductor.queue_free)
	get_tree().root.add_child(reproductor)
	reproductor.play()


func _empezar(dialogo: Window, con_tutorial: bool) -> void:
	dialogo.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if con_tutorial:
		tutorial_solicitado.emit()
	else:
		maze_solicitada.emit()
