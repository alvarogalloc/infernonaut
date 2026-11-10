extends Control
## HUD de viales + mejoras + llaves. Las mejoras se muestran siempre (atenuadas
## a 0) con tooltip para que el jugador descubra cómo se usan.

@onready var viales = [$Vial1, $Vial2, $Vial3]

var _escudos_restantes := -1
var _cargas_dash_sombra := -1
var _llaves := -1


func actualizar_cargas(cargas_actuales: int, porcentaje_recarga: float):
	for i in range(viales.size()):
		if i < cargas_actuales:
			viales[i].value = 100
		elif i == cargas_actuales:
			viales[i].value = porcentaje_recarga
		else:
			viales[i].value = 0


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
