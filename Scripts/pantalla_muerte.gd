extends Node
## pantalla_muerte.gd — Escena dedicada de muerte del jugador
## Se navega a ella mediante SceneTransition.ir_a() cuando el jugador muere.
## Botón REINTENTAR → recarga mundo.tscn desde cero.
## Botón MENÚ       → va al Menú Principal.

# ─── Colores ──────────────────────────────────────────────────────────────────
const COLOR_BG        := Color(0.02, 0.02, 0.08, 1.0)
const COLOR_SANGRE    := Color(0.45, 0.04, 0.04, 0.30)
const COLOR_PANEL_BG  := Color(0.04, 0.03, 0.13, 0.97)
const COLOR_BORDE     := Color(0.42, 0.28, 0.72, 0.80)
const COLOR_TITULO    := Color(0.95, 0.20, 0.20)
const COLOR_SCORE     := Color(1.00, 0.88, 0.42)
const COLOR_RECORD    := Color(0.78, 0.68, 0.92)
const COLOR_MUERTE    := Color(0.70, 0.70, 0.90)
const COLOR_NIVEL     := Color(0.55, 0.90, 0.55)
const COLOR_BTN_RETRY := Color(0.16, 0.08, 0.32)
const COLOR_BTN_MENU  := Color(0.08, 0.05, 0.18)

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	get_tree().paused = false   # por si quedó pausado de algún estado anterior
	_construir_ui()

# ─────────────────────────────────────────────────────────────────────────────
#  CONSTRUCCIÓN DE LA UI
# ─────────────────────────────────────────────────────────────────────────────
func _construir_ui() -> void:
	# ── Capa principal ─────────────────────────────────────────────────────
	var canvas := CanvasLayer.new()
	canvas.layer = 64
	add_child(canvas)

	# Fondo oscuro total
	var fondo := ColorRect.new()
	fondo.color = COLOR_BG
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fondo)

	# Manchas decorativas en las esquinas
	_agregar_manchas(canvas)

	# ── Panel central ──────────────────────────────────────────────────────
	# Calculamos el alto del panel según el contenido que hay
	var panel_alto := 360
	if Global.show_death_counter:
		panel_alto += 38
	if Global.level > 1:
		panel_alto += 38
	if Global.current_wave > 0:
		panel_alto += 38
	if Global.checkpoint_wave > 1:
		panel_alto += 68   # botón extra de checkpoint (más alto que una línea de texto)

	var panel := Panel.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -210.0
	panel.offset_right  =  210.0
	panel.offset_top    = -float(panel_alto) / 2.0
	panel.offset_bottom =  float(panel_alto) / 2.0

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_PANEL_BG
	estilo.set_corner_radius_all(18)
	estilo.set_border_width_all(2)
	estilo.border_color = COLOR_BORDE
	panel.add_theme_stylebox_override("panel", estilo)
	canvas.add_child(panel)

	# ── Contenido del panel ────────────────────────────────────────────────
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

	# ── Título ────────────────────────────────────────────────────────────
	var titulo := Label.new()
	titulo.text = "☠  HAS MUERTO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color",         COLOR_TITULO)
	titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	titulo.add_theme_constant_override("outline_size", 3)
	titulo.add_theme_font_size_override("font_size", 46)
	col.add_child(titulo)

	col.add_child(_separador())

	# ── Estadísticas ──────────────────────────────────────────────────────
	var lbl_score := Label.new()
	lbl_score.text = "Puntuación:  %d" % Global.score
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

	# Contador de muertes (controlable desde los ajustes)
	if Global.show_death_counter:
		var lbl_muertes := Label.new()
		lbl_muertes.text = "💀  Muertes: %d" % Global.death_count
		lbl_muertes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_muertes.add_theme_color_override("font_color", COLOR_MUERTE)
		lbl_muertes.add_theme_font_size_override("font_size", 18)
		col.add_child(lbl_muertes)

	# Nivel alcanzado esta partida
	if Global.level > 1:
		var lbl_nivel := Label.new()
		lbl_nivel.text = "⭐  Nivel alcanzado: %d" % Global.level
		lbl_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_nivel.add_theme_color_override("font_color", COLOR_NIVEL)
		lbl_nivel.add_theme_font_size_override("font_size", 18)
		col.add_child(lbl_nivel)

	# Oleada alcanzada (objetivo de la sesión)
	if Global.current_wave > 0:
		var lbl_oleada := Label.new()
		lbl_oleada.text = "🌊  Oleada alcanzada: %d" % Global.current_wave
		lbl_oleada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_oleada.add_theme_color_override("font_color", COLOR_NIVEL)
		lbl_oleada.add_theme_font_size_override("font_size", 18)
		col.add_child(lbl_oleada)

	col.add_child(_separador())

	# ── Botones ───────────────────────────────────────────────────────────
	# Checkpoint — solo aparece si el jugador ya superó al menos un jefe
	if Global.checkpoint_wave > 1:
		var btn_check := _crear_boton(
			"📍  Continuar desde Oleada %d" % Global.checkpoint_wave,
			Color(0.06, 0.18, 0.10))
		btn_check.pressed.connect(_on_usar_checkpoint)
		col.add_child(btn_check)

	var btn_retry := _crear_boton("↺  Reintentar desde el inicio", COLOR_BTN_RETRY)
	btn_retry.pressed.connect(_on_reintentar)
	col.add_child(btn_retry)

	var btn_menu := _crear_boton("🏠  MENÚ PRINCIPAL", COLOR_BTN_MENU)
	btn_menu.pressed.connect(_on_ir_menu)
	col.add_child(btn_menu)

	# ── Animación de entrada ──────────────────────────────────────────────
	panel.modulate.a = 0.0
	panel.scale      = Vector2(0.82, 0.82)
	panel.pivot_offset = Vector2(210.0, float(panel_alto) / 2.0)

	var tw := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.45)
	tw.tween_property(panel, "scale",  Vector2.ONE, 0.50)

	# Parpadeo del título
	var tw2 := titulo.create_tween().set_loops(3)
	tw2.tween_property(titulo, "modulate:a", 0.25, 0.22)
	tw2.tween_property(titulo, "modulate:a", 1.00, 0.22)


