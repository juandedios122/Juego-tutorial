extends Node2D

var _label_score    : Label       = null
var _label_muertes  : Label       = null
var _label_nivel    : Label       = null
var _barra_xp       : ProgressBar = null
var _label_objetivo : Label       = null
var _capa_anuncio   : CanvasLayer = null   # capa donde vive el banner de encuentro

func _ready() -> void:
	_crear_hud_score()
	_crear_hud_extra()
	_crear_hud_objetivo()
	_crear_hud_anuncio()

	if has_node("ExplorationTheme"):
		$ExplorationTheme.stop()

	Global.play_music()

	if Global.current_scene == "cliff_side":
		$Jugador.global_position = Vector2(Global.mundo_entry_x, Global.mundo_entry_y)

	Global.current_scene = "Mundo"

func _process(_delta: float) -> void:
	change_scene()

func _on_cliffside_transition_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		Global.transition_scene = true

func _on_cliffside_transition_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		Global.transition_scene = false

func change_scene():
	if Global.transition_scene == true and Global.current_scene == "Mundo":
		Global.transition_scene = false
		get_tree().change_scene_to_file("res://Scenes/cliff_side.tscn")


# ─────────────────────────────────────────────────────────────────────────────
#  HUD DE PUNTUACIÓN  (arriba a la derecha)
# ─────────────────────────────────────────────────────────────────────────────
func _crear_hud_score() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)

	_label_score = Label.new()
	_label_score.text = "⚔ 0"
	_label_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_score.add_theme_font_size_override("font_size", 22)
	_label_score.add_theme_color_override("font_color",        Color(1.0, 0.95, 0.70))
	_label_score.add_theme_color_override("font_shadow_color", Color(0.0, 0.0,  0.0, 0.85))
	_label_score.add_theme_constant_override("shadow_offset_x", 2)
	_label_score.add_theme_constant_override("shadow_offset_y", 2)
	_label_score.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label_score.offset_left   = -160.0
	_label_score.offset_top    =  12.0
	_label_score.offset_right  = -80.0    # deja espacio al botón de pausa
	_label_score.offset_bottom =  44.0
	capa.add_child(_label_score)

	Global.score_changed.connect(_on_score_changed)
	Global.reiniciar_score()


# ─────────────────────────────────────────────────────────────────────────────
#  HUD EXTRA: contador de muertes (abajo-izq) + nivel/XP (abajo-der)
# ─────────────────────────────────────────────────────────────────────────────
func _crear_hud_extra() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)

	# ── Contador de muertes (esquina inferior izquierda) ───────────────────
	_label_muertes = Label.new()
	_label_muertes.text = "💀 %d" % Global.death_count
	_label_muertes.add_theme_font_size_override("font_size", 18)
	_label_muertes.add_theme_color_override("font_color",        Color(0.75, 0.70, 0.92))
	_label_muertes.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_label_muertes.add_theme_constant_override("shadow_offset_x", 2)
	_label_muertes.add_theme_constant_override("shadow_offset_y", 2)
	_label_muertes.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label_muertes.offset_left   =  12.0
	_label_muertes.offset_top    = -40.0
	_label_muertes.offset_right  = 160.0
	_label_muertes.offset_bottom = -10.0
	_label_muertes.visible = Global.show_death_counter
	capa.add_child(_label_muertes)

	# ── Nivel (esquina inferior derecha) ───────────────────────────────────
	_label_nivel = Label.new()
	_label_nivel.text = "⭐ Nv. 1"
	_label_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_nivel.add_theme_font_size_override("font_size", 18)
	_label_nivel.add_theme_color_override("font_color",        Color(1.0, 0.88, 0.30))
	_label_nivel.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_label_nivel.add_theme_constant_override("shadow_offset_x", 2)
	_label_nivel.add_theme_constant_override("shadow_offset_y", 2)
	_label_nivel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_label_nivel.offset_left   = -160.0
	_label_nivel.offset_top    =  -58.0
	_label_nivel.offset_right  =  -12.0
	_label_nivel.offset_bottom =  -30.0
	capa.add_child(_label_nivel)

	# ── Barra de XP (justo encima del label de nivel) ─────────────────────
	_barra_xp = ProgressBar.new()
	_barra_xp.min_value = 0
	_barra_xp.max_value = Global.xp_to_next_level
	_barra_xp.value     = Global.xp
	_barra_xp.show_percentage = false
	_barra_xp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_barra_xp.offset_left   = -160.0
	_barra_xp.offset_top    =  -28.0
	_barra_xp.offset_right  =  -12.0
	_barra_xp.offset_bottom =  -10.0
	capa.add_child(_barra_xp)

	# Estilizar la barra de XP con un color dorado
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.78, 0.12)
	fill.set_corner_radius_all(4)
	_barra_xp.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.08, 0.18)
	bg.set_corner_radius_all(4)
	_barra_xp.add_theme_stylebox_override("background", bg)

	# ── Conectar señales ───────────────────────────────────────────────────
	Global.xp_gained.connect(_on_xp_gained)
	Global.death_counter_visibility_changed.connect(_on_death_counter_visibility)


