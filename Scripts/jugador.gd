extends CharacterBody2D

@export var speed: float = 100.0

# ─── Combate del jugador ──────────────────────────────────────────────────────
# Daño que inflige cada golpe de espada que conecta de verdad con un enemigo.
@export var attack_damage: int = 20

# Cuánto dura el "candado" del golpe: desde que empieza el swing hasta que
# se puede volver a atacar. Es la MISMA duración que usa $deal_attack_timer
# (se sincronizan solos en _ready(), así que solo hace falta tocar este
# número). boton_ataque.gd usa este mismo valor para saber cuánto debe
# durar el barrido gris de "recargando" sobre el botón.
@export var attack_cooldown_time: float = 0.5

# ─── Progresión por nivel ─────────────────────────────────────────────────────
# Cada vez que subes de nivel, esto se SUMA a tus stats — el nivel deja de
# ser cosmético y se vuelve poder real, tal como pide un juego comercial.
@export var vida_extra_por_nivel  : int = 15
@export var dano_extra_por_nivel  : int = 4

@onready var joystick    = get_node("CanvasLayer/JoystickControl")
@onready var arma        = $Arma
@onready var hitbox_arma = $Arma/HitboxArma

# ── Punto de anclaje (Marker2D) para el arma ──────────────────────────────
# Arrástralo en el editor 2D (con la escena jugador.tscn abierta) hasta
# donde quieras que quede — nada de números a ciegas. El código solo lee
# su posición.
@onready var punto_mano    : Marker2D = $PuntoMano

# ─── Stats del Jugador ───────────────────────────────────────────────────────
var health           : int    = 100
var max_health       : int    = 100
var player_alive     : bool   = true
var attack_ip        : bool   = false
var current_dir      : String = "none"
var health_regen     : int    = 5
var regen_active     : bool   = true
var initial_position : Vector2 = Vector2.ZERO
var last_damage_time : float  = 0.0
var regen_delay      : float  = 5.0

# Enemigos ya golpeados durante el swing actual del arma — evita que un
# mismo golpe de espada haga daño varias veces si el cuerpo se queda
# solapado con el hitbox durante varios frames seguidos.
var _golpeados_este_swing : Array = []

# ─── Detección de enemigos cercanos ──────────────────────────────────────────
var enemy_inattack_range  : bool = false
var enemy_attack_cooldown : bool = true

# Tween del parpadeo de i-frames; guardamos la referencia para poder
# cancelarlo anticipadamente (p.ej. si el jugador muere mientras parpadea).
var _iframes_tween : Tween = null

# ─── Sistema de Corazones (HUD) ──────────────────────────────────────────────
# Cada corazón representa 1/5 de la VIDA MÁXIMA ACTUAL (no un HP fijo), para
# que el HUD se siga viendo bien aunque max_health crezca con el nivel.
const MAX_HEARTS : int = 5

var hearts_container : HBoxContainer = null
var heart_textures   : Array         = []

# ─── Arma equipada desde el inventario ───────────────────────────────────────
# Guardamos cómo era $Arma en la escena original (textura y escala) para
# poder volver a ese aspecto "por defecto" cuando el slot activo de la
# hotbar no tiene un arma equipada.
var _textura_arma_defecto : Texture2D = null
var _escala_arma_defecto  : Vector2   = Vector2.ONE

func player():
	pass

