class_name Sfx
extends RefCounted
## Efectos de sonido sueltos (sin estado). Se llaman desde cualquier script:
##   Sfx.muerte_enemigo(self)
##   Sfx.abrir_pausa(self)
##   Sfx.seleccionar_opcion(self)
## Cada sonido se reproduce en un AudioStreamPlayer temporal colgado de la
## raíz del árbol: así no se corta si el nodo que lo pidió se libera (botón
## que reinicia o cambia de escena) y suena aunque el juego esté en pausa.

const MUERTE_ENEMIGO := [
	preload("res://assets/sfx/enemigo_muriendo1.wav"),
	preload("res://assets/sfx/enemigo_muriendo2.wav"),
]
const ABRIR_PAUSA := preload("res://assets/sfx/abrir_pausa.wav")
const SELECCIONAR_OPCION := preload("res://assets/sfx/seleccionar_opcion.wav")


## Reproduce al azar uno de los sonidos de enemigo muriendo.
static func muerte_enemigo(contexto: Node) -> void:
	_reproducir(contexto, MUERTE_ENEMIGO.pick_random())


static func abrir_pausa(contexto: Node) -> void:
	_reproducir(contexto, ABRIR_PAUSA)


static func seleccionar_opcion(contexto: Node) -> void:
	_reproducir(contexto, SELECCIONAR_OPCION)


static func _reproducir(contexto: Node, sonido: AudioStream) -> void:
	if contexto == null or not contexto.is_inside_tree():
		return
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = sonido
	reproductor.process_mode = Node.PROCESS_MODE_ALWAYS
	reproductor.autoplay = true
	reproductor.finished.connect(reproductor.queue_free)
	# Diferido: esto puede llamarse desde un callback de físicas.
	contexto.get_tree().root.add_child.call_deferred(reproductor)
