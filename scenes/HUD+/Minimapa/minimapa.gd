extends Control
## Minimapa mínimo: salas visitadas iluminadas, pendientes oscuras.
## La geometría sale de las coordenadas gx/gy que ya calcula tutorial.gd.

const CELDA := 20.0
const HUECO := 4.0
const MARGEN := 10.0

const COLOR_OSCURA := Color(0.09, 0.08, 0.11, 0.95)
const COLOR_VISITADA := Color(0.72, 0.55, 0.24, 0.95)
const COLOR_ACTUAL := Color(1.0, 0.86, 0.48, 1.0)
const BORDE_OSCURA := Color(0.24, 0.21, 0.27, 1.0)
const BORDE_VISITADA := Color(0.95, 0.78, 0.35, 1.0)

var _celdas: Array = [] ## [{indice:int, pos:Vector2i, visitada:bool}]
var _actual := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `info` es el array de tutorial.gd; puede tener huecos (arena suelta).
func configurar(info: Array, inicial: int) -> void:
	_celdas.clear()
	for i in info.size():
		var datos = info[i]
		if datos == null:
			continue
		_celdas.append({
			"indice": i,
			"pos": Vector2i(int(datos.gx), int(datos.gy)),
			"visitada": i == inicial,
		})
	_actual = inicial
	queue_redraw()


func marcar(indice: int) -> void:
	_actual = indice
	for c in _celdas:
		if c["indice"] == indice:
			c["visitada"] = true
	queue_redraw()


func _draw() -> void:
	if _celdas.is_empty():
		return
	var min_x: int = 999999
	var min_y: int = 999999
	var max_x: int = -999999
	var max_y: int = -999999
	for c in _celdas:
		var p: Vector2i = c["pos"]
		if p.x < min_x:
			min_x = p.x
		if p.x > max_x:
			max_x = p.x
		if p.y < min_y:
			min_y = p.y
		if p.y > max_y:
			max_y = p.y
	var columnas := max_x - min_x + 1
	var filas := max_y - min_y + 1
	var celda := CELDA
	var disp_x := size.x - 2.0 * MARGEN - 12.0
	var disp_y := size.y - 2.0 * MARGEN - 12.0
	celda = minf(celda, (disp_x - (columnas - 1) * HUECO) / columnas)
	celda = minf(celda, (disp_y - (filas - 1) * HUECO) / filas)
	celda = maxf(celda, 6.0)
	var ancho: float = float(columnas) * (celda + HUECO) - HUECO
	var alto: float = float(filas) * (celda + HUECO) - HUECO
	var origen := Vector2(size.x - MARGEN - ancho, MARGEN)
	draw_rect(Rect2(origen - Vector2(6, 6), Vector2(ancho + 12, alto + 12)),
			Color(0.02, 0.015, 0.025, 0.55), true)
	for c in _celdas:
		var p: Vector2i = c["pos"]
		var r := Rect2(origen + Vector2(
			(p.x - min_x) * (celda + HUECO),
			(p.y - min_y) * (celda + HUECO)
		), Vector2(celda, celda))
		var visitada: bool = c["visitada"]
		var actual: bool = c["indice"] == _actual
		var relleno := COLOR_ACTUAL if actual else (COLOR_VISITADA if visitada else COLOR_OSCURA)
		var borde := Color.WHITE if actual else (BORDE_VISITADA if visitada else BORDE_OSCURA)
		draw_rect(r, relleno, true)
		draw_rect(r, borde, false, 2.0)