func _ready():
	initial_position = global_position
	$AnimatedSprite2D.play("Front_Idle")

	$attack_cooldown.wait_time = 1.0

	# Única fuente de verdad para cuánto dura el swing: el timer de la
	# escena queda sincronizado con la variable exportada (ver arriba).
	$deal_attack_timer.wait_time = attack_cooldown_time

	$"tiempo_regeneracion".wait_time = 2.0
	$"tiempo_regeneracion".timeout.connect(_on_regeneracion_timeout)
	$"tiempo_regeneracion".start()

	hitbox_arma.monitoring = false
	arma.z_index = 2
	_resetear_arma()

	# ── Arma equipada: el ítem del slot activo de la hotbar reemplaza la
	# textura de $Arma, que ya se anima con _animar_arma()/_resetear_arma()
	# durante los ataques — así cualquier arma que equipes se ve y se
	# mueve con las mismas animaciones de golpe.
	_textura_arma_defecto = arma.texture
	_escala_arma_defecto  = arma.scale
	Inventory.slot_activo_cambiado.connect(func(_indice): _actualizar_arma_equipada())
	Inventory.inventario_cambiado.connect(_actualizar_arma_equipada)
	_actualizar_arma_equipada()

	# ── Cargar las texturas de los corazones ────────────────────────────────
	var sheet := load("res://Assets/sprites/heart/Scaled 2x/Health_04_Heart_Red.png")

	for i in range(5):
		var atlas := AtlasTexture.new()
		atlas.atlas  = sheet
		atlas.region = Rect2(i * 32, 0, 32, 32)
		heart_textures.append(atlas)

	_crear_corazones()
	_crear_label_nombre()

	# ── Conectar señal de XP para mostrar popup ─────────────────────────────
	Global.xp_gained.connect(_on_xp_ganado)

# ─────────────────────────────────────────────────────────────────────────────
#  NOMBRE DEL JUGADOR
# ─────────────────────────────────────────────────────────────────────────────
const _TAG_FONT_SIZE := 20
const _TAG_PAD_H     := 10.0
const _TAG_PAD_V     := 3.0
const _TAG_OFFSET_Y  := -38.0