# ─────────────────────────────────────────────────────────────────────────────
#  HUD DE OBJETIVO: oleada actual / oleada final  (arriba-centro)
# ─────────────────────────────────────────────────────────────────────────────
func _crear_hud_objetivo() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)

	_label_objetivo = Label.new()
	_label_objetivo.text = "Oleada 1"
	_label_objetivo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_objetivo.add_theme_font_size_override("font_size", 18)
	_label_objetivo.add_theme_color_override("font_color",        Color(0.85, 0.90, 1.0))
	_label_objetivo.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_label_objetivo.add_theme_constant_override("shadow_offset_x", 2)
	_label_objetivo.add_theme_constant_override("shadow_offset_y", 2)
	_label_objetivo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label_objetivo.offset_left   = -120.0
	_label_objetivo.offset_top    =   12.0
	_label_objetivo.offset_right  =  120.0
	_label_objetivo.offset_bottom =   42.0
	capa.add_child(_label_objetivo)

	Global.wave_changed.connect(_on_wave_changed)


# ─────────────────────────────────────────────────────────────────────────────
#  HUD DE ANUNCIO DE ENCUENTRO  (banner centro-pantalla, aparece y desaparece)
#  Escucha Global.wave_encounter_started, que el EnemySpawner emite al inicio
#  de cada oleada con el texto ("¡HORDA!", "¡ÉLITE!", etc.) y el color.
# ─────────────────────────────────────────────────────────────────────────────
func _crear_hud_anuncio() -> void:
	_capa_anuncio = CanvasLayer.new()
	_capa_anuncio.layer = 20
	add_child(_capa_anuncio)
	Global.wave_encounter_started.connect(_on_encounter_started)
	# Logros: popup cuando se desbloquea uno
	Achievements.desbloqueado.connect(_on_logro_desbloqueado)
	# Bono diario
	Global.daily_bonus_available.connect(_on_bono_diario)
	# Reclamar automáticamente el bono al entrar al mundo
	if not Global.daily_bonus_used:
		await get_tree().create_timer(2.0).timeout
		Global.reclamar_bono_diario()

@warning_ignore("unused_parameter")
func _on_logro_desbloqueado(id: String, titulo: String, icono: String) -> void:
	# Muestra el popup del logro en la esquina superior-izquierda
	var lbl := Label.new()
	lbl.text = "%s  %s" % [icono, titulo]
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	lbl.offset_left  = 12.0
	lbl.offset_top   = 95.0
	lbl.offset_right = 240.0
	lbl.offset_bottom = 120.0
	lbl.modulate.a = 0.0
	_capa_anuncio.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)

func _on_bono_diario() -> void:
	var lbl := Label.new()
	lbl.text = "🎁  ¡Bono diario! +60 XP"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.70))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_left = -160.0; lbl.offset_right = 160.0
	lbl.offset_top  =  52.0;  lbl.offset_bottom = 78.0
	lbl.modulate.a = 0.0
	_capa_anuncio.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)

func _on_encounter_started(anuncio: String, color: Color) -> void:
	# Cada anuncio crea su propio Label y lo descarta al terminar la animación,
	# así no hay estado persistente que limpiar.
	var lbl := Label.new()
	lbl.text = anuncio
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color",         color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.60))
	lbl.add_theme_constant_override("shadow_offset_x", 3)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.offset_left   = -220.0
	lbl.offset_right  =  220.0
	lbl.offset_top    =  -28.0
	lbl.offset_bottom =   28.0
	lbl.modulate.a    = 0.0
	_capa_anuncio.add_child(lbl)

	# Animación: aparece, mantiene, desaparece
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.20)
	tw.tween_property(lbl, "position:y", lbl.position.y - 18, 0.70) \
		.set_delay(0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.60)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.35)
	tw.tween_callback(lbl.queue_free)


# ─────────────────────────────────────────────────────────────────────────────
#  CALLBACKS DE SEÑALES
# ─────────────────────────────────────────────────────────────────────────────
func _on_score_changed(nuevo_score: int) -> void:
	if _label_score:
		_label_score.text = "⚔ %d" % nuevo_score

@warning_ignore("unused_parameter")
func _on_xp_gained(cantidad: int, nuevo_nivel: int, subio_nivel: bool) -> void:
	if _label_nivel:
		_label_nivel.text = "⭐ Nv. %d" % nuevo_nivel

	if _barra_xp:
		if subio_nivel:
			_barra_xp.max_value = Global.xp_to_next_level
		_barra_xp.value = Global.xp

	# Efecto de brillo rápido en el nivel si subió
	if subio_nivel and _label_nivel:
		var tw := _label_nivel.create_tween()
		tw.tween_property(_label_nivel, "modulate", Color(1.8, 1.8, 0.4), 0.12)
		tw.tween_property(_label_nivel, "modulate", Color(1.0, 1.0, 1.0), 0.30)

func _on_death_counter_visibility(es_visible: bool) -> void:
	if _label_muertes:
		_label_muertes.visible = es_visible

func _on_wave_changed(numero: int) -> void:
	if not _label_objetivo:
		return

	var spawner := get_node_or_null("EnemySpawner")
	var final_wave: int = spawner.final_wave if spawner else 10
	var intervalo : int = spawner.boss_wave_interval if spawner else 5
	var es_jefe   : bool = intervalo > 0 and numero % intervalo == 0

	if es_jefe and numero >= final_wave:
		_label_objetivo.text = "☠  ¡JEFE FINAL!  ☠"
		_label_objetivo.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
	elif es_jefe:
		_label_objetivo.text = "⚔  Oleada %d — ¡JEFE!" % numero
		_label_objetivo.add_theme_color_override("font_color", Color(1.0, 0.65, 0.30))
	else:
		_label_objetivo.text = "Oleada %d / %d" % [numero, final_wave]
		_label_objetivo.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
