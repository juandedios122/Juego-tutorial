// post_process.gdshader
// FIX: La sintaxis "const vec3 PALETTE[16] = { ... }" es C, no GLSL ES.
// Reemplazada por una función palette_color(int i) que devuelve
// el mismo color por índice — compatible con todos los targets de Godot 4.

shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D screen_texture : hint_screen_texture,
                                   repeat_disable,
                                   filter_nearest;

uniform float pixel_size      : hint_range(1.0, 4.0, 0.5) = 2.0;
uniform float palette_steps   : hint_range(4.0, 32.0, 1.0) = 10.0;
uniform bool  enable_palette  = true;
uniform float saturation      : hint_range(0.0, 2.0)       = 1.18;
uniform float contrast        : hint_range(0.5, 2.0)       = 1.08;
uniform float vignette_amount : hint_range(0.0, 1.0)       = 0.30;

// ── PALETA DARK FANTASY (función en lugar de array const) ─────────────────
vec3 palette_color(int i) {
	if (i ==  0) return vec3(0.039, 0.035, 0.078);  // negro-índigo
	if (i ==  1) return vec3(0.125, 0.098, 0.196);  // morado oscuro
	if (i ==  2) return vec3(0.220, 0.149, 0.318);  // violeta
	if (i ==  3) return vec3(0.110, 0.169, 0.278);  // azul medianoche
	if (i ==  4) return vec3(0.200, 0.278, 0.420);  // azul acero
	if (i ==  5) return vec3(0.349, 0.424, 0.576);  // azul grisáceo
	if (i ==  6) return vec3(0.549, 0.627, 0.745);  // azul pálido
	if (i ==  7) return vec3(0.086, 0.220, 0.149);  // verde bosque oscuro
	if (i ==  8) return vec3(0.196, 0.392, 0.235);  // verde musgo
	if (i ==  9) return vec3(0.380, 0.580, 0.318);  // verde hoja
	if (i == 10) return vec3(0.549, 0.369, 0.149);  // ocre oscuro
	if (i == 11) return vec3(0.780, 0.588, 0.220);  // dorado antorcha
	if (i == 12) return vec3(0.929, 0.816, 0.510);  // amarillo cálido
	if (i == 13) return vec3(0.600, 0.220, 0.200);  // rojo sangre
	if (i == 14) return vec3(0.750, 0.710, 0.670);  // gris piedra
	return vec3(0.980, 0.965, 0.910);                // blanco hueso (15)
}

// ── HELPERS ───────────────────────────────────────────────────────────────
vec3 ajustar_saturacion(vec3 color, float sat) {
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(luma), color, sat);
}

vec3 cuantizar_a_paleta(vec3 color) {
	float dist_min  = 1.0e9;
	vec3  resultado = color;
	for (int i = 0; i < 16; i++) {
		vec3  c   = palette_color(i);
		vec3  d   = color - c;
		float dst = dot(d, d);
		if (dst < dist_min) {
			dist_min  = dst;
			resultado = c;
		}
	}
	return resultado;
}

// ── FRAGMENT ──────────────────────────────────────────────────────────────
void fragment() {
	// 1. Pixelación
	vec2 uv = UV;
	if (pixel_size > 1.0) {
		vec2 bloque = pixel_size / vec2(textureSize(screen_texture, 0));
		uv = floor(UV / bloque) * bloque + bloque * 0.5;
	}
	vec3 col = texture(screen_texture, uv).rgb;

	// 2. Contraste y saturación
	col = (col - 0.5) * contrast + 0.5;
	col = ajustar_saturacion(col, saturation);

	// 3. Cuantización de paleta
	if (enable_palette) {
		vec3 paleta     = cuantizar_a_paleta(col);
		vec3 cuantizado = floor(col * palette_steps + 0.5) / palette_steps;
		col = mix(cuantizado, paleta, 0.70);
	}

	// 4. Viñeta
	vec2  vig_uv = UV * 2.0 - 1.0;
	float vig    = 1.0 - dot(vig_uv, vig_uv) * vignette_amount;
	col *= clamp(vig, 0.0, 1.0);

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
