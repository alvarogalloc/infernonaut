extends Control

@onready var viales = [$Vial1,$Vial2,$Vial3]

var _escudos_restantes := 0
var _cargas_dash_sombra := 0

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


## Indicadores de mejora activa (escudo / dash sombra). La llama el personaje
## cada frame; solo redibuja cuando cambia el estado.
func mostrar_mejoras(escudos_restantes: int, cargas_dash_sombra: int):
	if _escudos_restantes == escudos_restantes and _cargas_dash_sombra == cargas_dash_sombra:
		return
	_escudos_restantes = escudos_restantes
	_cargas_dash_sombra = cargas_dash_sombra
	queue_redraw()


func _draw() -> void:
	if _escudos_restantes > 0:
		_dibujar_indicador(Vector2(54, 58), Color(0.95, 0.8, 0.25), _escudos_restantes)
	if _cargas_dash_sombra > 0:
		_dibujar_indicador(Vector2(54, 80), Color(0.5, 0.7, 1.0), _cargas_dash_sombra)


func _dibujar_indicador(centro: Vector2, color: Color, cantidad: int) -> void:
	draw_circle(centro, 8.0, color.darkened(0.25))
	draw_circle(centro, 5.0, color)
	var fuente := ThemeDB.fallback_font
	var texto := str(cantidad)
	var tam := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(fuente, centro - tam / 2.0 + Vector2(0, 4), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.08, 0.06, 0.1))