class_name Sangre
extends RefCounted
## Explosión de sangre reusable: reventón de partículas + manchas que quedan en
## el suelo. Uso desde la muerte de un enemigo: `Sangre.explotar(self)`.
##
## Cada muerte lanza TRES fuentes de sangre:
##  1. nube: muchísimas gotas chicas en todas direcciones y con poco alcance
##     (el "reventón" de 360°, le da volumen).
##  2. chorro: gotas que salen en abanico hacia donde pegó el golpe y caen
##     cerca del cuerpo. La dirección sale del dash del jugador
##     (`direccion_golpe()`); si no hay golpe direccional (pinchos, etc.) el
##     chorro también sale redondo.
##  3. fuente: un surtidor que sale del cadáver hacia arriba y dura ~1 s,
##     perdiendo fuerza hasta apagarse.
## 4. Si el enemigo muere cerca del personaje, parte de la sangre se le queda
##    pegada encima (se seca y se desvanece; con muchos kills lo pinta de rojo).
## 5. Si lo mató el jugador: impact frame y manchas de sangre en la pantalla
##    que se deslizan y se desvanecen (ver sangre_pantalla.gd).
## Además la mancha del suelo deja salpicaduras en 360° y otras orientadas
## hacia el golpe, más cerca del cuerpo.
## En la nube y el chorro el frenado es mayor que la gravedad: las gotas se
## detienen donde caen en vez de esparcirse o "llover" hacia abajo. La fuente es
## la excepción a propósito: sus gotas suben y vuelven a caer.

const _COLOR_MANCHA := Color(0.32, 0.0, 0.0, 0.6)

# --- Ajustes (px, px/s, px/s², segundos) ------------------------------------
# --- Ajustes (px, px/s, px/s², segundos) ------------------------------------
# Alcance aproximado de una gota = velocidad² / (2 * frenado).
# Cada Vector2 es (mínimo, máximo).

# NUBE (El reventón circular)
const _NUBE_CANTIDAD := Vector2i(600, 800)     ## Más del doble
const _NUBE_VELOCIDAD := Vector2(100.0, 450.0) ## Sale disparada.
const _NUBE_FRENADO := Vector2(400.0, 700.0)   ## Frena en seco para dar el impacto.
const _NUBE_ESCALA := Vector2(0.4, 1.0)        ## Gotas un poco más grandes.
const _NUBE_ORIGEN := Vector2(5.0, 15.0) 

# CHORRO (hacia donde pegó el golpe, cae cerca del cuerpo)
const _CHORRO_CANTIDAD := Vector2i(700, 1000)
const _CHORRO_VELOCIDAD := Vector2(200.0, 720.0) ## Antes 300-800: ahora llega mucho menos lejos.
const _CHORRO_FRENADO := Vector2(550.0, 800.0)   ## Alcance ≈ 25 a 245 px (antes 56 a 640).
const _CHORRO_ESCALA := Vector2(0.5, 1.2)
const _CHORRO_ORIGEN := Vector2(4.0, 10.0)
const _CHORRO_ABANICO := 18.0 ## Medio cono en grados (antes 10): se lee como un abanico, no un rayo.

# FUENTE (el surtidor que se queda ~1 s saliendo del cadáver)
const _FUENTE_DURACION := 1.0                    ## Segundos que brota.
const _FUENTE_CANTIDAD := 1000                    ## Gotas vivas a la vez: súbelo para más sangre.
const _FUENTE_VELOCIDAD := Vector2(300.0, 600.0) ## Fuerza del chorro hacia arriba.
const _FUENTE_GRAVEDAD := 500.0                 ## Con qué fuerza vuelven a caer las gotas.
const _FUENTE_FRENADO := Vector2(0.0, 400.0)
const _FUENTE_ESCALA := Vector2(0.7, 1.5)
const _FUENTE_ORIGEN := Vector2(3.0, 8.0)
const _FUENTE_ABANICO := 22.0                    ## Medio cono en grados alrededor de "arriba".
const _FUENTE_VIDA := 1.1                        ## Vida de cada gota (≈ lo que tarda en subir y bajar).
const _FUENTE_FUERZA_FINAL := 0.4                ## La fuerza cae a este % al terminar el segundo.
const _FUENTE_DESFASE := Vector2.ZERO            ## Mueve el punto de salida (ej. Vector2(0, -10)).

