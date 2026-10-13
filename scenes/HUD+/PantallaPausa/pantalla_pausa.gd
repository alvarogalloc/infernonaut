extends CanvasLayer

## Se emite cuando el jugador pide reanudar (botón o ESC dentro de esta
## pantalla). juego.gd la escucha para saber cuándo debe quitar esta
## pantalla y despausar el juego.
signal reanudar_solicitado

## Se emite al pedir reiniciar: juego.gd regenera la MISMA semilla.
signal reiniciar_solicitado

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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_boton_reanudar_pressed() -> void:
	reanudar_solicitado.emit()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _on_boton_reiniciar_pressed() -> void:
	reiniciar_solicitado.emit()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _on_boton_salir_pressed() -> void:
	get_tree().quit()
