class_name Puerta
extends StaticBody2D
## Barrera física en el hueco entre salas. Se abre al tocarla con las llaves
## necesarias (las consume). El color y los pines muestran el requisito:
## verde = abierta, oro = 1, azul = 2, violeta = 3; pulsa en verde cuando
## el jugador ya puede abrirla. Se disuelve al abrirse.

signal abierta

const COLOR_ABIERTA := Color(0.35, 1.0, 0.5)
const COLOR_1 := Color(1.0, 0.82, 0.25)
const COLOR_2 := Color(0.3, 0.8, 1.0)
const COLOR_3 := Color(0.8, 0.4, 1.0)
const COLOR_DENEGADA := Color(1.0, 0.2, 0.2)
const RUTA_LLAVE := "res://sprites/ui/llave.svg"
const RUTA_DISOLVE := "res://scenes/nivel/door_dissolve.gdshader"

@export var necesita_llave := true
@export var llaves_requeridas := 1
@export var mostrar_aviso := true ## false en la mazmorra (sin cajas de texto)
@export var lado := "E" ## "E" (este/oeste) o "S" (sur/norte), para los pines

var _esta_abierta := false
var _ultimo_aviso := -2000
var _jugador: Node2D = null
var _sprite: Sprite2D = null
var _mat: ShaderMaterial = null
var _pips: Array = []
var _color_base := COLOR_1
var _suficiente := false
var _flash := 0.0
var _pulse := 0.5
var _t := 0.0


func _ready() -> void:
	add_to_group(Constantes.GRUPO_PUERTAS)
	var detector := Area2D.new()
	detector.name = "Detector"
	detector.collision_layer = 0
	detector.collision_mask = 1 ## cuerpo del jugador
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(170, 140)
	forma.shape = rect
	detector.add_child(forma)
	add_child(detector)
	detector.body_entered.connect(_on_body_entered)

	for hijo in get_children():
		if hijo is Sprite2D:
			_sprite = hijo
			break
	if _sprite != null:
		_mat = ShaderMaterial.new()
		_mat.shader = load(RUTA_DISOLVE)
		_mat.set_shader_parameter("progress", 0.0)
		_sprite.material = _mat

	_crear_pips()
	_actualizar_color()


func _process(delta: float) -> void:
	if _esta_abierta:
		return
	if _jugador == null or not is_instance_valid(_jugador):
		_jugador = get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	var llaves := int(_jugador.llaves) if _jugador != null else 0
	var suficiente := not necesita_llave or llaves >= llaves_requeridas
	var flash_antes := _flash
	_flash = maxf(_flash - delta, 0.0)
	_t += delta
	if suficiente != _suficiente:
		_suficiente = suficiente
		_actualizar_color()
	if _flash > 0.0 or _suficiente:
		_pulse = 0.5 + 0.5 * sin(_t * 5.0)
		_actualizar_pips()
		queue_redraw()
	elif flash_antes > 0.0:
		_actualizar_color()


func _on_body_entered(body: Node2D) -> void:
	if _esta_abierta or not body.is_in_group(Constantes.GRUPO_PERSONAJES):
		return
	if necesita_llave and body.get("llaves") < llaves_requeridas:
		_denegada()
		return
	if necesita_llave:
		body.llaves -= llaves_requeridas
	abrir()


func abrir() -> void:
	if _esta_abierta:
		return
	_esta_abierta = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	abierta.emit()
	for pip in _pips:
		pip.visible = false
	queue_redraw()
	if not is_inside_tree():
		visible = false
		return
	if _mat != null:
		var t := create_tween()
		t.tween_property(_mat, "shader_parameter/progress", 1.0, 0.45)
		t.tween_callback(queue_free)
	else:
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.3)
		t.tween_callback(queue_free)


func esta_abierta() -> bool:
	return _esta_abierta


## Color del requisito (oro/azul/violeta): llave.gd lo usa para el haz.
func color_requerida() -> Color:
	return _color_requerida()


func _denegada() -> void:
	_flash = 0.5
	_actualizar_color()
	if not mostrar_aviso:
		return
	var ahora := Time.get_ticks_msec()
	if ahora - _ultimo_aviso < 1500:
		return
	_ultimo_aviso = ahora
	var texto := "NECESITAS UNA LLAVE" if llaves_requeridas == 1 \
			else "NECESITAS %d LLAVES" % llaves_requeridas
	get_tree().call_group("tutorial_hud", "mensaje", texto)


func _crear_pips() -> void:
	if llaves_requeridas <= 0:
		return
	var textura: Texture2D = load(RUTA_LLAVE)
	var centro := (llaves_requeridas - 1) * 0.5
	for i in llaves_requeridas:
		for signo in [-1.0, 1.0]:
			var pip := Sprite2D.new()
			pip.texture = textura
			pip.scale = Vector2(0.28, 0.28)
			if lado == "E":
				pip.position = Vector2(90.0 * signo, (i - centro) * 22.0)
			else:
				pip.position = Vector2((i - centro) * 22.0, 90.0 * signo)
			add_child(pip)
			_pips.append(pip)


func _actualizar_color() -> void:
	_color_base = _color_requerida()
	var c := _color_actual()
	if _sprite != null:
		_sprite.modulate = Color.WHITE.lerp(c, 0.45)
	_actualizar_pips()
	queue_redraw()


func _actualizar_pips() -> void:
	var c := _color_actual()
	var alpha := 1.0 if not _suficiente else 0.65 + 0.35 * _pulse
	for pip in _pips:
		pip.modulate = Color(c.r, c.g, c.b, alpha)


func _color_actual() -> Color:
	if _flash > 0.0:
		return COLOR_DENEGADA
	return COLOR_ABIERTA if _suficiente else _color_base


func _color_requerida() -> Color:
	match llaves_requeridas:
		0:
			return COLOR_ABIERTA
		1:
			return COLOR_1
		2:
			return COLOR_2
		_:
			return COLOR_3


func _draw() -> void:
	if _esta_abierta:
		return
	var c := _color_actual()
	var borde := 0.30 + (0.30 * _pulse if _suficiente else 0.0)
	if _flash > 0.0:
		borde = 0.75
	draw_circle(Vector2.ZERO, 64.0, Color(c, 0.10))
	draw_arc(Vector2.ZERO, 68.0, 0.0, TAU, 48, Color(c, borde), 3.0)
