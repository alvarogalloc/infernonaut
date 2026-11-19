extends Node
## Escena principal: menú -> carga -> nivel curado.
## Modos: "tutorial", "maze" (mazmorra demo) y "arena" (desbloqueada).

const MENU := preload("res://scenes/juego/menu_principal.tscn")
const CARGA := preload("res://scenes/juego/pantalla_carga.tscn")
const MUERTE := preload("res://scenes/HUD+/PantallaMuerte/pantalla_muerte.tscn")
const PAUSA := preload("res://scenes/HUD+/PantallaPausa/pantalla_pausa.tscn")
const NIVEL := preload("res://scenes/nivel/tutorial.tscn")
const MAZE := preload("res://scenes/nivel/maze.tscn")
## Música de fondo de la partida sin tutorial (modo "maze").
const OST := preload("res://assets/musica/ost_juego.ogg")
const OST_VOLUMEN_DB := -12.0
const OST_FADE_SALIDA := 0.6

var _menu: CanvasLayer = null
var _carga: CanvasLayer = null
var _pausa: CanvasLayer = null
var _muerte: CanvasLayer = null
var _fin: CanvasLayer = null
var _nivel: Node = null
var _muerto: bool = false
var _modo := "tutorial"
var _ost: AudioStreamPlayer = null
var _ost_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El reproductor vive aquí (no en el nivel) para que la música no se corte
	# al reiniciar la partida; solo para al volver al menú.
	OST.loop
	_ost = AudioStreamPlayer.new()
	_ost.stream = OST
	_ost.volume_db = OST_VOLUMEN_DB
	add_child(_ost)
	_mostrar_menu()


func _limpiar() -> void:
	for n in [_menu, _carga, _pausa, _muerte, _fin, _nivel]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_menu = null
	_carga = null
	_pausa = null
	_muerte = null
	_fin = null
	_nivel = null
	_muerto = false
	get_tree().paused = false


func _mostrar_menu() -> void:
	_limpiar()
	_detener_ost()
	_menu = MENU.instantiate()
	add_child(_menu)
	_menu.tutorial_solicitado.connect(_iniciar_tutorial)
	_menu.maze_solicitada.connect(_iniciar_maze)


func _iniciar_tutorial() -> void:
	_iniciar_partida("tutorial")


func _iniciar_maze() -> void:
	_iniciar_partida("maze")


func _iniciar_partida(modo: String) -> void:
	_limpiar()
	_modo = modo
	if modo == "maze":
		_iniciar_ost()
	else:
		_detener_ost()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_carga = CARGA.instantiate()
	add_child(_carga)
	# Deja que la pantalla de carga se dibuje antes de construir.
	await get_tree().process_frame
	await get_tree().process_frame
	_nivel = (MAZE if modo == "maze" else NIVEL).instantiate()
	if modo == "maze":
		_nivel.set("modo", "maze")
	else:
		_nivel.set("solo_arena", modo == "arena")
	add_child(_nivel)
	_nivel.connect("completado", _on_completado)
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(_carga):
		_carga.queue_free()
		_carga = null
	var jug := get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	if jug != null and not jug.personaje_muerto.is_connected(_on_muerte):
		jug.personaje_muerto.connect(_on_muerte)


## Arranca el OST. Si ya está sonando (reinicio tras morir) lo deja seguir.
func _iniciar_ost() -> void:
	if _ost_tween != null:
		_ost_tween.kill()
		_ost_tween = null
		
	_ost.volume_db = OST_VOLUMEN_DB
	
	if not _ost.playing:
		# En lugar de hacer _ost.play() directo, creamos un Tween con retraso
		_ost_tween = create_tween()
		_ost_tween.tween_interval(3.0) # Espera 3 segundos
		_ost_tween.tween_callback(_ost.play) # Ejecuta el play() tras la espera

## Baja el volumen y lo detiene (al volver al menú o entrar a otro modo).
## Baja el volumen y lo detiene (al volver al menú o entrar a otro modo).
func _detener_ost() -> void:
	# 1. Matamos el tween primero por si estaba en medio de los 3 segundos de espera
	if _ost_tween != null:
		_ost_tween.kill()
		_ost_tween = null
		
	# 2. Si no estaba sonando, ya no hay nada más que hacer
	if not _ost.playing:
		return
		
	# 3. Si ya estaba sonando, hacemos el fade out normal
	_ost_tween = create_tween()
	_ost_tween.tween_property(_ost, "volume_db", -40.0, OST_FADE_SALIDA)
	_ost_tween.tween_callback(_ost.stop)

func _on_completado() -> void:
	if _modo == "tutorial":
		Progreso.marcar_tutorial_completado()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fin = CanvasLayer.new()
	_fin.process_mode = Node.PROCESS_MODE_ALWAYS
	_fin.layer = 60
	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.02, 0.04, 0.92)
	fondo.anchor_right = 1.0
	fondo.anchor_bottom = 1.0
	_fin.add_child(fondo)
	var caja := VBoxContainer.new()
	caja.offset_left = 560.0
	caja.offset_top = 360.0
	caja.offset_right = 1360.0
	caja.offset_bottom = 720.0
	caja.add_theme_constant_override("separation", 18)
	_fin.add_child(caja)
	var titulo := Label.new()
	var subtitulo := Label.new()
	if _modo == "maze":
		titulo.text = "MAZMORRA COMPLETADA"
		subtitulo.text = "Demo completada. Prueba el tutorial o la arena."
	elif _modo == "arena":
		titulo.text = "ARENA COMPLETADA"
		subtitulo.text = "Sobreviviste a la arena."
	else:
		titulo.text = "TUTORIAL COMPLETADO"
		subtitulo.text = "La arena queda desbloqueada en el menú."
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	subtitulo.add_theme_font_size_override("font_size", 28)
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(subtitulo)
	var boton := Button.new()
	boton.text = "VOLVER AL MENÚ"
	boton.add_theme_font_size_override("font_size", 32)
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	boton.pressed.connect(_mostrar_menu)
	caja.add_child(boton)
	add_child(_fin)
	get_tree().paused = true


func _on_muerte() -> void:
	_muerto = true
	_muerte = MUERTE.instantiate()
	add_child(_muerte)
	_muerte.reiniciar_solicitado.connect(_reiniciar)
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _muerto or _nivel == null:
		return
	if _pausa != null:
		_cerrar_pausa()
	else:
		_abrir_pausa()


func _abrir_pausa() -> void:
	Sfx.abrir_pausa(self)
	_pausa = PAUSA.instantiate()
	add_child(_pausa)
	_pausa.reanudar_solicitado.connect(_cerrar_pausa)
	_pausa.reiniciar_solicitado.connect(_reiniciar)
	_pausa.salir_solicitado.connect(_mostrar_menu)
	get_tree().paused = true


func _cerrar_pausa() -> void:
	if _pausa != null:
		_pausa.queue_free()
		_pausa = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _reiniciar() -> void:
	_iniciar_partida(_modo)
