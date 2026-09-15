extends Area2D
var jugador: Node2D = null
func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("personajes"):
		jugador = body
		jugador.personaje_muerto.connect()
		
