extends CanvasLayer

## Se emite cuando el jugador pide reanudar (botón o ESC dentro de esta
## pantalla). escena_principal.gd la escucha para saber cuándo debe
## quitar esta pantalla y despausar el juego.
signal reanudar_solicitado

@onready var boton_reanudar: Button = $Control/Panel/VBoxContainer/BotonReanudar
@onready var boton_reiniciar: Button = $Control/Panel/VBoxContainer/BotonReiniciar
@onready var boton_salir: Button = $Control/Panel/VBoxContainer/BotonSalir


func _ready() -> void:
	# Para que la pantalla (y sus botones) sigan respondiendo aunque
	# el árbol esté en pausa (get_tree().paused = true)
	process_mode = Node.PROCESS_MODE_ALWAYS

	boton_reanudar.pressed.connect(_on_boton_reanudar_pressed)
	boton_reiniciar.pressed.connect(_on_boton_reiniciar_pressed)
	boton_salir.pressed.connect(_on_boton_salir_pressed)

	boton_reanudar.grab_focus()


func _on_boton_reanudar_pressed() -> void:
	reanudar_solicitado.emit()


func _on_boton_reiniciar_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_boton_salir_pressed() -> void:
	get_tree().quit()
