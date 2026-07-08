extends CharacterBody2D

var player_detected      = false
var speed                = 50.0
var player_chease        = false
var player_target        = null
var health               = 100
var max_health           = 100
var player_inattack_zone = false
var can_take_damage      = true
var is_dead              = false

# ─── Deambular cuando está idle ──────────────────────────────────────────────
var wander_timer     : float   = 0.0
var wander_direction : Vector2 = Vector2.ZERO
var is_wandering     : bool    = false

# ─── Daño de contacto al jugador ─────────────────────────────────────────────
var contact_damage          : int   = 10
var contact_damage_timer    : float = 0.0
const CONTACT_INTERVAL      : float = 1.5

# ─── Recompensas al morir ─────────────────────────────────────────────────────
const PUNTOS_AL_MORIR : int = 50
const XP_AL_MORIR     : int = 20

func enemy():
	pass

signal devolver_al_pool(enemigo: Node)

var _base_health         : int   = 100
var _base_speed          : float = 50.0
var _base_contact_damage : int   = 10

## Llamado por el EnemySpawner ANTES de add_child para escalar los stats
## del slime según la oleada actual. Cada oleada sube vida y velocidad.
func escalar_para_oleada(numero: int) -> void:
	var factor_vida  := 1.0 + (numero - 1) * 0.12   # +12% vida por oleada
	var factor_speed := 1.0 + (numero - 1) * 0.04   # +4%  velocidad por oleada
	health     = int(health     * factor_vida)
	max_health = int(max_health * factor_vida)
	speed     *= factor_speed
	# ProgressBar aún no existe (no estamos en el árbol), se actualiza en _ready()

func _ready():
	_base_health         = health
	_base_speed          = speed
	_base_contact_damage = contact_damage
	$ProgressBar.max_value = max_health
	$ProgressBar.value     = health
	$AnimatedSprite2D.play("Idle")
	Global.enemy_spawned()
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)

	wander_timer = randf_range(1.0, 4.0)

func _physics_process(delta) -> void:
	if contact_damage_timer > 0:
		contact_damage_timer -= delta

	if player_inattack_zone and contact_damage_timer <= 0 and not is_dead:
		if is_instance_valid(player_target) and player_target.has_method("receive_damage"):
			player_target.receive_damage(contact_damage)
			contact_damage_timer = CONTACT_INTERVAL

	if is_dead:
		return

	update_health_bar()

	if player_chease:
		var direction = (player_target.position - position).normalized()
		velocity = direction * speed
		move_and_slide()
		$AnimatedSprite2D.play("Walk")

		if (player_target.position.x - position.x) < 0:
			$AnimatedSprite2D.flip_h = true
		else:
			$AnimatedSprite2D.flip_h = false
	else:
		_update_wander(delta)

func _update_wander(delta: float) -> void:
	wander_timer -= delta

	if wander_timer <= 0:
		wander_timer = randf_range(2.0, 5.0)
		if randf() < 0.5:
			is_wandering     = true
			var angle        = randf() * TAU
			wander_direction = Vector2(cos(angle), sin(angle))
		else:
			is_wandering = false

	if is_wandering:
		velocity = wander_direction * (speed * 0.35)
		move_and_slide()
		$AnimatedSprite2D.play("Walk")

		if wander_direction.x < 0:
			$AnimatedSprite2D.flip_h = true
		else:
			$AnimatedSprite2D.flip_h = false
	else:
		velocity = Vector2.ZERO
		$AnimatedSprite2D.play("Idle")

func _on_detection_area_body_entered(body: Node2D) -> void:
	if not is_dead and body.has_method("player"):
		player_target = body
		player_chease = true
		is_wandering  = false

func _on_detection_area_body_exited(_body: Node2D) -> void:
	if _body.has_method("player"):
		player_detected = false
		player_target   = null
		player_chease   = false

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("player") and not is_dead:
		player_inattack_zone = true
		player_target = body

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_zone = false
		contact_damage_timer = 0.0