func _crear_label_nombre() -> void:
	var label := Label.new()
	label.name                 = "NombreJugador"
	label.text                 = Global.player_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size  = Vector2(20, float(_TAG_FONT_SIZE))

	var fuente := load("res://Assets/fonts/VT323-Regular.ttf") as FontFile
	if fuente:
		label.add_theme_font_override("font", fuente)
	label.add_theme_font_size_override("font_size", _TAG_FONT_SIZE)

	label.add_theme_color_override("font_color",        Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size",    4)

	$CanvasLayer.add_child(label)

func _actualizar_pos_nombre() -> void:
	var label := $CanvasLayer.get_node_or_null("NombreJugador")
	if label == null:
		return

	var cabeza_mundo := global_position + Vector2(0, _TAG_OFFSET_Y)
	var screen_pos   := get_viewport().get_canvas_transform() * cabeza_mundo

	var rendered_w : float = label.size.x
	var text_w     : float = rendered_w if rendered_w > 5.0 \
							 else float(label.text.length()) * (_TAG_FONT_SIZE * 0.55)
	var tag_w      : float = maxf(text_w, 40.0)
	var tag_h      : float = float(_TAG_FONT_SIZE) + 4.0

	label.position = Vector2(screen_pos.x - tag_w * 0.5, screen_pos.y - tag_h)
	label.size     = Vector2(tag_w, tag_h)

# ─────────────────────────────────────────────────────────────────────────────
#  HUD DE CORAZONES
# ─────────────────────────────────────────────────────────────────────────────
func _crear_corazones() -> void:
	var canvas := $CanvasLayer

	hearts_container = HBoxContainer.new()
	hearts_container.name = "HeartsContainer"
	hearts_container.add_theme_constant_override("separation", 4)

	hearts_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hearts_container.position = Vector2(10, 68)

	canvas.add_child(hearts_container)

	for i in range(MAX_HEARTS):
		var corazon := TextureRect.new()
		corazon.name                = "Heart%d" % i
		corazon.texture             = heart_textures[0]
		corazon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		corazon.custom_minimum_size = Vector2(32, 32)
		hearts_container.add_child(corazon)

	update_hearts()

func update_hearts() -> void:
	if not is_instance_valid(hearts_container):
		return

	var hp_per_heart: float = float(max_health) / float(MAX_HEARTS)
	var hp_clamped  : int   = clamp(health, 0, max_health)

	for i in range(MAX_HEARTS):
		var heart_node := hearts_container.get_child(i) as TextureRect
		if heart_node == null:
			continue

		var hp_para_este: float = clamp(hp_clamped - i * hp_per_heart, 0.0, hp_per_heart)
		var fraccion     := hp_para_este / hp_per_heart

		if fraccion >= 0.8:
			heart_node.texture = heart_textures[0]
		elif fraccion >= 0.55:
			heart_node.texture = heart_textures[1]
		elif fraccion >= 0.3:
			heart_node.texture = heart_textures[2]
		elif fraccion > 0.0:
			heart_node.texture = heart_textures[3]
		else:
			heart_node.texture = heart_textures[4]

# ─────────────────────────────────────────────────────────────────────────────
#  LOOP PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────
func _physics_process(delta):
	_actualizar_pos_nombre()
	if player_alive:
		player_movement(delta)
		enemy_attack()
		Attack()

		if health <= 0:
			player_alive = false
			health = 0
			update_hearts()
			$"tiempo_regeneracion".stop()
			await die_and_respawn()

# ─────────────────────────────────────────────────────────────────────────────
#  MOVIMIENTO Y ANIMACIONES
# ─────────────────────────────────────────────────────────────────────────────
@warning_ignore("unused_parameter")
func player_movement(delta):
	var input_vector   = Vector2.ZERO
	var using_joystick = false

	if joystick and joystick.visible and joystick.has_method("get_vector"):
		var joy_vec = joystick.get_vector()
		if joy_vec.length() > 0.15:
			input_vector   = joy_vec
			using_joystick = true

	if not using_joystick:
		input_vector.x = Input.get_axis("ui_left",  "ui_right")
		input_vector.y = Input.get_axis("ui_up",    "ui_down")

	if input_vector != Vector2.ZERO:
		velocity = input_vector.normalized() * speed

		if abs(input_vector.x) > abs(input_vector.y):
			current_dir = "right" if input_vector.x > 0 else "left"
		else:
			current_dir = "down" if input_vector.y > 0 else "up"

		play_anim(1)
	else:
		velocity = Vector2.ZERO
		play_anim(0)

	move_and_slide()

func play_anim(movement):
	var dir  = current_dir
	var anim = $AnimatedSprite2D

	if dir == "none":
		if movement == 0 and not attack_ip:
			anim.play("Front_Idle")
		return

	match dir:
		"right":
			anim.flip_h = false
			if movement == 1: anim.play("Side_Walk")
			elif not attack_ip: anim.play("Side_Idle")
		"left":
			anim.flip_h = true
			if movement == 1: anim.play("Side_Walk")
			elif not attack_ip: anim.play("Side_Idle")
		"down":
			anim.flip_h = false
			if movement == 1: anim.play("Front_Walk")
			elif not attack_ip: anim.play("Front_Idle")
		"up":
			anim.flip_h = false
			if movement == 1: anim.play("Back_Walk")
			elif not attack_ip: anim.play("Back_Idle")

# ─────────────────────────────────────────────────────────────────────────────
#  DAÑO RECIBIDO
# ─────────────────────────────────────────────────────────────────────────────
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("enemy"):
		enemy_inattack_range = true

func _on_hitbox_body_exited(body: Node2D) -> void:
	if body.has_method("enemy"):
		enemy_inattack_range = false

func enemy_attack():
	if enemy_inattack_range and enemy_attack_cooldown:
		receive_damage(10)

func receive_damage(amount: int) -> void:
	if not enemy_attack_cooldown or not player_alive:
		return

	var amount_final: int = amount

	health -= amount_final
	health  = max(0, health)

	last_damage_time      = Time.get_ticks_msec() / 1000.0
	enemy_attack_cooldown = false
	$attack_cooldown.start()

	_show_damage_number(amount_final)
	_iframes_blink()
	update_hearts()

func _on_attack_cooldown_timeout() -> void:
	enemy_attack_cooldown = true

func _show_damage_number(amount: int) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	label.add_theme_font_size_override("font_size", 16)
	label.z_index = 100
	add_child(label)
	label.position = Vector2(-12, -55)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

func _iframes_blink() -> void:
	# Cancela cualquier parpadeo previo que todavía esté corriendo
	if _iframes_tween != null and _iframes_tween.is_valid():
		_iframes_tween.kill()
		$AnimatedSprite2D.modulate = Color.WHITE

	# Duración del parpadeo = wait_time del timer de cooldown de daño
	var duracion : float = $attack_cooldown.wait_time
	var intervalo: float = 0.08   # cada cuánto alterna visible/invisible

	_iframes_tween = create_tween().set_loops(int(duracion / (intervalo * 2)))
	_iframes_tween.tween_property($AnimatedSprite2D, "modulate:a", 0.15, intervalo)
	_iframes_tween.tween_property($AnimatedSprite2D, "modulate:a", 1.00, intervalo)
	# Al terminar, garantiza que el sprite vuelve a ser completamente visible
	_iframes_tween.finished.connect(
		func(): $AnimatedSprite2D.modulate = Color.WHITE,
		CONNECT_ONE_SHOT
	)

# ─────────────────────────────────────────────────────────────────────────────
#  POPUP DE XP GANADO
# ─────────────────────────────────────────────────────────────────────────────
## Recompensa real por subir de nivel: más vida máxima, más daño, y te
## cura por completo (premio inmediato y tangible, no solo un número).
func _aplicar_recompensa_de_nivel(_nuevo_nivel: int) -> void:
	max_health += vida_extra_por_nivel
	health      = max_health
	attack_damage += dano_extra_por_nivel
	update_hearts()

func _on_xp_ganado(cantidad: int, nuevo_nivel: int, subio_nivel: bool) -> void:
	if not player_alive:
		return

	# Texto principal de XP
	var label := Label.new()
	label.text = "+%d XP" % cantidad
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.20))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 17)
	label.z_index = 100
	add_child(label)
	label.position = Vector2(-18, -70)

	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 44, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)

	# Popup de nivel si subió
	if subio_nivel:
		_aplicar_recompensa_de_nivel(nuevo_nivel)
		await get_tree().create_timer(0.30).timeout
		_mostrar_subida_nivel(nuevo_nivel)

