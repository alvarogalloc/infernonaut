extends CanvasLayer
## Menú principal: Jugar (pregunta si quiere tutorial) y Salir.

signal tutorial_solicitado
signal maze_solicitada


func _ready() -> void:
	$BotonJugar.pressed.connect(_on_jugar)
	$BotonSalir.pressed.connect(get_tree().quit)
	$BotonJugar.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