# MANCHA DEL SUELO: salpicaduras orientadas al golpe (más cerca que las de 360°)
const _MANCHA_DIR_CANTIDAD := 200
const _MANCHA_DIR_ABANICO := 280.0 ## Medio cono en grados.
const _MANCHA_DIR_ALCANCE := 5.5  ## Hasta cuántos radios del charco llegan (las de 360° llegan a 4.5).

const _GRAVEDAD := 120.0 ## Un poco más de gravedad para que caiga con más peso.
static var _gota: Texture2D
static var _tex_rampa_ini: GradientTexture1D
static var _tex_rampa_vida: GradientTexture1D
## Zona donde GPUParticles2D sigue dibujando. Si el emisor queda fuera de
## pantalla pero las gotas no, Godot las recorta; debe cubrir el alcance máximo.
const _AREA_VISIBLE := Rect2(-800.0, -800.0, 1600.0, 1600.0)


## Revienta la sangre desde `desde`. Las manchas se cuelgan del padre del nodo
## (la sala), así que se liberan cuando se libera la sala.
## `direccion`: hacia dónde salpica el chorro (global). Si es ZERO se toma la del
## dash del jugador; si tampoco hay dash, el chorro sale en todas direcciones.
static func explotar(desde: Node2D, manchas: int = 12, direccion: Vector2 = Vector2.ZERO) -> void:
	var sala := desde.get_parent()
	if sala == null:
		return
	var pos := desde.global_position

	if direccion == Vector2.ZERO:
		direccion = _direccion_del_golpe(desde)

	for emisor in _crear_emisores(direccion):
		sala.add_child(emisor)
		emisor.global_position = pos
		emisor.emitting = true

	_arrancar_fuente(sala, pos)

	# La sangre también le cae al personaje si el enemigo murió cerca de él
	# (ver sangre_personaje.gd).
	var jugador := desde.get_tree().get_first_node_in_group(Constantes.GRUPO_PERSONAJES) as Node2D
	if jugador != null and jugador != desde:
		SangrePersonaje.salpicar(jugador, pos)
		# Impact frame + sangre en la pantalla, solo cuando mata el jugador
		# (hay dirección de golpe); no cuando muere por pinchos, etc.
		if direccion != Vector2.ZERO:
			SangrePantalla.muerte_enemigo(jugador, pos)

	if manchas > 0:
		var charco := Mancha.new()
		charco.cantidad = manchas
		charco.direccion = direccion
		sala.add_child(charco)
		charco.global_position = pos


## Hacia dónde va el golpe que mata: la dirección del dash del jugador mientras
## dashea. ZERO si no hay golpe direccional.
static func _direccion_del_golpe(desde: Node) -> Vector2:
	var arbol := desde.get_tree()
	if arbol == null:
		return Vector2.ZERO
	var jugador := arbol.get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	if jugador != null and jugador.has_method("direccion_golpe"):
		return jugador.direccion_golpe()
	return Vector2.ZERO


static func _crear_emisores(direccion: Vector2) -> Array[GPUParticles2D]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Reventón redondo: el volumen. Todo sale en el mismo instante.
	var nube := _emisor(rng, _NUBE_CANTIDAD, _NUBE_VELOCIDAD, _NUBE_FRENADO,
			_NUBE_ESCALA, _NUBE_ORIGEN)
	(nube.process_material as ParticleProcessMaterial).spread = 180.0

	# Chorro: en abanico hacia el golpe y escalonado (~0.1 s) como un latigazo.
	var chorro := _emisor(rng, _CHORRO_CANTIDAD, _CHORRO_VELOCIDAD, _CHORRO_FRENADO,
			_CHORRO_ESCALA, _CHORRO_ORIGEN)
	chorro.explosiveness = 0.85
	var mat_chorro := chorro.process_material as ParticleProcessMaterial
	if direccion == Vector2.ZERO:
		mat_chorro.spread = 180.0
	else:
		var d := direccion.normalized()
		mat_chorro.direction = Vector3(d.x, d.y, 0.0)
		mat_chorro.spread = _CHORRO_ABANICO

	return [nube, chorro]


