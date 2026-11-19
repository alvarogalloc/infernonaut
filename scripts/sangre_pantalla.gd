class_name SangrePantalla
extends CanvasLayer
## Efecto de pantalla cuando el jugador mata a un enemigo:
##
##  1. IMPACT FRAME: un destello de ~0.12 s en blanco/negro duro (primero
##     invertido, luego en rojo y negro) con líneas de velocidad que salen de
##     donde murió el enemigo.
##  2. SANGRE EN PANTALLA: manchas de tamaños y formas al azar (manchas redondas
##     de borde ondulado y chorreadas alargadas). Aparecen sobre todo hacia
##     los bordes para no tapar el centro, se deslizan hacia abajo dejando un
##     rastro y se van desvaneciendo hasta desaparecer.
##  3. Entre más kills seguidos, más manchas por muerte y más grandes. El
##     sangrado baja solo (ENFRIADO), así que si dejas de matar se limpia.
##
## No hay que tocar escenas: `Sangre.explotar` llama a
## `SangrePantalla.muerte_enemigo(jugador, posicion)` y esta capa se crea sola
## como hija del personaje (se libera con él al reiniciar).

const _NOMBRE := "SangrePantalla"

# --- Ajustes -------------------------------------------------------------------
## Capa de dibujo: encima del mundo y del HUD de viales, debajo del HUD del
## tutorial (20), del wipe de salas (50) y de las pantallas de pausa/muerte.
const CAPA := 10

# Impact frame
## false = sin destello (por si molesta a alguien sensible a los flashes).
const IMPACT_FRAME := false
## Segundos (reales, no les afecta el hitstop) que dura el destello.
const IMPACT_DURACION := 0.12
## Brillo (0 a 1) a partir del cual un píxel cuenta como "claro" en el
## blanco/negro. Si el destello sale todo negro o todo blanco, mueve este valor.
const IMPACT_UMBRAL := 0.25
## Intensidad de las líneas de velocidad (0 = sin líneas).
const IMPACT_LINEAS := 0.8

# Sangre en pantalla
## Manchas por muerte (con 0 kills acumulados, con el sangrado al máximo).
const MANCHAS := Vector2i(3, 14)
## Tope de manchas a la vez (se borran las más viejas).
const MAX_MANCHAS := 80
## Kills seguidos (acumulados) para llegar al máximo de manchas por muerte.
const KILLS_PARA_MAXIMO := 8.0
## Cuánto baja el sangrado por segundo (0.25 = 1 kill cada 4 s).
const ENFRIADO := 0.25
## Radio de las manchas en px (mínimo, máximo). Muchas chicas, pocas grandes.
const RADIO := Vector2(14.0, 90.0)
## Segundos que dura cada mancha, de que aparece a que desaparece del todo.
const VIDA := Vector2(3.0, 5.0)
## Retraso máximo (s) con el que van apareciendo las manchas de una misma muerte.
const RETRASO_MAX := 0.12
## Deslizamiento hacia abajo: velocidad inicial (px/s) y aceleración (px/s²).
const DESLIZ_VEL := Vector2(8.0, 25.0)
const DESLIZ_ACEL := Vector2(8.0, 30.0)
## Opacidad máxima de una mancha (para que se vea a través y no impida ver).
const ALFA_MAX := 0.65
const COLOR_A := Color(0.45, 0.0, 0.02)
const COLOR_B := Color(0.80, 0.03, 0.05)

const _SOMBREADOR := """
shader_type canvas_item;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_nearest;
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;
uniform float invertir : hint_range(0.0, 1.0) = 1.0;
uniform float umbral : hint_range(0.0, 1.0) = 0.25;
uniform float lineas : hint_range(0.0, 1.0) = 0.8;
uniform vec2 centro = vec2(0.5, 0.5);
uniform vec3 tinta : source_color = vec3(0.04, 0.0, 0.0);
uniform vec3 papel : source_color = vec3(1.0, 0.94, 0.9);
uniform vec3 sangre : source_color = vec3(0.85, 0.03, 0.05);

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float luz = dot(c, vec3(0.299, 0.587, 0.114));
	// Blanco/negro duro: 1 = zona clara.
	float t = smoothstep(umbral - 0.04, umbral + 0.04, luz);
	t = mix(t, 1.0 - t, invertir);
	// Primer fotograma: blanco y negro. Segundo: rojo y negro.
	vec3 claro = mix(sangre, papel, invertir);
	vec3 col = mix(tinta, claro, t);

	// Líneas de velocidad que salen del punto del impacto.
	float aspecto = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (SCREEN_UV - centro) * vec2(aspecto, 1.0);
	float sector = floor((atan(d.y, d.x) + 3.14159265) / 6.2831853 * 56.0);
	float rayo = step(0.62, hash(sector)) * smoothstep(0.10, 0.45, length(d)) * lineas;
	col = mix(col, vec3(1.0) - col, rayo);

	COLOR = vec4(mix(c, col, fuerza), 1.0);
}
"""

