extends Control
## HUD de viales + mejoras + llaves. Las mejoras se muestran siempre (atenuadas
## a 0) con tooltip para que el jugador descubra cómo se usan.
## Los viales se clonan en $Flotantes, que sigue al personaje y oscila.

@export_group("Viales flotantes")
## Píxeles de pantalla entre el origen del personaje y el centro de los viales.
@export var separacion_y := 200.0
## Amplitud del vaivén vertical, en píxeles de pantalla.
@export var amplitud := 8.0
## Velocidad del vaivén, en radianes por segundo.
@export var velocidad := 2.2

## Centro del grupo de viales flotantes.
const ANCLA := Vector2(64.0, 20.0)

@onready var viales = [$Vial1, $Vial2, $Vial3]
@onready var flotantes = $Flotantes
@onready var viales_flotantes = [$Flotantes/Vial1, $Flotantes/Vial2, $Flotantes/Vial3]

var _capa: CanvasLayer
var _personaje: Node2D
var _base_flotantes: Array[Vector2] = []
var _tiempo := 0.0
var _escudos_restantes := -1
var _cargas_dash_sombra := -1
var _llaves := -1


func _ready() -> void:
	_capa = get_parent() as CanvasLayer
	if _capa != null:
		_personaje = _capa.get_parent() as Node2D
	for v in viales_flotantes:
		_base_flotantes.append(v.position)
	_actualizar_posicion()


func _process(delta: float) -> void:
	if _personaje == null or not is_instance_valid(_personaje):
		return
	_tiempo += delta
	_actualizar_posicion()
	# Cada vial oscila con su propia fase.
	for i in range(viales_flotantes.size()):
		var fase := _tiempo * velocidad + i * TAU / viales_flotantes.size()
		viales_flotantes[i].position = _base_flotantes[i] \
				+ Vector2(0.0, sin(fase) * amplitud)


func _actualizar_posicion() -> void:
	if _personaje == null or not is_instance_valid(_personaje):
		return
	var objetivo := get_viewport().get_canvas_transform() * _personaje.global_position \
			+ Vector2(0.0, separacion_y)
	flotantes.position = get_global_transform_with_canvas().affine_inverse() * objetivo - ANCLA


func actualizar_cargas(cargas_actuales: int, porcentaje_recarga: float):
	for i in range(viales.size()):
		var valor := 0.0
		if i < cargas_actuales:
			valor = 100.0
		elif i == cargas_actuales:
			valor = porcentaje_recarga
		viales[i].value = valor
		viales_flotantes[i].value = valor


func mostrar_mejoras(escudos_restantes: int, cargas_dash_sombra: int, llaves: int):
	if _escudos_restantes == escudos_restantes \
			and _cargas_dash_sombra == cargas_dash_sombra \
			and _llaves == llaves:
		return
	_escudos_restantes = escudos_restantes
	_cargas_dash_sombra = cargas_dash_sombra
	_llaves = llaves
	_actualizar($Escudo, escudos_restantes)
	_actualizar($Sombra, cargas_dash_sombra)
	_actualizar($Llave, llaves)


func _actualizar(fila: Control, cantidad: int) -> void:
	(fila.get_node("Cantidad") as Label).text = str(cantidad)
	fila.modulate = Color.WHITE if cantidad > 0 else Color(1, 1, 1, 0.35)
