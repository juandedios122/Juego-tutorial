extends CharacterBody2D

# ─── Stats ───────────────────────────────────────────────────────────────────
var speed              = 80.0
var health             = 200
var max_health         = 200
var attack_damage      = 15     # Daño que el Mushroom inflige al jugador

# ─── Estado ──────────────────────────────────────────────────────────────────
var player_detected      = false
var player_chease        = false
var player_target        = null
var player_inattack_zone = false
var can_take_damage      = true
var is_dead              = false
var is_attacking         = false
var is_stunned           = false
var is_hit               = false

var stun_chance = 0.25

# ─── Jefe de oleada ───────────────────────────────────────────────────────────
# Lo activa el EnemySpawner en la oleada final mediante convertir_en_jefe().
var es_jefe : bool = false

# ─── Recompensas al morir ─────────────────────────────────────────────────────
const PUNTOS_AL_MORIR : int = 100
const XP_AL_MORIR     : int = 35
const MULTIPLICADOR_RECOMPENSA_JEFE : int = 5

func enemy():
	pass

signal devolver_al_pool(enemigo: Node)

var _base_health        : int    = 200
var _base_attack_damage : int    = 15
var _base_speed         : float  = 80.0
var _base_sprite_scale  : Vector2 = Vector2.ONE
var _base_bar_scale     : Vector2 = Vector2.ONE

func reset_stats() -> void:
	es_jefe        = false
	health         = _base_health
	max_health     = _base_health
	attack_damage  = _base_attack_damage
	speed          = _base_speed
	$AnimatedSprite2D.scale    = _base_sprite_scale
	$AnimatedSprite2D.modulate = Color.WHITE
	$ProgressBar.scale         = _base_bar_scale

func activar_desde_pool(pos: Vector2) -> void:
	global_position      = pos
	visible              = true
	process_mode         = Node.PROCESS_MODE_INHERIT
	is_dead              = false
	is_attacking         = false
	is_stunned           = false
	is_hit               = false
	player_chease        = false
	player_detected      = false
	player_target        = null
	player_inattack_zone = false
	can_take_damage      = true
	velocity             = Vector2.ZERO
	$AnimatedSprite2D.modulate = Color.WHITE
	$AnimatedSprite2D.play("Idle")
	if has_node("ProgressBar"):
		$ProgressBar.visible   = true
		$ProgressBar.max_value = max_health
		$ProgressBar.value     = health
		$ProgressBar.modulate  = Color.GREEN
	if has_node("Detection_Area"):
		$Detection_Area.set_deferred("monitoring", true)
	if has_node("Area2D"):
		$Area2D.set_deferred("monitoring", true)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", false)

## Llamado por el EnemySpawner ANTES de add_child (antes que convertir_en_jefe).
## El spawner llama PRIMERO a escalar_para_oleada y LUEGO a convertir_en_jefe,
## así el jefe parte de stats ya escalados y se amplifica sobre ellos.
func escalar_para_oleada(numero: int) -> void:
	if es_jefe:
		# Si ya es jefe, un segundo ciclo de escalado solo ajusta velocidad
		speed *= 1.0 + (float(numero) / float(50))
		return
	var factor_vida  := 1.0 + (numero - 1) * 0.15   # +15% vida
	var factor_dano  := 1.0 + (numero - 1) * 0.08   # +8%  daño
	var factor_speed := 1.0 + (numero - 1) * 0.05   # +5%  velocidad
	health        = int(health        * factor_vida)
	max_health    = int(max_health    * factor_vida)
	attack_damage = int(attack_damage * factor_dano)
	speed        *= factor_speed


## normal en el jefe de la sesión, escalando sus stats y su tamaño visual
## (sin necesitar un sprite nuevo) y marcándolo para dar recompensa extra.
func convertir_en_jefe() -> void:
	es_jefe        = true
	max_health     = max_health * 4
	health         = max_health
	attack_damage  = int(attack_damage * 1.8)
	speed          = speed * 0.85   # un poco más lento, pero pega más fuerte

	$AnimatedSprite2D.scale   *= 1.6
	$AnimatedSprite2D.modulate = Color(1.0, 0.55, 0.55)   # tinte rojizo de "jefe"
	$ProgressBar.max_value     = max_health
	$ProgressBar.value         = health
	$ProgressBar.scale        *= 1.4

func _ready():
	_base_health        = health
	_base_attack_damage = attack_damage
	_base_speed         = speed
	_base_sprite_scale  = $AnimatedSprite2D.scale
	_base_bar_scale     = $ProgressBar.scale
	$ProgressBar.max_value = max_health
	$ProgressBar.value     = health
	$AnimatedSprite2D.play("Idle")
	Global.enemy_spawned()
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta) -> void:
	update_health_bar()

	if is_dead or is_stunned or is_hit:
		return

	if player_chease:
		if not is_attacking:
			var direction = (player_target.position - position).normalized()
			velocity = direction * speed
			move_and_slide()
			$AnimatedSprite2D.play("Run")

			if (player_target.position.x - position.x) > 0:
				$AnimatedSprite2D.flip_h = true
			else:
				$AnimatedSprite2D.flip_h = false
	else:
		if not is_attacking:
			velocity = Vector2.ZERO
			$AnimatedSprite2D.play("Idle")

