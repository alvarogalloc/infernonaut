class_name Sfx
extends RefCounted
## Efectos de sonido sueltos (sin estado). Se llaman desde cualquier script:
##   Sfx.muerte_enemigo(self)
##   Sfx.abrir_pausa(self)
##   Sfx.seleccionar_opcion(self)
##   Sfx.obtencion_escudo(self)
##   Sfx.uso_dash_sombra(self)
##   Sfx.enemigo_1_detectando(self)
## Cada sonido se reproduce en un AudioStreamPlayer temporal colgado de la
## raíz del árbol: así no se corta si el nodo que lo pidió se libera (botón
## que reinicia o cambia de escena) y suena aunque el juego esté en pausa.

const MUERTE_ENEMIGO := [
	preload("res://assets/sfx/enemigo_muriendo1.wav"),
	preload("res://assets/sfx/enemigo_muriendo2.wav"),
]
const ABRIR_PAUSA := preload("res://assets/sfx/abrir_pausa.wav")
const SELECCIONAR_OPCION := preload("res://assets/sfx/seleccionar_opcion.wav")
const OBTENCION_ESCUDO := preload("res://assets/sfx/obtencion_de_escudo.wav")
const USO_DASH_SOMBRA := preload("res://assets/sfx/uso_dash_sombra.wav")
const ENEMIGO_1_DETECTANDO := [
	preload("res://assets/sfx/enemigo_1_detectando1.mp3"),
	preload("res://assets/sfx/enemigo_1_detectando2.mp3"),
	preload("res://assets/sfx/enemigo_1_detectando3.mp3"),
]


## Reproduce al azar uno de los sonidos de enemigo muriendo.
static func muerte_enemigo(contexto: Node) -> void:
	_reproducir(contexto, MUERTE_ENEMIGO.pick_random())


static func abrir_pausa(contexto: Node) -> void:
	_reproducir(contexto, ABRIR_PAUSA)


static func seleccionar_opcion(contexto: Node) -> void:
	_reproducir(contexto, SELECCIONAR_OPCION)


static func obtencion_escudo(contexto: Node) -> void:
	_reproducir(contexto, OBTENCION_ESCUDO)


static func uso_dash_sombra(contexto: Node) -> void:
	_reproducir(contexto, USO_DASH_SOMBRA)


## Reproduce al azar uno de los sonidos de enemigo_1 detectando al jugador.
## El -8.0 es el volumen en dB (0 = original; más negativo = más bajo).
static func enemigo_1_detectando(contexto: Node) -> void:
	_reproducir(contexto, ENEMIGO_1_DETECTANDO.pick_random(), -11.0)


static func _reproducir(contexto: Node, sonido: AudioStream, volumen_db: float = 0.0) -> void:
	if contexto == null or not contexto.is_inside_tree():
		return
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = sonido
	reproductor.volume_db = volumen_db
	reproductor.process_mode = Node.PROCESS_MODE_ALWAYS
	reproductor.autoplay = true
	reproductor.finished.connect(reproductor.queue_free)
	# Diferido: esto puede llamarse desde un callback de físicas.
	contexto.get_tree().root.add_child.call_deferred(reproductor)
