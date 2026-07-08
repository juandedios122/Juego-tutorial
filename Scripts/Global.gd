extends Node
## Global.gd  —  Autoload Singleton
## Accesible desde cualquier script como: Global.player_name, etc.

const SAVE_PATH := "user://perfil_jugador.cfg"

# ─────────────────────────────────────────────────────────────────────────────
#  PERFIL DEL JUGADOR
# ─────────────────────────────────────────────────────────────────────────────
var player_name           : String    = "Jugador"
var player_avatar_path    : String    = ""
var player_avatar_texture : Texture2D = null

# ─────────────────────────────────────────────────────────────────────────────
#  AJUSTES DE AUDIO
# ─────────────────────────────────────────────────────────────────────────────
var musica_volumen : float = 0.80   # 0.0 – 1.0
var sfx_volumen    : float = 1.00   # 0.0 – 1.0

# ─────────────────────────────────────────────────────────────────────────────
#  AJUSTES DE UI
# ─────────────────────────────────────────────────────────────────────────────
var ui_scale_botones   : float = 1.0
var show_death_counter : bool  = true   # Mostrar contador de muertes en HUD
var postprocess_activo : bool  = true   # Shader de post-procesado activo

# ── Persistencia para retención ───────────────────────────────────────────────
var enemies_killed_total : int    = 0        # acumulado de todas las sesiones
var last_login_date      : String = ""       # "YYYY-MM-DD" para bono diario
var daily_bonus_used     : bool   = false    # se resetea al detectar nuevo día

signal daily_bonus_available

# Posición personalizada del joystick y del botón de ataque, guardada como un
# DESPLAZAMIENTO (offset) respecto a su posición por defecto. Vector2.ZERO
# significa "sin mover, posición original". Se llena al arrastrar los
# controles en el menú de pausa → Opciones → Reposicionar controles.
var offset_joystick     : Vector2 = Vector2.ZERO
var offset_boton_ataque : Vector2 = Vector2.ZERO

func get_offset_control(nombre: String) -> Vector2:
	match nombre:
		"JoystickControl": return offset_joystick
		"BotonAtaque":     return offset_boton_ataque
		_: return Vector2.ZERO

func set_offset_control(nombre: String, offset: Vector2) -> void:
	match nombre:
		"JoystickControl": offset_joystick     = offset
		"BotonAtaque":     offset_boton_ataque = offset
	guardar_perfil()

func reset_offsets_controles() -> void:
	offset_joystick     = Vector2.ZERO
	offset_boton_ataque = Vector2.ZERO
	guardar_perfil()

# ─────────────────────────────────────────────────────────────────────────────
#  PUNTUACIÓN
# ─────────────────────────────────────────────────────────────────────────────
var score      : int = 0
var high_score : int = 0

signal score_changed(nuevo_score: int)

func sumar_puntos(cantidad: int) -> void:
	score += cantidad
	if score > high_score:
		high_score = score
		guardar_perfil()
	score_changed.emit(score)

func reiniciar_score() -> void:
	score = 0
	score_changed.emit(score)

# ─────────────────────────────────────────────────────────────────────────────
#  CONTADOR DE MUERTES  (persiste entre sesiones)
# ─────────────────────────────────────────────────────────────────────────────
var death_count : int = 0

func registrar_muerte() -> void:
	death_count += 1
	guardar_perfil()
	if has_node("/root/Achievements"):
		get_node("/root/Achievements").muerte_registrada()

# ─────────────────────────────────────────────────────────────────────────────
#  SISTEMA DE XP Y NIVEL  (se reinicia al morir / reintentar)
# ─────────────────────────────────────────────────────────────────────────────
var level            : int = 1
var xp               : int = 0
var xp_to_next_level : int = 100

## Emitido al ganar XP. subio_nivel=true si el jugador subió de nivel este tick.
signal xp_gained(cantidad: int, nuevo_nivel: int, subio_nivel: bool)

func ganar_xp(cantidad: int) -> void:
	var nivel_antes := level
	xp += cantidad
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(xp_to_next_level * 1.35)
	xp_gained.emit(cantidad, level, level > nivel_antes)

func reset_xp_nivel() -> void:
	level            = 1
	xp               = 0
	xp_to_next_level = 100