var _rect: ColorRect
var _material: ShaderMaterial
var _lienzo: Lienzo
var _sangrado := 0.0
var _impacto_inicio_ms := -1


## Datos de una mancha. `edad` empieza negativa: es el retraso antes de aparecer.
class Salpicadura extends RefCounted:
	var pos := Vector2.ZERO
	var radio := 30.0
	var contorno := PackedVector2Array()
	var satelites := PackedVector3Array() ## x, y = desfase; z = radio
	var color := Color.RED
	var edad := 0.0
	var vida := 4.0
	var vel := 15.0
	var acel := 15.0

	## Cuánto ha bajado hasta ahora (px): arranca lento y se acelera un poco.
	func caida() -> float:
		var t := maxf(edad, 0.0)
		return vel * t + 0.5 * acel * t * t

	## Aparece rápido, se queda un rato y se desvanece mientras se desliza.
	func alfa() -> float:
		var entrada := clampf(edad / 0.06, 0.0, 1.0)
		var salida := 1.0 - smoothstep(vida * 0.3, vida, edad)
		return entrada * salida * ALFA_MAX


## Lienzo donde se dibujan las manchas (CanvasLayer no puede dibujar solo).
class Lienzo extends Node2D:
	var manchas: Array[Salpicadura] = []

	func agregar_tanda(cantidad: int, nivel: float) -> void:
		var tam := get_viewport_rect().size
		for i in cantidad:
			manchas.append(_nueva(tam, nivel))
		while manchas.size() > MAX_MANCHAS:
			manchas.pop_front()
		queue_redraw()

	func _nueva(tam: Vector2, nivel: float) -> Salpicadura:
		var s := Salpicadura.new()
		# Hacia los bordes (el centro casi no se mancha); algunas se salen de la pantalla.
		var ang := randf() * TAU
		var k := lerpf(0.25, 1.05, pow(randf(), 0.55))
		s.pos = tam * 0.5 + Vector2(cos(ang) * tam.x * 0.5, sin(ang) * tam.y * 0.5) * k
		s.radio = lerpf(RADIO.x, RADIO.y, pow(randf(), 2.2)) * (1.0 + nivel * 0.5)
		s.vida = randf_range(VIDA.x, VIDA.y)
		s.edad = -randf() * RETRASO_MAX
		s.vel = randf_range(DESLIZ_VEL.x, DESLIZ_VEL.y)
		s.acel = randf_range(DESLIZ_ACEL.x, DESLIZ_ACEL.y)
		s.color = COLOR_A.lerp(COLOR_B, randf())
		s.contorno = SangrePantalla._contorno_aleatorio(s.radio)
		for i in randi_range(2, 6):
			var a := randf() * TAU
			var d := s.radio * randf_range(1.2, 2.4)
			s.satelites.append(Vector3(cos(a) * d, sin(a) * d, s.radio * randf_range(0.08, 0.25)))
		return s

	func _process(delta: float) -> void:
		if manchas.is_empty():
			return
		for i in range(manchas.size() - 1, -1, -1):
			manchas[i].edad += delta
			if manchas[i].edad >= manchas[i].vida:
				manchas.remove_at(i)
		queue_redraw()

	func _draw() -> void:
		for s in manchas:
			if s.edad < 0.0:
				continue
			var a := s.alfa()
			if a <= 0.01:
				continue
			var c := s.color
			c.a = a
			var caida := s.caida()

			# Salpicaduritas sueltas: se quedan donde cayeron.
			for sat in s.satelites:
				draw_circle(s.pos + Vector2(sat.x, sat.y), sat.z, Color(c.r, c.g, c.b, a * 0.9))

			# Lo que queda en el lugar del impacto (más chico que la cabeza).
			draw_set_transform(s.pos, 0.0, Vector2(0.6, 0.6))
			draw_colored_polygon(s.contorno, Color(c.r, c.g, c.b, a * 0.9))

			# Rastro que va dejando al deslizarse, más fino hacia abajo.
			if caida > 2.0:
				var ancho := s.radio * 0.5
				draw_set_transform(s.pos, 0.0, Vector2.ONE)
				draw_colored_polygon(PackedVector2Array([
					Vector2(-ancho * 0.5, 0.0), Vector2(ancho * 0.5, 0.0),
					Vector2(ancho * 0.2, caida), Vector2(-ancho * 0.2, caida)]),
					Color(c.r, c.g, c.b, a * 0.8))

			# La gota que se desliza, con un brillito.
			draw_set_transform(s.pos + Vector2(0.0, caida), 0.0, Vector2.ONE)
			draw_colored_polygon(s.contorno, c)
			draw_circle(Vector2(-s.radio * 0.3, -s.radio * 0.3), s.radio * 0.16,
					Color(1.0, 0.6, 0.6, a * 0.35))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Punto de entrada. `desde` = posición global del enemigo que acaba de morir.
