extends Control

@onready var viales = [$Vial1,$Vial2,$Vial3]

func actualizar_cargas(cargas_actuales: int, porcentaje_recarga: float):
	for i in range(viales.size()):
		if i < cargas_actuales:
			# Si el índice es menor a las cargas que tenemos, está 100% llena
			viales[i].value = 100
		elif i == cargas_actuales:
			# Esta es la carga que se está rellenando en este momento
			viales[i].value = porcentaje_recarga
		else:
			# Estas son las cargas vacías que aún no empiezan a recargarse
			viales[i].value = 0