# ─────────────────────────────────────────────────────────────────────────────
#  OBJETIVO DE SESIÓN — OLEADAS Y RÉCORD DE OLEADA
#  (lo lee el EnemySpawner; el HUD se suscribe a wave_changed para mostrarlo)
# ─────────────────────────────────────────────────────────────────────────────
var current_wave : int = 0
var best_wave     : int = 0

signal wave_changed(numero: int)
## Emitida por el EnemySpawner al iniciar cada oleada.
## El HUD de mundo.gd la escucha para mostrar el anuncio de encuentro.
signal wave_encounter_started(anuncio: String, color: Color)

func set_current_wave(numero: int) -> void:
	current_wave = numero
	if numero > best_wave:
		best_wave = numero
		guardar_perfil()
	wave_changed.emit(numero)

func reset_wave() -> void:
	current_wave    = 0
	start_from_wave = 1     # el spawner siempre arranca desde el inicio al reiniciar
	wave_changed.emit(0)

# ─────────────────────────────────────────────────────────────────────────────
#  CHECKPOINT  (de sesión, no persiste al cerrar el juego)
#  El spawner llama a set_checkpoint() al terminar cada oleada de jefe.
#  La pantalla de muerte ofrece "Continuar desde Oleada X" si existe.
# ─────────────────────────────────────────────────────────────────────────────
var checkpoint_wave : int = 0   # 0 = sin checkpoint activo
var start_from_wave : int = 1   # Oleada desde la que arranca el spawner al cargar mundo

func set_checkpoint(numero: int) -> void:
	checkpoint_wave = numero

func usar_checkpoint() -> void:
	start_from_wave = checkpoint_wave
	# checkpoint_wave se conserva; si muere de nuevo puede volver al mismo punto

func limpiar_checkpoint() -> void:
	checkpoint_wave = 0
	start_from_wave = 1

# ─────────────────────────────────────────────────────────────────────────────
#  SEÑALES DE AJUSTES
# ─────────────────────────────────────────────────────────────────────────────
signal ui_scale_changed(factor: float)
signal death_counter_visibility_changed(es_visible: bool)

func set_ui_scale_botones(valor: float) -> void:
	ui_scale_botones = clampf(valor, 0.5, 2.0)
	ui_scale_changed.emit(ui_scale_botones)
	guardar_perfil()

func set_musica_volumen(valor: float) -> void:
	musica_volumen = clampf(valor, 0.0, 1.0)
	if music_player != null:
		music_player.volume_db = linear_to_db(musica_volumen)
	guardar_perfil()

func set_sfx_volumen(valor: float) -> void:
	sfx_volumen = clampf(valor, 0.0, 1.0)
	guardar_perfil()

func set_show_death_counter(valor: bool) -> void:
	show_death_counter = valor
	death_counter_visibility_changed.emit(valor)
	guardar_perfil()

# ─────────────────────────────────────────────────────────────────────────────
#  ESTADO DEL JUEGO
# ─────────────────────────────────────────────────────────────────────────────
var current_scene    : String = "Mundo"
var transition_scene : bool   = false

var mundo_entry_x : int = 168
var mundo_entry_y : int = 27
var cliff_entry_x : int = 223
var cliff_entry_y : int = 238

# ─────────────────────────────────────────────────────────────────────────────
#  CONTADORES DE ENEMIGOS
# ─────────────────────────────────────────────────────────────────────────────
var enemies_killed : int = 0
var enemies_alive  : int = 0

signal enemy_count_changed(alive: int, killed: int)

func enemy_spawned() -> void:
	enemies_alive += 1
	enemy_count_changed.emit(enemies_alive, enemies_killed)

func enemy_died() -> void:
	if enemies_alive > 0:
		enemies_alive -= 1
	enemies_killed += 1
	enemies_killed_total += 1
	enemy_count_changed.emit(enemies_alive, enemies_killed)

func reset_stats() -> void:
	enemies_killed   = 0
	enemies_alive    = 0
	transition_scene = false
	enemy_count_changed.emit(enemies_alive, enemies_killed)
	print("Estadísticas reseteadas")

# ─────────────────────────────────────────────────────────────────────────────
#  BONO DIARIO
# ─────────────────────────────────────────────────────────────────────────────
func _verificar_bono_diario() -> void:
	var hoy := Time.get_date_string_from_system()
	if hoy != last_login_date:
		last_login_date  = hoy
		daily_bonus_used = false
		guardar_perfil()
		daily_bonus_available.emit()   # mundo.gd / HUD se conecta para mostrarlo