func _on_detection_area_body_entered(body: Node2D) -> void:
	if not is_dead and body.has_method("player"):
		player_target = body
		player_chease = true

func _on_detection_area_body_exited(_body: Node2D) -> void:
	if _body.has_method("player"):
		player_detected = false
		player_target   = null
		player_chease   = false

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("player") and not is_dead:
		player_inattack_zone = true
		if player_target == null:
			player_target = body
		if not is_attacking and not is_stunned:
			_start_attack()

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_zone = false

func _start_attack() -> void:
	if is_dead or is_stunned or is_hit:
		return
	is_attacking = true

	if player_target:
		if (player_target.position.x - position.x) > 0:
			$AnimatedSprite2D.flip_h = true
		else:
			$AnimatedSprite2D.flip_h = false

	if randf() < 0.3:
		$AnimatedSprite2D.play("AttackWithStun")
	else:
		$AnimatedSprite2D.play("Attack")

## Llamado por el hitbox del arma del jugador cuando un golpe conecta de
## verdad. Reemplaza la comprobación antigua basada en "zona + bandera global".
func recibir_golpe(cantidad: int) -> void:
	if is_dead or not can_take_damage:
		return

	health -= cantidad
	can_take_damage = false
	$take_damage_cooldown.start()

	if health <= 0:
		die()
	else:
		_take_hit()

func _take_hit() -> void:
	if is_dead:
		return
	is_hit = true
	if randf() < stun_chance:
		is_stunned = true
		$AnimatedSprite2D.play("Stun")
	else:
		$AnimatedSprite2D.play("Hit")

func _on_animation_finished() -> void:
	var anim = $AnimatedSprite2D.animation

	if anim == "Hit":
		is_hit       = false
		is_attacking = false
		if player_chease:
			$AnimatedSprite2D.play("Run")
		else:
			$AnimatedSprite2D.play("Idle")

	elif anim == "Stun":
		is_stunned   = false
		is_hit       = false
		is_attacking = false
		if player_chease:
			$AnimatedSprite2D.play("Run")
		else:
			$AnimatedSprite2D.play("Idle")

	elif anim == "Attack":
		if player_inattack_zone and is_instance_valid(player_target) and not is_dead:
			if player_target.has_method("receive_damage"):
				player_target.receive_damage(attack_damage)

		is_attacking = false
		if player_inattack_zone and not is_dead:
			await get_tree().create_timer(0.4).timeout
			if player_inattack_zone and not is_dead and not is_stunned:
				_start_attack()
		elif player_chease:
			$AnimatedSprite2D.play("Run")
		else:
			$AnimatedSprite2D.play("Idle")

	elif anim == "AttackWithStun":
		if player_inattack_zone and is_instance_valid(player_target) and not is_dead:
			if player_target.has_method("receive_damage"):
				player_target.receive_damage(attack_damage)

		is_attacking = false
		if player_inattack_zone and not is_dead:
			await get_tree().create_timer(0.6).timeout
			if player_inattack_zone and not is_dead and not is_stunned:
				_start_attack()
		elif player_chease:
			$AnimatedSprite2D.play("Run")
		else:
			$AnimatedSprite2D.play("Idle")

	elif anim == "Die":
		pass

func _on_take_damage_cooldown_timeout():
	can_take_damage = true

func update_health_bar():
	$ProgressBar.value = health
	var percent = float(health) / float(max_health)

	if percent > 0.5:
		$ProgressBar.modulate = Color.GREEN
	elif percent > 0.25:
		$ProgressBar.modulate = Color.YELLOW
	else:
		$ProgressBar.modulate = Color.RED

func die():
	if is_dead:
		return
	is_dead = true
	Global.enemy_died()

	var multiplicador := MULTIPLICADOR_RECOMPENSA_JEFE if es_jefe else 1
	Global.sumar_puntos(PUNTOS_AL_MORIR * multiplicador)
	Global.ganar_xp(XP_AL_MORIR * multiplicador)

	player_chease        = false
	player_inattack_zone = false
	is_attacking         = false
	is_stunned           = false
	is_hit               = false

	if has_node("Detection_Area"):
		$Detection_Area.set_deferred("monitoring", false)
	if has_node("Area2D"):
		$Area2D.set_deferred("monitoring", false)

	# ── FIX CRÍTICO (idéntico al de slime.gd) ────────────────────────────
	# El CollisionShape2D raíz (shape físico del CharacterBody2D) nunca se
	# desactivaba, así que el Hitbox del jugador seguía detectando el
	# cuerpo del mushroom "muerto" como un obstáculo sólido con el que
	# colisionar, infligiendo daño de contacto indefinidamente.
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	if has_node("ProgressBar"):
		$ProgressBar.visible = false

	velocity = Vector2.ZERO
	$AnimatedSprite2D.play("Die")

	await $AnimatedSprite2D.animation_finished

	var tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, 0.5)
	await tween.finished

	visible      = false
	process_mode = Node.PROCESS_MODE_DISABLED

	devolver_al_pool.emit(self)
