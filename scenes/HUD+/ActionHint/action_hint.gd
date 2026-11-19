extends Node2D
## Tooltip de mundo para la mazmorra: icono de la acción necesaria, anillo
## pulsante y reacción (pop) cuando el jugador la ejecuta. Sin cajas de texto.

const COLORES := {
	"normal": Color(0.25, 0.55, 1.0),
	"fuerte": Color(1.0, 0.3, 0.2),
	"sombra": Color(0.72, 0.4, 1.0),
	"escudo": Color(0.95, 0.8, 0.25),
	"llave": Color(0.95, 0.8, 0.25),
	"meta": Color(0.9, 0.95, 1.0),
}

@onready var _icono: Sprite2D = $Icono

var _accion := ""
var _color := Color.WHITE
var _jugador: Node2D = null
var _t := 0.0
var _tween: Tween = null
var _hecho := false


func _ready() -> void:
	z_index = Constantes.Z_EFECTO
	add_to_group("action_hint")
	visible = false
	_buscar_jugador()


func accion_actual() -> String:
	return _accion


func reacciono() -> bool:
	return _hecho


func _process(delta: float) -> void:
	if _jugador == null or not is_instance_valid(_jugador):
		_buscar_jugador()
		if _jugador == null:
			visible = false
			return
	global_position = _jugador.global_position + Vector2(0, -110)
	if not visible:
		return
	_t += delta
	if not _hecho:
		_icono.scale = Vector2.ONE * (0.55 + 0.05 * sin(_t * 5.0))
		queue_redraw()


func mostrar(datos: Dictionary) -> void:
	if datos.is_empty():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_accion = datos.get("accion", "")
	_color = COLORES.get(_accion, Color.WHITE)
	_icono.texture = load(datos.get("icono", ""))
	_hecho = false
	modulate.a = 1.0
	visible = true
	_t = 0.0
	queue_redraw()


func _buscar_jugador() -> void:
	_jugador = get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	if _jugador == null:
		return
	if _jugador.has_signal("dash_normal"):
		_jugador.dash_normal.connect(_on_accion.bind("normal"))
		_jugador.dash_fuerte.connect(_on_accion.bind("fuerte"))
		_jugador.dash_sombra.connect(_on_accion.bind("sombra"))
		_jugador.llave_recogida.connect(_on_accion.bind("llave"))
		_jugador.golpe_absorbido.connect(_on_accion.bind("escudo"))
		_jugador.mejora_recogida.connect(_on_mejora)


func _on_mejora(tipo: String) -> void:
	if tipo == "escudo":
		_on_accion("escudo")


func _on_accion(tipo: String) -> void:
	if _hecho or tipo != _accion:
		return
	_hecho = true
	_tween = create_tween().set_parallel()
	_tween.tween_property(_icono, "scale", _icono.scale * 1.7, 0.15)
	_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	_tween.chain().tween_callback(func(): visible = false)


func _draw() -> void:
	if not visible:
		return
	var pulso := 0.5 + 0.5 * sin(_t * 5.0)
	draw_circle(Vector2.ZERO, 34.0, Color(_color, 0.10))
	draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 32, Color(_color, 0.35 + 0.4 * pulso), 3.0)