func reclamar_bono_diario() -> void:
	if daily_bonus_used:
		return
	daily_bonus_used = true
	guardar_perfil()
	# Da XP equivalente a matar 3 slimes — pequeño pero perceptible
	ganar_xp(60)

# ─────────────────────────────────────────────────────────────────────────────
#  MÚSICA PERSISTENTE
# ─────────────────────────────────────────────────────────────────────────────
var music_player : AudioStreamPlayer = null

func _ready() -> void:
	cargar_perfil()
	_verificar_bono_diario()

	print("═════════════════════════════════════════")
	print("  SISTEMA DE JUEGO INICIALIZADO")
	print("  Jugador: ", player_name)
	print("═════════════════════════════════════════")

	music_player           = AudioStreamPlayer.new()
	music_player.name      = "MusicaGlobal"
	music_player.volume_db = linear_to_db(musica_volumen)
	add_child(music_player)

	var stream := ResourceLoader.load("res://Assets/Music/exploration_theme.mp3")
	if stream != null:
		if stream.has_method("set"):
			stream.set("loop", true)
		music_player.stream = stream
	else:
		push_warning("Global: No se pudo cargar exploration_theme.mp3")

func play_music() -> void:
	if music_player != null and not music_player.playing:
		music_player.play()

func stop_music() -> void:
	if music_player != null:
		music_player.stop()

# ─────────────────────────────────────────────────────────────────────────────
#  PERSISTENCIA DEL PERFIL
# ─────────────────────────────────────────────────────────────────────────────
func guardar_perfil() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("jugador", "nombre",              player_name)
	cfg.set_value("jugador", "avatar_path",         player_avatar_path)
	cfg.set_value("audio",   "musica",              musica_volumen)
	cfg.set_value("audio",   "sfx",                 sfx_volumen)
	cfg.set_value("ui",      "escala_botones",      ui_scale_botones)
	cfg.set_value("ui",      "show_death_counter",  show_death_counter)
	cfg.set_value("ui",      "postprocess_activo",   postprocess_activo)
	cfg.set_value("stats",   "enemies_killed_total", enemies_killed_total)
	cfg.set_value("stats",   "last_login_date",      last_login_date)
	cfg.set_value("ui",      "offset_joystick",     offset_joystick)
	cfg.set_value("ui",      "offset_boton_ataque", offset_boton_ataque)
	cfg.set_value("score",   "high_score",          high_score)
	cfg.set_value("stats",   "death_count",         death_count)
	cfg.set_value("stats",   "best_wave",           best_wave)
	var err := cfg.save(SAVE_PATH)
	if err == OK:
		print("✅ Perfil guardado: ", player_name)
	else:
		push_warning("Global: No se pudo guardar el perfil — error ", err)

func cargar_perfil() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	player_name         = cfg.get_value("jugador", "nombre",              "Jugador")
	player_avatar_path  = cfg.get_value("jugador", "avatar_path",         "")
	musica_volumen      = cfg.get_value("audio",   "musica",              0.80)
	sfx_volumen         = cfg.get_value("audio",   "sfx",                 1.00)
	ui_scale_botones    = cfg.get_value("ui",      "escala_botones",      1.0)
	show_death_counter  = cfg.get_value("ui",      "show_death_counter",  true)
	postprocess_activo  = cfg.get_value("ui",      "postprocess_activo",   true)
	enemies_killed_total = cfg.get_value("stats",   "enemies_killed_total", 0)
	last_login_date      = cfg.get_value("stats",   "last_login_date",      "")
	offset_joystick     = cfg.get_value("ui",      "offset_joystick",     Vector2.ZERO)
	offset_boton_ataque = cfg.get_value("ui",      "offset_boton_ataque", Vector2.ZERO)
	high_score          = cfg.get_value("score",   "high_score",          0)
	death_count         = cfg.get_value("stats",   "death_count",         0)
	best_wave           = cfg.get_value("stats",   "best_wave",           0)

	if player_avatar_path != "" and player_avatar_path != "dispositivo":
		if ResourceLoader.exists(player_avatar_path):
			player_avatar_texture = ResourceLoader.load(player_avatar_path) as Texture2D
	print("📂 Perfil cargado: ", player_name)