static func muerte_enemigo(jugador: Node, desde: Vector2) -> void:
	var nodo := jugador.get_node_or_null(_NOMBRE) as SangrePantalla
	if nodo == null:
		nodo = SangrePantalla.new()
		nodo.name = _NOMBRE
		jugador.add_child(nodo)
	nodo._impactar(desde)


## Silueta de mancha: borde ondulado y suave (sin picos), con forma redonda o
## alargada. Siempre es un polígono simple (sin cruces).
## Para manchas más irregulares sube AMP_*; para más redondas, bájalos.
static func _contorno_aleatorio(r: float) -> PackedVector2Array:
	const N := 28
	const AMP_2 := 0.20 ## ovalado / achatado
	const AMP_3 := 0.15 ## lóbulos grandes
	const AMP_5 := 0.10 ## ondulaciones chicas
	var a2 := randf_range(0.3, 1.0) * AMP_2
	var a3 := randf_range(0.3, 1.0) * AMP_3
	var a5 := randf_range(0.3, 1.0) * AMP_5
	var p2 := randf() * TAU
	var p3 := randf() * TAU
	var p5 := randf() * TAU
	# Una de cada tres se estira hacia abajo, como una chorreada.
	var estira := Vector2(0.75, 1.5) if randi() % 3 == 0 else Vector2.ONE
	var pts := PackedVector2Array()
	for i in N:
		var a := TAU * float(i) / float(N)
		var f := 1.0 + a2 * sin(2.0 * a + p2) + a3 * sin(3.0 * a + p3) + a5 * sin(5.0 * a + p5)
		pts.append(Vector2.from_angle(a) * r * f * estira)
	return pts


func _init() -> void:
	layer = CAPA


func _ready() -> void:
	_lienzo = Lienzo.new()
	add_child(_lienzo)

	_rect = ColorRect.new()
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false ## apagado: solo cuesta algo mientras dura el destello
	var shader := Shader.new()
	shader.code = _SOMBREADOR
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("umbral", IMPACT_UMBRAL)
	_material.set_shader_parameter("lineas", IMPACT_LINEAS)
	_rect.material = _material
	add_child(_rect)


func _process(delta: float) -> void:
	_sangrado = maxf(0.0, _sangrado - ENFRIADO * delta)

	if _impacto_inicio_ms < 0:
		return
	# Tiempo real: el hitstop (Engine.time_scale) no alarga ni acorta el destello.
	var t := (Time.get_ticks_msec() - _impacto_inicio_ms) / 1000.0
	if t >= IMPACT_DURACION:
		_impacto_inicio_ms = -1
		_rect.visible = false
		_material.set_shader_parameter("fuerza", 0.0)
		return
	var fase := t / IMPACT_DURACION
	_material.set_shader_parameter("invertir", 1.0 if fase < 0.5 else 0.0)
	_material.set_shader_parameter("fuerza", 1.0 - smoothstep(0.6, 1.0, fase))


func _impactar(desde: Vector2) -> void:
	var nivel := clampf(_sangrado / KILLS_PARA_MAXIMO, 0.0, 1.0)
	var cantidad := int(round(lerpf(MANCHAS.x, MANCHAS.y, nivel))) + randi_range(0, 2)
	_lienzo.agregar_tanda(cantidad, nivel)
	_sangrado += 1.0

	if IMPACT_FRAME:
		# Punto del impacto en coordenadas de pantalla (0 a 1) para las líneas.
		var vp := get_viewport()
		var p := vp.get_canvas_transform() * desde
		_material.set_shader_parameter("centro", p / vp.get_visible_rect().size)
		_material.set_shader_parameter("invertir", 1.0)
		_material.set_shader_parameter("fuerza", 1.0)
		_impacto_inicio_ms = Time.get_ticks_msec()
		_rect.visible = true
