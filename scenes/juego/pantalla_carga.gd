extends CanvasLayer
## Pantalla de carga con animación simple (barra pulsante + puntos).

@onready var _barra: ColorRect = $Barra
@onready var _texto: Label = $Texto
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var ancho := 260.0 + 420.0 * (0.5 + 0.5 * sin(_t * 3.0))
	_barra.size = Vector2(ancho, 18.0)
	_barra.position = Vector2(960.0 - ancho * 0.5, 620.0)
	var puntos := int(_t * 2.5) % 4
	_texto.text = "GENERANDO MAZMORRA" + ".".repeat(puntos)