# ─────────────────────────────────────────────────────────────────────────────
#  HELPERS VISUALES
# ─────────────────────────────────────────────────────────────────────────────
func _separador() -> HSeparator:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 2)
	return sep


func _crear_boton(texto: String, color_bg: Color) -> Button:
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

	btn.add_theme_stylebox_override("normal",  mk.call(color_bg))
	btn.add_theme_stylebox_override("hover",   mk.call(color_bg.lightened(0.18)))
	btn.add_theme_stylebox_override("pressed", mk.call(color_bg.lightened(0.32)))
	return btn


func _agregar_manchas(canvas: CanvasLayer) -> void:
	# Manchas rojas decorativas en las cuatro esquinas
	var configs := [
		[Vector2(0.0, 0.0), Vector2(-40, -40), Vector2(200, 200)],
		[Vector2(1.0, 0.0), Vector2(-200, -40), Vector2(40, 200)],
		[Vector2(0.0, 1.0), Vector2(-40, -200), Vector2(200, 40)],
		[Vector2(1.0, 1.0), Vector2(-200, -200), Vector2(40, 40)],
	]
	for cfg_item in configs:
		var anc     : Vector2 = cfg_item[0]
		var offsets_tl : Vector2 = cfg_item[1]
		var offsets_br : Vector2 = cfg_item[2]
		var mancha := ColorRect.new()
		mancha.color = COLOR_SANGRE
		mancha.anchor_left   = anc.x
		mancha.anchor_right  = anc.x
		mancha.anchor_top    = anc.y
		mancha.anchor_bottom = anc.y
		mancha.offset_left   = offsets_tl.x
		mancha.offset_top    = offsets_tl.y
		mancha.offset_right  = offsets_br.x
		mancha.offset_bottom = offsets_br.y
		canvas.add_child(mancha)


# ─────────────────────────────────────────────────────────────────────────────
#  ACCIONES DE LOS BOTONES
# ─────────────────────────────────────────────────────────────────────────────
func _on_usar_checkpoint() -> void:
	Global.reiniciar_score()
	Global.reset_stats()
	Global.reset_xp_nivel()
	Global.usar_checkpoint()   # sets start_from_wave = checkpoint_wave
	Global.reset_wave()        # reinicia current_wave (el spawner lo rellenará)
	SceneTransition.ir_a("res://Scenes/mundo.tscn")


func _on_reintentar() -> void:
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
