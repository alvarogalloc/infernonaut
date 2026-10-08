extends CanvasLayer
## Menú principal aislado. Emite `iniciar_solicitado` al pedir partida.
signal iniciar_solicitado


func _ready() -> void:
	$BotonIniciar.pressed.connect(_on_iniciar)
	$BotonSalir.pressed.connect(_on_salir)
	$BotonIniciar.grab_focus()


func _on_iniciar() -> void:
	iniciar_solicitado.emit()


func _on_salir() -> void:
	get_tree().quit()