## Surtidor que sale del cadáver ~1 s. Emite sin parar durante _FUENTE_DURACION,
## va perdiendo fuerza, se apaga y se libera solo cuando caen las últimas gotas.
static func _arrancar_fuente(sala: Node, pos: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var f := _emisor(rng, Vector2i(_FUENTE_CANTIDAD, _FUENTE_CANTIDAD), _FUENTE_VELOCIDAD,
			_FUENTE_FRENADO, _FUENTE_ESCALA, _FUENTE_ORIGEN)
	f.one_shot = false          ## emite de forma continua (no todo de golpe)
	f.explosiveness = 0.0
	f.lifetime = _FUENTE_VIDA
	var mat := f.process_material as ParticleProcessMaterial
	mat.lifetime_randomness = 0.45
	mat.direction = Vector3(0.0, -1.0, 0.0) ## arriba
	mat.spread = _FUENTE_ABANICO
	mat.gravity = Vector3(0.0, _FUENTE_GRAVEDAD, 0.0)

	sala.add_child(f)
	f.global_position = pos + _FUENTE_DESFASE
	f.emitting = true

	# Pierde fuerza durante el segundo, se apaga y se libera al caer la última gota.
	var tw := f.create_tween()
	tw.tween_property(mat, "initial_velocity_max", _FUENTE_VELOCIDAD.y * _FUENTE_FUERZA_FINAL, _FUENTE_DURACION)
	tw.parallel().tween_property(mat, "initial_velocity_min", _FUENTE_VELOCIDAD.x * _FUENTE_FUERZA_FINAL, _FUENTE_DURACION)
	tw.tween_callback(func() -> void: f.emitting = false)
	tw.tween_interval(f.lifetime + 0.2)
	tw.tween_callback(f.queue_free)


## Emisor en la GPU: la simulación (posición, velocidad, frenado, color) la
## calcula el shader de ParticleProcessMaterial, no GDScript ni la CPU.
## Nace apagado: quien lo agrega al árbol pone `emitting = true`.
static func _emisor(rng: RandomNumberGenerator, cantidad: Vector2i, velocidad: Vector2,
		frenado: Vector2, escala: Vector2, origen: Vector2) -> GPUParticles2D:
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true ## partículas 2D: sin movimiento en Z
	m.lifetime_randomness = 0.4 ## no todas desaparecen al mismo tiempo (en GPU vive en el material)
	# El origen tampoco es un punto: sale de una zona chica.
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = rng.randf_range(origen.x, origen.y)
	m.direction = Vector3(1.0, 0.0, 0.0)
	m.spread = 45.0
	m.initial_velocity_min = velocidad.x
	m.initial_velocity_max = velocidad.y
	m.gravity = Vector3(0.0, _GRAVEDAD, 0.0)
	m.damping_min = frenado.x
	m.damping_max = frenado.y
	m.scale_min = escala.x
	m.scale_max = escala.y
	m.color_initial_ramp = _rampa_inicial()
	m.color_ramp = _rampa_vida()

	var p := GPUParticles2D.new()
	p.process_material = m
	p.texture = _tex_gota()
	p.amount = rng.randi_range(cantidad.x, cantidad.y)
	p.lifetime = rng.randf_range(0.7, 1.0)
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.fixed_fps = 60
	p.visibility_rect = _AREA_VISIBLE
	p.z_index = Constantes.Z_EFECTO
	p.finished.connect(p.queue_free)
	return p


## Tono de cada gota al nacer, al azar entre oscuro y vivo: evita el "todo del
## mismo rojo" de una nube plana. Se crea una sola vez y se comparte.
static func _rampa_inicial() -> GradientTexture1D:
	if _tex_rampa_ini == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.45, 0.0, 0.02, 1.0))
		g.set_color(1, Color(0.9, 0.05, 0.04, 1.0))
		_tex_rampa_ini = GradientTexture1D.new()
		_tex_rampa_ini.gradient = g
	return _tex_rampa_ini