func _mostrar_subida_nivel(nivel: int) -> void:
	var label := Label.new()
	label.text = "✦ ¡NIVEL %d!" % nivel
	label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 22)
	label.z_index = 101
	add_child(label)
	label.position = Vector2(-30, -92)
	label.modulate.a = 0.0

	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.18)
	tween.tween_property(label, "position:y", label.position.y - 55, 1.2) \
		.set_delay(0.10)
	var tw2 := label.create_tween()
	tw2.tween_interval(0.80)
	tw2.tween_property(label, "modulate:a", 0.0, 0.40)
	tw2.tween_callback(label.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  ATAQUE DEL JUGADOR + ANIMACIÓN DEL ARMA
# ─────────────────────────────────────────────────────────────────────────────
func Attack():
	if Input.is_action_just_pressed("Attack") and not attack_ip:
		attack_ip = true
		_golpeados_este_swing.clear()   # nuevo swing → lista de impactos limpia
		$deal_attack_timer.start()

		# Avisa al botón de ataque en pantalla para que se bloquee y
		# muestre el barrido de recarga mientras dura el swing.
		Global.player_attack_started.emit(attack_cooldown_time)

		var dir = current_dir

		match dir:
			"right":
				$AnimatedSprite2D.flip_h = false
				$AnimatedSprite2D.play("Side_Attack")
			"left":
				$AnimatedSprite2D.flip_h = true
				$AnimatedSprite2D.play("Side_Attack")
			"down":
				$AnimatedSprite2D.play("Front_Attack")
			"up":
				$AnimatedSprite2D.play("Back_Attack")
			_:
				$AnimatedSprite2D.play("Front_Attack")

		_animar_arma(dir)

## Devuelve el Item ARMA equipado en el slot activo, o null si no hay
## ninguno (o lo que hay no es un arma).
func _obtener_item_arma_equipada() -> Item:
	var contenido = Inventory.obtener_item_activo()
	if contenido != null and contenido["item"].tipo == Item.Tipo.ARMA:
		return contenido["item"]
	return null

## Aplica la corrección de flip del arma equipada (espejo_en_mano) sobre
## un valor "base" calculado por la coreografía del swing.
func _flip_arma_corregido(flip_base: bool) -> bool:
	var item := _obtener_item_arma_equipada()
	if item != null and item.espejo_en_mano:
		return not flip_base
	return flip_base

## Suma la corrección de rotación del arma equipada (rotacion_en_mano)
## sobre un ángulo "base" calculado por la coreografía del swing.
func _rotacion_arma_corregida(grados_base: float) -> float:
	var item := _obtener_item_arma_equipada()
	return grados_base + (item.rotacion_en_mano if item != null else 0.0)

## Suma la corrección de posición del arma equipada (offset_en_mano) sobre
## una posición "base" calculada por la coreografía del swing.
func _posicion_arma_corregida(pos_base: Vector2) -> Vector2:
	var item := _obtener_item_arma_equipada()
	return pos_base + (item.offset_en_mano if item != null else Vector2.ZERO)

func _animar_arma(dir: String) -> void:
	hitbox_arma.set_deferred("monitoring", true)

	var duracion = 0.22
	# Las 4 poses de ataque son pequeños desplazamientos RELATIVOS a
	# PuntoMano (el marcador que arrastras en el editor) — si mueves el
	# marcador, las 4 se reacomodan juntas en vez de tener que retocar
	# cada una por separado.
	var base := punto_mano.position

	match dir:
		"right":
			arma.flip_h           = _flip_arma_corregido(true)
			arma.position         = _posicion_arma_corregida(base + Vector2(2, 0))
			arma.rotation_degrees = _rotacion_arma_corregida(-70.0)
		"left":
			arma.flip_h           = _flip_arma_corregido(false)
			arma.position         = _posicion_arma_corregida(base + Vector2(-10, 0))
			arma.rotation_degrees = _rotacion_arma_corregida(70.0)
		"down":
			arma.flip_h           = _flip_arma_corregido(true)
			arma.position         = _posicion_arma_corregida(base + Vector2(0, 6))
			arma.rotation_degrees = _rotacion_arma_corregida(-30.0)
		"up":
			arma.flip_h           = _flip_arma_corregido(true)
			arma.position         = _posicion_arma_corregida(base + Vector2(0, -4))
			arma.rotation_degrees = _rotacion_arma_corregida(-150.0)
		_:
			arma.flip_h           = _flip_arma_corregido(true)
			arma.position         = _posicion_arma_corregida(base + Vector2(0, 6))
			arma.rotation_degrees = _rotacion_arma_corregida(-30.0)

	var tween = create_tween()
	match dir:
		"right":
			tween.tween_property(arma, "rotation_degrees", _rotacion_arma_corregida(80.0), duracion)
		"left":
			tween.tween_property(arma, "rotation_degrees", _rotacion_arma_corregida(-80.0), duracion)
		"down":
			tween.tween_property(arma, "rotation_degrees", _rotacion_arma_corregida(60.0), duracion)
		"up":
			tween.tween_property(arma, "rotation_degrees", _rotacion_arma_corregida(-90.0), duracion)
		_:
			tween.tween_property(arma, "rotation_degrees", _rotacion_arma_corregida(60.0), duracion)

	tween.tween_callback(_resetear_arma)

func _resetear_arma() -> void:
	hitbox_arma.set_deferred("monitoring", false)
	arma.flip_h           = _flip_arma_corregido(true)
	arma.position          = _posicion_arma_corregida(punto_mano.position)
	arma.rotation_degrees = _rotacion_arma_corregida(-45.0)

## Refleja en $Arma el ítem equipado en el slot activo de la hotbar.
## Si no hay nada equipado (o el ítem no es de tipo ARMA), vuelve al
## aspecto por defecto que ya traía la escena. Se llama al cambiar el slot
## activo y también al cambiar el inventario (por si el arma equipada se
## gasta, se suelta o se intercambia mientras está seleccionada).
## Alto aproximado (en píxeles, ya en el espacio local del personaje) al
## que se ve la espada por defecto: 32px de textura original * 0.43125 de
## escala ≈ 14px. Se usa como referencia para que CUALQUIER ícono de arma,
## sea cual sea su resolución, termine con un tamaño parecido en la mano
## — si no, una imagen de 16px con la escala vieja (pensada para 32px)
## salía la mitad de chica de lo esperado, y por eso se veía "rara" en el
## swing (las posiciones del golpe están pensadas para ese tamaño).
const ALTO_ARMA_DEFECTO_PX := 14.0

func _actualizar_arma_equipada() -> void:
	var contenido = Inventory.obtener_item_activo()

	if contenido != null and contenido["item"].tipo == Item.Tipo.ARMA and contenido["item"].icono != null:
		var item: Item = contenido["item"]
		var alto_textura: float = item.icono.get_height()
		var escala_auto: float  = ALTO_ARMA_DEFECTO_PX / alto_textura

		arma.texture = item.icono
		arma.scale   = Vector2(escala_auto, escala_auto) * item.escala_en_mano
	else:
		arma.texture = _textura_arma_defecto
		arma.scale   = _escala_arma_defecto

func _on_hitbox_arma_body_entered(body: Node2D) -> void:
	# Solo nos interesan cuerpos que sepan recibir un golpe (enemigos).
	if not body.has_method("recibir_golpe"):
		return

	# Evita que el mismo swing golpee dos veces al mismo enemigo
	# (puede pasar si el cuerpo queda solapado con el hitbox varios frames).
	if body in _golpeados_este_swing:
		return

	_golpeados_este_swing.append(body)
	body.recibir_golpe(attack_damage)

func _on_deal_attack_timer_timeout() -> void:
	$deal_attack_timer.stop()
	attack_ip = false

# ─────────────────────────────────────────────────────────────────────────────
#  REGENERACIÓN DE VIDA
# ─────────────────────────────────────────────────────────────────────────────
func _on_regeneracion_timeout():
	if not player_alive:
		return
	var elapsed = Time.get_ticks_msec() / 1000.0 - last_damage_time
	if regen_active and health < max_health and elapsed >= regen_delay:
		health = min(health + health_regen, max_health)
		update_hearts()

# ─────────────────────────────────────────────────────────────────────────────
#  MUERTE — navega a la escena PantallaMuserte
# ─────────────────────────────────────────────────────────────────────────────
func die_and_respawn() -> void:
	# Detener todo lo que pueda interferir
	$attack_cooldown.stop()
	if has_node("tiempo_regeneracion"):
		$"tiempo_regeneracion".stop()
	enemy_attack_cooldown = false

	# Cancelar el parpadeo de i-frames si estaba activo
	if _iframes_tween != null and _iframes_tween.is_valid():
		_iframes_tween.kill()

	# La última animación que estaba activa se congela en su frame actual:
	# basta con detenerla para que quede el último frame visible.
	$AnimatedSprite2D.pause()

	# ── Secuencia de muerte con tweens (funciona con cualquier sprite) ────
	# 1. Flash blanco de impacto final
	$AnimatedSprite2D.modulate = Color(2.5, 2.5, 2.5, 1.0)
	await get_tree().create_timer(0.06).timeout

	# 2. Spin + shrink + desvanecimiento simultáneos
	var tw := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property($AnimatedSprite2D, "modulate",
		Color(0.9, 0.15, 0.15, 0.0), 0.70)
	tw.tween_property($AnimatedSprite2D, "rotation_degrees",
		$AnimatedSprite2D.rotation_degrees + 360.0, 0.70)
	tw.tween_property($AnimatedSprite2D, "scale",
		Vector2(0.0, 0.0), 0.65)
	await tw.finished

	Global.registrar_muerte()
	SceneTransition.ir_a("res://Scenes/PantallaMuserte.tscn")
