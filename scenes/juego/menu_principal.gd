extends CanvasLayer
## Menú principal aislado. Emite `iniciar_solicitado(semilla)` al pedir
## partida: la semilla la decide la caja de texto (o el botón Nueva).
signal iniciar_solicitado(semilla: int)

@onready var semilla_input: LineEdit = %SemillaInput


func _ready() -> void:
	$BotonIniciar.pressed.connect(_on_iniciar)
	$BotonSalir.pressed.connect(_on_salir)
	%BotonSemilla.pressed.connect(_on_nueva_semilla)
	semilla_input.text = str(randi())
	$BotonIniciar.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Semilla de la caja: entero válido = ese; inválido/vacío = aleatoria.
func _seed_actual() -> int:
	var t := semilla_input.text.strip_edges()
	if t.is_valid_int():
		return t.to_int()
	return randi()


func _on_nueva_semilla() -> void:
	semilla_input.text = str(randi())


func _on_iniciar() -> void:
	iniciar_solicitado.emit(_seed_actual())
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _on_salir() -> void:
	get_tree().quit()
