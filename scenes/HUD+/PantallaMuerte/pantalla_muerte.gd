extends CanvasLayer

@onready var boton_reiniciar: Button = $Control/Panel/VBoxContainer/BotonReiniciar
@onready var boton_salir: Button = $Control/Panel/VBoxContainer/BotonSalir


func _ready() -> void:
	# PROCESS_MODE_ALWAYS: para que la pantalla (y sus botones) sigan respondiendo aunque el árbol esté en pausa (get_tree().paused = true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	boton_reiniciar.pressed.connect(_on_boton_reiniciar_pressed)
	boton_salir.pressed.connect(_on_boton_salir_pressed)
	boton_reiniciar.grab_focus()


func _on_boton_reiniciar_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_boton_salir_pressed() -> void:
	get_tree().quit()
