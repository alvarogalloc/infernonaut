extends CanvasLayer
## Menú principal: Jugar (pregunta si quiere tutorial) y Salir.
## Incluye música de fondo (en bucle, con fade-in) y fondo con parallax
## (ver menu_parallax.gd). La música se corta sola cuando juego.gd libera
## el menú al empezar la partida.

signal tutorial_solicitado
signal maze_solicitada

const VOLUMEN_MUSICA_DB := -6.0
const FADE_IN_MUSICA := 2.0

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
	dialogo.cancel_button_text = "No, jugar sin tutorial"
	dialogo.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialogo)
	dialogo.confirmed.connect(_empezar.bind(dialogo, true))
	dialogo.canceled.connect(_empezar.bind(dialogo, false))
	dialogo.popup_centered()


func _empezar(dialogo: Window, con_tutorial: bool) -> void:
	dialogo.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if con_tutorial:
		tutorial_solicitado.emit()
	else:
		maze_solicitada.emit()
