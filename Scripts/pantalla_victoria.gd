extends Node
## pantalla_victoria.gd — Pantalla de victoria del jugador.
## Se muestra cuando el EnemySpawner detecta que el jefe de la oleada final
## (final_wave) fue derrotado. Misma estructura que pantalla_muerte.gd para
## mantener consistencia visual, pero en tono celebratorio.

const COLOR_BG       := Color(0.02, 0.05, 0.03, 1.0)
const COLOR_BRILLO   := Color(0.20, 0.55, 0.25, 0.25)
const COLOR_PANEL_BG := Color(0.03, 0.10, 0.06, 0.97)
const COLOR_BORDE    := Color(0.35, 0.78, 0.45, 0.85)
const COLOR_TITULO   := Color(0.45, 0.95, 0.50)
const COLOR_SCORE    := Color(1.00, 0.88, 0.42)
const COLOR_RECORD   := Color(0.78, 0.92, 0.80)
const COLOR_DATO     := Color(0.80, 0.90, 0.85)
const COLOR_BTN      := Color(0.08, 0.22, 0.12)

func _ready() -> void:
	get_tree().paused = false
	_construir_ui()

func _construir_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 64
	add_child(canvas)

	var fondo := ColorRect.new()
	fondo.color = COLOR_BG
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fondo)

	var panel := Panel.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -210.0
	panel.offset_right  =  210.0
	panel.offset_top    = -200.0
	panel.offset_bottom =  200.0

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_PANEL_BG
	estilo.set_corner_radius_all(18)
	estilo.set_border_width_all(2)
	estilo.border_color = COLOR_BORDE
	panel.add_theme_stylebox_override("panel", estilo)
	canvas.add_child(panel)

	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left",   30)
	margen.add_theme_constant_override("margin_right",  30)
	margen.add_theme_constant_override("margin_top",    26)
	margen.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margen)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margen.add_child(col)

	var titulo := Label.new()
	titulo.text = "🏆  ¡VICTORIA!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color",         COLOR_TITULO)
	titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	titulo.add_theme_constant_override("outline_size", 3)
	titulo.add_theme_font_size_override("font_size", 42)
	col.add_child(titulo)

	var subt := Label.new()
	subt.text = "Derrotaste al jefe final"
	subt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subt.add_theme_color_override("font_color", COLOR_DATO)
	subt.add_theme_font_size_override("font_size", 16)
	col.add_child(subt)

	col.add_child(_separador())

	var lbl_score := Label.new()
	lbl_score.text = "Puntuación final:  %d" % Global.score
	lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_score.add_theme_color_override("font_color", COLOR_SCORE)
	lbl_score.add_theme_font_size_override("font_size", 26)
	col.add_child(lbl_score)

	var lbl_record := Label.new()
	lbl_record.text = "Récord:  %d" % Global.high_score
	lbl_record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_record.add_theme_color_override("font_color", COLOR_RECORD)
	lbl_record.add_theme_font_size_override("font_size", 18)
	col.add_child(lbl_record)

	var lbl_nivel := Label.new()
	lbl_nivel.text = "⭐  Nivel final: %d" % Global.level
	lbl_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nivel.add_theme_color_override("font_color", COLOR_DATO)
	lbl_nivel.add_theme_font_size_override("font_size", 18)
	col.add_child(lbl_nivel)

	col.add_child(_separador())

	var btn_jugar := _crear_boton("⚔  JUGAR DE NUEVO")
	btn_jugar.pressed.connect(_on_jugar_de_nuevo)
	col.add_child(btn_jugar)

	var btn_menu := _crear_boton("🏠  MENÚ PRINCIPAL")
	btn_menu.pressed.connect(_on_ir_menu)
	col.add_child(btn_menu)

	panel.modulate.a = 0.0
	panel.scale      = Vector2(0.82, 0.82)
	panel.pivot_offset = Vector2(210.0, 200.0)

	var tw := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.45)
	tw.tween_property(panel, "scale",  Vector2.ONE, 0.50)

	var tw2 := titulo.create_tween().set_loops(3)
	tw2.tween_property(titulo, "modulate:a", 0.35, 0.25)
	tw2.tween_property(titulo, "modulate:a", 1.00, 0.25)

func _separador() -> HSeparator:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 2)
	return sep

func _crear_boton(texto: String) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(0, 60)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var mk := func(c: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(10)
		s.set_border_width_all(2)
		s.border_color = COLOR_BORDE
		s.content_margin_left   = 14
		s.content_margin_right  = 14
		s.content_margin_top    = 10
		s.content_margin_bottom = 10
		return s

	btn.add_theme_stylebox_override("normal",  mk.call(COLOR_BTN))
	btn.add_theme_stylebox_override("hover",   mk.call(COLOR_BTN.lightened(0.18)))
	btn.add_theme_stylebox_override("pressed", mk.call(COLOR_BTN.lightened(0.32)))
	return btn

func _on_jugar_de_nuevo() -> void:
	Global.reiniciar_score()
	Global.reset_stats()
	Global.reset_xp_nivel()
	Global.reset_wave()
	Global.limpiar_checkpoint()
	SceneTransition.ir_a("res://Scenes/mundo.tscn")

func _on_ir_menu() -> void:
	Global.reiniciar_score()
	Global.reset_stats()
	Global.reset_xp_nivel()
	Global.reset_wave()
	Global.limpiar_checkpoint()
	SceneTransition.ir_a("res://Scenes/MainMenu.tscn")
