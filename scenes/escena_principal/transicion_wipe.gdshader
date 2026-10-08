shader_type canvas_item;
// Directional dark wipe for room transitions.
// progreso 0 = transparent, 1 = fully covered. The dark edge sweeps
// along `direccion` (travel direction), softened by `filo` so it reads
// as a gradient darkening toward the side you are going to — not a pop.
uniform float progreso : hint_range(0.0, 1.0) = 0.0;
uniform vec2 direccion = vec2(1.0, 0.0);
uniform float filo : hint_range(0.01, 0.6) = 0.28;
uniform vec4 color_oscuridad : source_color = vec4(0.02, 0.0, 0.03, 1.0);

void fragment() {
	vec2 dir = direccion;
	if (length(dir) < 0.001) {
		dir = vec2(1.0, 0.0);
	}
	dir = normalize(dir);
	// Position along travel axis, 0 (origin side) .. 1 (destination side).
	float p = dot(UV - vec2(0.5), dir) + 0.5;
	// Dark covers the origin side first, edge sweeps toward destination.
	// progreso 0 -> borde before 0 -> transparent; 1 -> borde past 1 -> covered.
	float borde = mix(-filo, 1.0 + filo, progreso);
	float a = 1.0 - smoothstep(borde, borde + filo, p);
	COLOR = vec4(color_oscuridad.rgb, color_oscuridad.a * a);
}
