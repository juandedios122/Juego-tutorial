## ╔══════════════════════════════════════════════════════════════════════════╗
## ║  PARCHE para jugador.gd — Nombre del jugador encima del personaje       ║
## ║                                                                          ║
## ║  Instrucciones:                                                          ║
## ║  1. Abre  Scripts/jugador.gd                                             ║
## ║  2. Busca la función  _ready()                                           ║
## ║  3. Al FINAL de _ready() (antes del closing }) agrega el bloque          ║
## ║     marcado con ✅ AGREGAR AQUI                                          ║
## ╚══════════════════════════════════════════════════════════════════════════╝

## ─── COPIA ESTE BLOQUE AL FINAL DE _ready() EN jugador.gd ──────────────────
##
##     # ── Nombre del jugador encima del sprite ──────────────────────────────
##     _crear_label_nombre()
##
## ─── Y AGREGA ESTA FUNCIÓN NUEVA en jugador.gd ──────────────────────────────

func _crear_label_nombre() -> void:
	# Crea un label en espacio de mundo que sigue al jugador
	var label := Label.new()
	label.name = "NombreJugador"

	# Texto desde el perfil global
	label.text                 = Global.player_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size  = Vector2(120, 18)

	# Posición: encima del sprite del jugador
	# Ajusta el Y si tu sprite es más alto o más bajo
	label.position = Vector2(-60, -42)

	# ── Estilo visual del nombre ───────────────────────────────────────────
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color",        Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("outline_size",    2)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))

	# ✏️ Para usar la fuente del juego (PressStart2P), descomenta:
	# var fuente := load("res://Assets/fonts/VT323-Regular.ttf") as FontFile
	# if fuente: label.add_theme_font_override("font", fuente)

	add_child(label)

	# Si el nombre cambia en tiempo de ejecución, actualiza el label:
	# label.text = Global.player_name
