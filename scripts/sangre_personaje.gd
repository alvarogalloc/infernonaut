class_name SangrePersonaje
extends Node2D
## Sangre que se le pega al personaje cuando mata a un enemigo cerca.
##
## No hace falta tocar el script del personaje ni la escena: `Sangre.explotar`
## llama a `SangrePersonaje.salpicar(jugador, posicion)` y este script se crea
## solo, como hijo del AnimatedSprite2D del personaje.
##
##  - Cada muerte cercana le deja gotas encima. Se quedan unos segundos, se van
##    secando (de rojo vivo a rojo oscuro) y luego se desvanecen.
##  - Entre más cerca estaba el enemigo, más gotas.
##  - Cada kill sube el "sangrado". Con sangrado alto caen más gotas, más
##    grandes y duran más. Cuando llega a KILLS_PARA_ROJO el personaje queda
##    pintado de rojo. Si dejas de matar, el sangrado baja solo (ENFRIADO).
##  - Las gotas son hijas del sprite y (con RECORTAR_A_SILUETA) solo se ven
##    sobre el cuerpo, no flotando afuera. El tinte rojo usa un shader en el
##    material del sprite, así que NO toca `modulate` ni `self_modulate`
##    (el personaje ya los usa para la muerte, el parpadeo y el dash sombra).

const _NOMBRE := "SangrePersonaje"

# --- Ajustes (px locales del sprite, segundos) -------------------------------
## Si el enemigo muere más lejos que esto (px), la sangre no le llega.
const ALCANCE := 600.0
## Recorta las gotas a la silueta del sprite. Si algo se ve raro, ponlo en false.
const RECORTAR_A_SILUETA := true
## Gotas por muerte a máxima cercanía (mínimo, máximo).
const GOTAS := Vector2i(10, 18)
## Gotas extra por cada kill acumulado (sangrado).
const GOTAS_EXTRA_POR_KILL := 200.0
## Tope de gotas a la vez (se borran las más viejas).
const MAX_GOTAS := 600
## Segundos que se queda cada gota antes de empezar a desvanecerse (mín, máx).
const VIDA := Vector2(4.0, 7.0)
## Segundos que tarda en desvanecerse al final.
const DESVANECER := 3.0
## Tamaño de las gotas (radio mínimo, máximo).
const RADIO := Vector2(5.0, 20.0)
## Probabilidad de que una gota grande chorree hacia abajo.
const CHORREO_PROB := 0.5
## Qué parte del sprite cubren las gotas (1.0 = todo el rectángulo del frame).
const AREA := 0.85
## Kills (acumulados) para quedar pintado de rojo del todo.
const KILLS_PARA_ROJO := 12.0
## Cuánto baja el sangrado por segundo (0.05 = 1 kill cada 20 s).
const ENFRIADO := 0.05
## Qué tan rojo queda al máximo (0 a 1). Con 1.0 se pierde todo el detalle.
const COBERTURA_MAX := 0.9
const COLOR_FRESCA := Color(0.80, 0.02, 0.04)
const COLOR_SECA := Color(0.30, 0.0, 0.02)

const _SOMBREADOR := """
shader_type canvas_item;

uniform float cobertura : hint_range(0.0, 1.0) = 0.0;
uniform vec3 sangre_oscura : source_color = vec3(0.28, 0.0, 0.02);
uniform vec3 sangre_viva : source_color = vec3(0.85, 0.04, 0.05);

void fragment() {
	// Conserva el sombreado del sprite: lo claro queda rojo vivo y lo oscuro, rojo oscuro.
	float luz = clamp(dot(COLOR.rgb, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
	vec3 rojo = mix(sangre_oscura, sangre_viva, luz);
	COLOR.rgb = mix(COLOR.rgb, rojo, cobertura);
}
"""

static var _shader: Shader
static var _tex_circulo: Texture2D

var _sprite: AnimatedSprite2D
var _material: ShaderMaterial
var _gotas: Array[Gota] = []
var _sangrado := 0.0


class Gota extends RefCounted:
	var pos := Vector2.ZERO
	var radio := 8.0
	var edad := 0.0
	var vida := 5.0
	var chorreo := 0.0


## Punto de entrada. `desde` = posición global del enemigo que acaba de morir.
static func salpicar(jugador: Node2D, desde: Vector2) -> void:
	var distancia := jugador.global_position.distance_to(desde)
	if distancia > ALCANCE:
		return
	var sprite := jugador.get("animacion") as AnimatedSprite2D
	if sprite == null:
		return
	var nodo := sprite.get_node_or_null(_NOMBRE) as SangrePersonaje
	if nodo == null:
		nodo = SangrePersonaje.new()
		nodo.name = _NOMBRE
		sprite.add_child(nodo)
	nodo._agregar(desde, 1.0 - distancia / ALCANCE)


