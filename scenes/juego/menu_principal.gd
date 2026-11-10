extends CanvasLayer
## Menú principal. El tutorial está siempre disponible; la arena directa se
## desbloquea cuando el tutorial se ha completado al menos una vez.

signal tutorial_solicitado
signal arena_solicitada


func _ready() -> void:
	$BotonTutorial.pressed.connect(_on_tutorial)
	$BotonArena.pressed.connect(_on_arena)
	$BotonSalir.pressed.connect(get_tree().quit)
	var completo := Progreso.tutorial_completado()
	$BotonArena.disabled = not completo
	$BotonArena.tooltip_text = "Completa el tutorial una vez para desbloquear." \
			if not completo else "Entra directamente a la arena."
	$Estado.text = "TUTORIAL COMPLETADO — ARENA DESBLOQUEADA" if completo \
			else "Completa el tutorial para desbloquear la arena."
	$BotonTutorial.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_tutorial() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	tutorial_solicitado.emit()


func _on_arena() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	arena_solicitada.emit()
