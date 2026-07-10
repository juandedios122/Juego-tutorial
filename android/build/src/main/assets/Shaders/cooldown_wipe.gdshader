// cooldown_wipe.gdshader
// Barrido de recarga del botón de ataque.
//
//   progreso = 0.0  → recién usado: TODO el botón se ve oscuro/gris.
//   progreso = 1.0  → listo: el botón se ve con su color normal.
//
// Entre medio, la parte oscura se "retira" desde abajo hacia arriba, como
// si el color original fuera subiendo para llenar el botón de nuevo.
// Se aplica directamente sobre la textura del botón (no es un overlay
// aparte), así que respeta la silueta real del ícono sin dibujar nada
// fuera de su forma.

shader_type canvas_item;

uniform float progreso : hint_range(0.0, 1.0) = 1.0;
uniform float oscurecido : hint_range(0.0, 1.0) = 0.35; // 0 = negro, 1 = sin oscurecer

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// El límite entre "oscuro" y "normal" sube (hacia UV.y = 0) a medida
	// que progreso avanza de 0.0 a 1.0.
	float limite = 1.0 - progreso;
	float factor = (UV.y < limite) ? oscurecido : 1.0;

	COLOR = vec4(tex.rgb * factor, tex.a);
}
