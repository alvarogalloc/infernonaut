extends Control
## Parallax del menú principal.
## Hijos esperados: "Fondo" y "Personaje" (TextureRect a pantalla completa).
## Ambas capas siguen al mouse; el personaje (capa cercana) se mueve más
## que el fondo (capa lejana), y eso da la sensación de profundidad.

## Desplazamiento máximo (px) cuando el mouse está en una esquina de la pantalla.
@export var fuerza_personaje := Vector2(28.0, 16.0)
@export var fuerza_fondo := Vector2(10.0, 6.0)
## Qué tan rápido alcanzan al mouse (más alto = más pegado, más bajo = más suave).
@export var suavizado := 6.0
## Si es true las capas se mueven en sentido contrario al mouse.
@export var invertir := false

@onready var _fondo: Control = $Fondo
@onready var _personaje: Control = $Personaje

## Posición suavizada del mouse, normalizada de -1 a 1 en cada eje.
var _actual := Vector2.ZERO


func _ready() -> void:
	resized.connect(_ajustar_capas)
	_ajustar_capas.call_deferred()


## Escala las capas un poco para que, al moverse, nunca se vean los bordes
## del fondo. La escala se calcula a partir de fuerza_fondo, así que si subes
## ese valor el margen crece solo. Ambas capas usan la misma escala para que
## la silueta blanca del fondo siga coincidiendo con el dibujo del personaje.
func _ajustar_capas() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var margen := maxf(fuerza_fondo.x / size.x, fuerza_fondo.y / size.y)
	var escala := 1.0 + 2.0 * margen + 0.005
	for capa: Control in [_fondo, _personaje]:
		capa.pivot_offset = size * 0.5
		capa.scale = Vector2.ONE * escala


func _process(delta: float) -> void:
	var vp := get_viewport()
	var tam := vp.get_visible_rect().size
	if tam.x <= 0.0 or tam.y <= 0.0:
		return
	var objetivo := ((vp.get_mouse_position() / tam) * 2.0 - Vector2.ONE).clampf(-1.0, 1.0)
	if invertir:
		objetivo = -objetivo
	_actual = _actual.lerp(objetivo, 1.0 - exp(-suavizado * delta))
	_fondo.position = _actual * fuerza_fondo
	_personaje.position = _actual * fuerza_personaje