## Llamado por el hitbox del arma del jugador (jugador.gd) cuando un golpe
## conecta de verdad — esto es lo único que hace que el slime pierda vida.
## Ya no depende de banderas globales ni de comprobar "zona + atacando".
func reset_stats() -> void:
	health         = _base_health
	max_health     = _base_health
	speed          = _base_speed
	contact_damage = _base_contact_damage

func activar_desde_pool(pos: Vector2) -> void:
	global_position      = pos
	visible              = true
	process_mode         = Node.PROCESS_MODE_INHERIT
	is_dead              = false
	player_chease        = false
	player_detected      = false
	player_target        = null
	player_inattack_zone = false
	can_take_damage      = true
	is_wandering         = false
	wander_timer         = randf_range(1.0, 4.0)
	wander_direction     = Vector2.ZERO
	contact_damage_timer = 0.0
	velocity             = Vector2.ZERO
	$AnimatedSprite2D.modulate = Color.WHITE
	$AnimatedSprite2D.play("Idle")
	if has_node("ProgressBar"):
		$ProgressBar.visible    = true
		$ProgressBar.max_value  = max_health
		$ProgressBar.value      = health
		$ProgressBar.modulate   = Color.GREEN
	if has_node("Detection_Area"):
		$Detection_Area.set_deferred("monitoring", true)
	if has_node("Area2D"):
		$Area2D.set_deferred("monitoring", true)
	# Re-habilita el collider físico raíz que die() desactivó.
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", false)

func recibir_golpe(cantidad: int) -> void:
	if is_dead or not can_take_damage:
		return

	health -= cantidad
	can_take_damage = false
	$take_damage_cooldown.start()   # breve i-frame para no recibir 2 golpes del mismo swing

	_flash_golpe()

	if health <= 0:
		die()

func _flash_golpe() -> void:
	var tween := create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate", Color(1.6, 1.6, 1.6), 0.05)
	tween.tween_property($AnimatedSprite2D, "modulate", Color(1.0, 1.0, 1.0), 0.12)

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

func _on_animation_finished() -> void:
	var anim = $AnimatedSprite2D.animation
	if anim == "Death":
		pass

func die():
	if is_dead:
		return
	is_dead = true
	Global.enemy_died()
	Global.sumar_puntos(PUNTOS_AL_MORIR)
	Global.ganar_xp(XP_AL_MORIR)

	player_chease        = false
	player_inattack_zone = false
	is_wandering         = false

	if has_node("Detection_Area"):
		$Detection_Area.set_deferred("monitoring", false)
	if has_node("Area2D"):
		$Area2D.set_deferred("monitoring", false)

	# ── FIX CRÍTICO ────────────────────────────────────────────────────────
	# El CollisionShape2D raíz es el shape FÍSICO del CharacterBody2D (no un
	# Area2D). Antes nunca se desactivaba, así que aunque el sprite se
	# desvaneciera, el cuerpo seguía siendo un obstáculo físico sólido y el
	# Hitbox propio del jugador (jugador.gd) lo seguía detectando como
	# "cuerpo encima", infligiendo daño de contacto indefinidamente a un
	# enemigo que ya estaba "muerto". Debe desactivarse aquí, de inmediato.
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	# Ocultar la barra de vida ya: antes se quedaba visible y flotando sobre
	# un sprite invisible porque solo se desvanecía el AnimatedSprite2D.
	if has_node("ProgressBar"):
		$ProgressBar.visible = false

	velocity = Vector2.ZERO
	$AnimatedSprite2D.play("Death")

	await $AnimatedSprite2D.animation_finished

	var tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, 0.5)
	await tween.finished

	# Oculta el nodo completo (por si queda algún hijo visual adicional) y
	# detiene su procesamiento mientras espera en el pool. activar_desde_pool()
	# se encarga de revertir ambas cosas al reutilizarlo.
	visible      = false
	process_mode = Node.PROCESS_MODE_DISABLED

	devolver_al_pool.emit(self)