## Evolución de cada gota: se queda opaca (es líquido, no humo), se oscurece
## un poco y se funde solo al final. También compartida.
static func _rampa_vida() -> GradientTexture1D:
	if _tex_rampa_vida == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		g.colors = PackedColorArray([
			Color(1.0, 1.0, 1.0, 1.0),
			Color(0.75, 0.55, 0.55, 1.0),
			Color(0.55, 0.35, 0.35, 0.0),
		])
		_tex_rampa_vida = GradientTexture1D.new()
		_tex_rampa_vida.gradient = g
	return _tex_rampa_vida


## Gota redonda generada en código: las partículas sin textura son cuadrados.
## Borde duro (casi todo opaco): así se lee como líquido y no como niebla.
static func _tex_gota() -> Texture2D:
	if _gota != null:
		return _gota
	const S := 8
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var d := Vector2(x + 0.5 - S * 0.5, y + 0.5 - S * 0.5).length() / (S * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) * 2.5, 0.0, 1.0)))
	_gota = ImageTexture.create_from_image(img)
	return _gota


## Charco quieto en el suelo: un nodo que se dibuja una sola vez.
class Mancha extends Node2D:
	var cantidad := 12
	## Hacia dónde pegó el golpe (global). ZERO = sin salpicaduras direccionales.
	var direccion := Vector2.ZERO
	var _semilla := 0

	func _ready() -> void:
		z_index = Constantes.Z_DECOR_SUELO
		_semilla = randi()
		queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = _semilla
		var plano := Vector2(1.0, 0.55) ## aplasta en Y: el suelo visto en perspectiva
		var radio := rng.randf_range(26.0, 42.0)

		# Charco principal, en dos o tres círculos para que no sea un disco perfecto.
		for i in 3:
			var centro := Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-6.0, 6.0))
			draw_circle(centro * plano, radio * rng.randf_range(0.5, 1.0), _COLOR_MANCHA)

		# Salpicaduras alrededor, más lejos que el charco.
		for i in cantidad:
			var dir := Vector2.from_angle(rng.randf() * TAU) * plano
			draw_circle(dir * rng.randf_range(radio, radio * 4.5),
					rng.randf_range(2.0, 12.0), _COLOR_MANCHA)

		# Salpicaduras hacia el golpe: en abanico, más cerca del cuerpo que las de
		# 360° y más chicas mientras más lejos. Se dibujan DESPUÉS de las otras
		# para no cambiar cómo se ven las de siempre (misma semilla).
		if direccion != Vector2.ZERO:
			var base := direccion.angle()
			var alcance := radio * _MANCHA_DIR_ALCANCE
			for i in _MANCHA_DIR_CANTIDAD:
				var ang := base + deg_to_rad(rng.randf_range(-_MANCHA_DIR_ABANICO, _MANCHA_DIR_ABANICO))
				var dist := rng.randf_range(radio * 0.6, alcance)
				var tam := rng.randf_range(3.0, 11.0) * lerpf(1.0, 0.45, dist / alcance)
				draw_circle(Vector2.from_angle(ang) * dist * plano, tam, _COLOR_MANCHA)

			# Unos rastros alargados desde el charco hacia el golpe.
			for i in 3:
				var ang := base + deg_to_rad(rng.randf_range(-_MANCHA_DIR_ABANICO * 0.6, _MANCHA_DIR_ABANICO * 0.6))
				var ini := Vector2.from_angle(ang) * radio * 0.4 * plano
				var fin := Vector2.from_angle(ang) * rng.randf_range(radio * 1.0, alcance) * plano
				draw_line(ini, fin, _COLOR_MANCHA, rng.randf_range(3.0, 7.0), true)