func _ready() -> void:
	_sprite = get_parent() as AnimatedSprite2D
	if _sprite == null:
		return
	# Las gotas son una textura escalada: con filtro lineal salen suaves
	# aunque el proyecto use filtro Nearest por defecto (pixel art).
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if RECORTAR_A_SILUETA:
		_sprite.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	if _sprite.material == null:
		_material = ShaderMaterial.new()
		_material.shader = _obtener_shader()
		_sprite.material = _material
	else:
		push_warning("SangrePersonaje: el sprite ya tiene un material; no se aplica el tinte rojo.")


func _process(delta: float) -> void:
	if _sangrado > 0.0:
		_sangrado = maxf(0.0, _sangrado - ENFRIADO * delta)
		_actualizar_cobertura()

	if _gotas.is_empty():
		return
	for i in range(_gotas.size() - 1, -1, -1):
		var g := _gotas[i]
		g.edad += delta
		if g.edad >= g.vida + DESVANECER:
			_gotas.remove_at(i)
	queue_redraw()


func _agregar(desde: Vector2, cercania: float) -> void:
	if _sprite == null:
		return
	var peso := lerpf(0.4, 1.0, cercania)
	var nivel := clampf(_sangrado / KILLS_PARA_ROJO, 0.0, 1.0)
	var cantidad := int(round(randi_range(GOTAS.x, GOTAS.y) * peso + _sangrado * GOTAS_EXTRA_POR_KILL))

	var rect := _rect_cuerpo()
	var centro := rect.get_center()
	var mitad := rect.size * 0.5 * AREA
	# Un poco más de sangre del lado por donde llegó la salpicadura.
	var hacia := _sprite.to_local(desde).normalized()

	for i in cantidad:
		var g := Gota.new()
		var punto := Vector2.from_angle(randf() * TAU) * sqrt(randf())
		var p := centro + punto * mitad + hacia * mitad * 0.3
		g.pos = Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
		# Muchas gotas chicas y pocas grandes; con más sangrado, más grandes.
		g.radio = lerpf(RADIO.x, RADIO.y, pow(randf(), 2.0)) * (1.0 + nivel * 0.6)
		g.vida = randf_range(VIDA.x, VIDA.y) * (1.0 + nivel)
		if g.radio > 9.0 and randf() < CHORREO_PROB:
			g.chorreo = randf_range(20.0, 70.0)
		_gotas.append(g)

	_sangrado += 1.0
	while _gotas.size() > MAX_GOTAS:
		_gotas.pop_front()
	_actualizar_cobertura()
	queue_redraw()


## Rectángulo del frame actual, en coordenadas locales del sprite.
func _rect_cuerpo() -> Rect2:
	var tam := Vector2(400.0, 400.0)
	var frames := _sprite.sprite_frames
	if frames != null and frames.has_animation(_sprite.animation):
		var tex := frames.get_frame_texture(_sprite.animation, _sprite.frame)
		if tex != null:
			tam = tex.get_size()
	var origen := _sprite.offset
	if _sprite.centered:
		origen -= tam * 0.5
	return Rect2(origen, tam)


func _actualizar_cobertura() -> void:
	if _material == null:
		return
	var nivel := clampf(_sangrado / KILLS_PARA_ROJO, 0.0, 1.0)
	_material.set_shader_parameter("cobertura", smoothstep(0.15, 1.0, nivel) * COBERTURA_MAX)


func _draw() -> void:
	for g in _gotas:
		# Se queda opaca hasta g.vida y luego se desvanece. Mientras tanto se seca.
		var alfa := 1.0
		if g.edad > g.vida:
			alfa = 1.0 - (g.edad - g.vida) / DESVANECER
		var color := COLOR_FRESCA.lerp(COLOR_SECA, clampf(g.edad / g.vida, 0.0, 1.0))
		color.a = clampf(alfa, 0.0, 1.0) * 0.92
		# Pequeño "splat": nace chica y crece en los primeros 0.08 s.
		var r := g.radio * clampf(g.edad / 0.08, 0.3, 1.0)
		_gota(g.pos, r, color)
		if g.chorreo > 0.0:
			var largo := g.chorreo * clampf(g.edad / (g.vida * 0.7), 0.0, 1.0)
			if largo > 1.0:
				var fin := g.pos + Vector2(0.0, largo)
				draw_line(g.pos, fin, color, r * 0.6)
				_gota(fin, r * 0.3, color)


## Una gota = un quad con textura (barato y se agrupa en pocos draw calls).
## draw_circle genera un polígono de muchos vértices por gota y cada frame.
func _gota(centro: Vector2, radio: float, color: Color) -> void:
	draw_texture_rect(_circulo(), Rect2(centro - Vector2(radio, radio), Vector2(radio, radio) * 2.0), false, color)


static func _circulo() -> Texture2D:
	if _tex_circulo == null:
		const S := 64
		var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
		for y in S:
			for x in S:
				var d := Vector2(x + 0.5 - S * 0.5, y + 0.5 - S * 0.5).length() / (S * 0.5)
				# Borde suave de ~1 px para que no se vea dentado.
				img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) * S * 0.5, 0.0, 1.0)))
		_tex_circulo = ImageTexture.create_from_image(img)
	return _tex_circulo


static func _obtener_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _SOMBREADOR
	return _shader
