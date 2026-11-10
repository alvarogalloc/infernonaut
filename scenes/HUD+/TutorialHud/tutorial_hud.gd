extends CanvasLayer
## HUD del tutorial: una lección por sala y mensajes puntuales (llave, puerta).

const LECCIONES := [
	{
		"icono": "res://sprites/ui/raton_der.svg",
		"titulo": "CLIC DERECHO — DASH CORTO",
		"texto": "No hay caminar: cada clic te lanza. Recoge la llave y abre la puerta.",
	},
	{
		"icono": "res://sprites/ui/raton_izq.svg",
		"titulo": "CLIC IZQUIERDO — DASH FUERTE",
		"texto": "Daña enemigos y gasta 1 vial. El guardia de esta sala lleva la llave: mátalo.",
	},
	{
		"icono": "res://sprites/ui/escudo.svg",
		"titulo": "ESCUDO",
		"texto": "Absorbe un golpe letal. Cruza los pinchos: sin escudo, mueres.",
	},
	{
		"icono": "res://sprites/ui/raton_centro.svg",
		"titulo": "CLIC CENTRAL — DASH SOMBRA",
		"texto": "Atraviesa paredes y aterriza en el último punto libre. Gasta 1 carga.",
	},
	{
		"icono": "res://sprites/ui/llave.svg",
		"titulo": "EXAMEN FINAL",
		"texto": "Combina escudo y dash sombra. La llave abre la puerta a la arena.",
	},
	{
		"icono": "res://sprites/ui/meta.svg",
		"titulo": "ARENA",
		"texto": "Sobrevive y llega a la meta. Ahí termina el tutorial.",
	},
]

@onready var _panel: PanelContainer = $Panel
@onready var _icono: TextureRect = $Panel/Fila/Icono
@onready var _titulo: Label = $Panel/Fila/Textos/Titulo
@onready var _texto: Label = $Panel/Fila/Textos/Texto
@onready var _mensaje: Label = $Mensaje

var _actual := -1
var _msg_tween: Tween


func _ready() -> void:
	add_to_group("tutorial_hud")
	_panel.modulate.a = 0.0
	_mensaje.modulate.a = 0.0


func mostrar_leccion(indice: int) -> void:
	if indice == _actual or indice < 0 or indice >= LECCIONES.size():
		return
	_actual = indice
	var leccion: Dictionary = LECCIONES[indice]
	_icono.texture = load(leccion.icono)
	_titulo.text = leccion.titulo
	_texto.text = leccion.texto
	_panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 1.0, 0.25)


func mensaje(texto: String) -> void:
	_mensaje.text = texto
	_mensaje.modulate.a = 1.0
	if _msg_tween != null and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.3)
	_msg_tween.tween_property(_mensaje, "modulate:a", 0.0, 0.4)
