shader_type canvas_item;
// Disolución por celdas: progress 0 = puerta entera, 1 = desaparecida.
uniform float progress : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * vec2(34.0, 34.0));
	float n = hash(cell);
	float threshold = progress * 1.15;
	float visible = step(threshold, n);
	float edge = smoothstep(threshold - 0.09, threshold, n)
			- smoothstep(threshold, threshold + 0.09, n);
	edge *= step(0.01, progress);
	COLOR.a *= visible;
	COLOR.rgb += vec3(edge) * 0.9;
}
