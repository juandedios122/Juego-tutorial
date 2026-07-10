extends Node
## SFX.gd  —  Autoload Singleton
## Sistema de efectos de sonido 100% procedural: genera todas las muestras
## de audio en código sin necesitar archivos .wav ni .ogg.
## Usa AudioStreamWAV con datos PCM de 16 bits generados en _ready().
##
## Añadir al Autoload:  Nombre "SFX"  Ruta "res://Scripts/SFX.gd"
##
## Uso desde cualquier script:
##   SFX.play("attack")       # swing de espada
##   SFX.play("hit")          # impacto en enemigo
##   SFX.play("player_hit")   # jugador recibe daño
##   SFX.play("enemy_death")  # muerte de enemigo normal
##   SFX.play("boss_death")   # muerte de jefe
##   SFX.play("xp")           # ganancia de XP
##   SFX.play("level_up")     # subida de nivel (chime)
##   SFX.play("ui_click")     # botón de UI
##   SFX.play("inventory_open")   # abrir inventario
##   SFX.play("inventory_close")  # cerrar inventario
##   SFX.play("pickup")           # recoger objeto del suelo
##   SFX.play("potion_drink")     # consumir poción
##   SFX.play("walk")             # paso al caminar (se llama en bucle)
##   SFX.play("break_object")     # romper árbol/arbusto/objeto destructible
##   SFX.play("door_open")        # abrir puerta
##   SFX.play("door_close")       # cerrar puerta
##   SFX.play("npc_talk")         # iniciar diálogo con NPC
##   SFX.play("chest_open")       # abrir cofre

const SAMPLE_RATE := 22050

var _streams   : Dictionary = {}   # nombre → AudioStreamWAV
var _players   : Array      = []   # pool de AudioStreamPlayer
var _pool_size : int        = 8

# ─────────────────────────────────────────────────────────────────────────────
#  INIT
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_generar_todos_los_sonidos()
	_crear_pool()
	print("✅ SFX iniciado — %d sonidos generados" % _streams.size())

func _crear_pool() -> void:
	for i in range(_pool_size):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

# ─────────────────────────────────────────────────────────────────────────────
#  API PÚBLICA
# ─────────────────────────────────────────────────────────────────────────────
func play(nombre: String, vol_db: float = 0.0) -> void:
	if not Global.sfx_volumen > 0.0:
		return
	var stream := _streams.get(nombre) as AudioStreamWAV
	if stream == null:
		push_warning("SFX: sonido desconocido '%s'" % nombre)
		return

	# Buscar un player libre en el pool
	for p in _players:
		if not p.playing:
			p.stream    = stream
			p.volume_db = vol_db + linear_to_db(Global.sfx_volumen)
			p.play()
			return

	# Si todos están ocupados, robar el primero (el más viejo)
	var p : AudioStreamPlayer = _players[0]
	p.stream    = stream
	p.volume_db = vol_db + linear_to_db(Global.sfx_volumen)
	p.play()


# ─────────────────────────────────────────────────────────────────────────────
#  SÍNTESIS — helpers de generación de muestras PCM
# ─────────────────────────────────────────────────────────────────────────────
static func _wav(samples: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.data     = samples
	s.format   = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SAMPLE_RATE
	s.stereo   = false
	return s

## Convierte un float −1..1 a dos bytes little-endian de 16-bit.
static func _s16(val: float, buf: PackedByteArray, idx: int) -> void:
	var v := int(clamp(val, -1.0, 1.0) * 32767.0)
	buf[idx]     = v & 0xFF
	buf[idx + 1] = (v >> 8) & 0xFF

## Ruido blanco con envolvente exponencial.
static func _ruido(duracion: float, decay: float, amp: float = 1.0) -> PackedByteArray:
	var n   := int(SAMPLE_RATE * duracion)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	for i in range(n):
		var t    := float(i) / SAMPLE_RATE
		var env  := exp(-t * decay) * amp
		_s16(randf_range(-1.0, 1.0) * env, buf, i * 2)
	return buf

## Onda sinusoidal con envolvente exponencial.
static func _sine(freq: float, duracion: float, decay: float, amp: float = 1.0) -> PackedByteArray:
	var n   := int(SAMPLE_RATE * duracion)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	for i in range(n):
		var t   := float(i) / SAMPLE_RATE
		var env := exp(-t * decay) * amp
		_s16(sin(TAU * freq * t) * env, buf, i * 2)
	return buf

## Mezcla dos buffers de la misma longitud (los trunca al más corto).
static func _mezclar(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var n   := mini(a.size(), b.size())
	var buf := PackedByteArray()
	buf.resize(n)
	var i := 0
	while i < n - 1:
		var va := float(a[i] | (a[i+1] << 8))
		var vb := float(b[i] | (b[i+1] << 8))
		# Convertir unsigned a signed
		if va > 32767: va -= 65536
		if vb > 32767: vb -= 65536
		var mix = clamp((va + vb) / 32767.0, -1.0, 1.0)
		_s16(mix, buf, i)
		i += 2
	return buf

## Concatena varios buffers en secuencia (para acordes / arpegios).
static func _concatenar(partes: Array) -> PackedByteArray:
	var total := 0
	for p in partes:
		total += (p as PackedByteArray).size()
	var buf := PackedByteArray()
	buf.resize(total)
	var idx := 0
	for p in partes:
		for b in (p as PackedByteArray):
			buf[idx] = b
			idx += 1
	return buf


# ─────────────────────────────────────────────────────────────────────────────
#  DEFINICIONES DE SONIDOS
# ─────────────────────────────────────────────────────────────────────────────
func _generar_todos_los_sonidos() -> void:

	# ── Swing de espada — ruido corto de alta frecuencia + sibilancia ───────
	var ruido_swing := _ruido(0.10, 28.0, 0.75)
	var silbido     := _sine(1800.0, 0.10, 22.0, 0.40)
	_streams["attack"] = _wav(_mezclar(ruido_swing, silbido))

	# ── Impacto en enemigo — thump + crepitar ───────────────────────────────
	var thump  := _sine(120.0, 0.14, 35.0, 0.90)
	var crujido := _ruido(0.12, 25.0, 0.55)
	_streams["hit"] = _wav(_mezclar(thump, crujido))

	# ── Jugador recibe daño — más grave y pronunciado que "hit" ─────────────
	var golpe_grave := _sine(80.0, 0.18, 20.0, 1.0)
	var ruido_daño  := _ruido(0.16, 18.0, 0.65)
	_streams["player_hit"] = _wav(_mezclar(golpe_grave, ruido_daño))

	# ── Muerte de enemigo normal — pop corto ─────────────────────────────────
	var pop      := _sine(350.0, 0.04, 80.0, 1.0)   # frecuencia alta, muy corto
	var pop_tail := _ruido(0.12, 30.0, 0.50)
	_streams["enemy_death"] = _wav(_mezclar(pop, pop_tail))

	# ── Muerte de jefe — explosión grave ─────────────────────────────────────
	var boom    := _sine(55.0, 0.30, 12.0, 1.0)
	var estall  := _ruido(0.30, 10.0, 0.85)
	var sust    := _sine(200.0, 0.20, 25.0, 0.45)
	var boss_b  := _mezclar(boom, estall)
	_streams["boss_death"] = _wav(_mezclar(boss_b, sust))

	# ── Ganancia de XP — beep corto agudo ────────────────────────────────────
	_streams["xp"] = _wav(_sine(880.0, 0.08, 40.0, 0.60))

	# ── Subida de nivel — acorde ascendente de tres notas ────────────────────
	# Do → Mi → Sol (arpegio mayor rápido)
	var n1 := _sine(523.0, 0.15, 12.0, 0.75)   # C5
	var n2 := _sine(659.0, 0.15, 12.0, 0.75)   # E5
	var n3 := _sine(784.0, 0.25, 8.0,  0.85)   # G5
	_streams["level_up"] = _wav(_concatenar([n1, n2, n3]))

	# ── Click de UI — tick muy corto ─────────────────────────────────────────
	_streams["ui_click"] = _wav(_ruido(0.04, 80.0, 0.50))

	# ── Wave completada — fanfarria corta (Do → Sol) ─────────────────────────
	var wc1 := _sine(440.0, 0.12, 15.0, 0.70)  # A4
	var wc2 := _sine(660.0, 0.18, 10.0, 0.80)  # E5
	_streams["wave_clear"] = _wav(_concatenar([wc1, wc2]))

	# ── Abrir inventario — dos notas ascendentes cortas ──────────────────────
	var inv_o1 := _sine(500.0, 0.06, 30.0, 0.55)
	var inv_o2 := _sine(700.0, 0.08, 25.0, 0.55)
	_streams["inventory_open"] = _wav(_concatenar([inv_o1, inv_o2]))

	# ── Cerrar inventario — las mismas dos notas pero descendentes ───────────
	var inv_c1 := _sine(700.0, 0.06, 30.0, 0.50)
	var inv_c2 := _sine(450.0, 0.08, 25.0, 0.50)
	_streams["inventory_close"] = _wav(_concatenar([inv_c1, inv_c2]))

	# ── Recoger objeto — "pip" agudo y muy corto ─────────────────────────────
	_streams["pickup"] = _wav(_sine(950.0, 0.07, 45.0, 0.55))

	# ── Consumir poción — glugh (dos borboteos) + brillo final ───────────────
	var glu1     := _sine(220.0, 0.07, 30.0, 0.55)
	var glu2     := _sine(260.0, 0.07, 30.0, 0.55)
	var brillo   := _sine(900.0, 0.10, 20.0, 0.45)
	var glugh    := _mezclar(glu1, glu2)
	_streams["potion_drink"] = _wav(_concatenar([glugh, brillo]))

	# ── Paso al caminar — golpecito seco y grave, muy corto ──────────────────
	_streams["walk"] = _wav(_ruido(0.05, 60.0, 0.30))

	# ── Romper objeto (árbol/arbusto/obstáculo) — crujido + estallido corto ──
	var crack   := _ruido(0.14, 22.0, 0.75)
	var snap    := _sine(140.0, 0.10, 30.0, 0.60)
	_streams["break_object"] = _wav(_mezclar(crack, snap))

	# ── Abrir puerta — chirrido grave ascendente ──────────────────────────────
	var puerta_o := _sine(180.0, 0.22, 8.0, 0.45)
	_streams["door_open"] = _wav(puerta_o)

	# ── Cerrar puerta — golpe seco grave ──────────────────────────────────────
	var puerta_c1 := _sine(90.0, 0.10, 25.0, 0.70)
	var puerta_c2 := _ruido(0.06, 40.0, 0.35)
	_streams["door_close"] = _wav(_mezclar(puerta_c1, puerta_c2))

	# ── Iniciar diálogo con NPC — "blip" suave, dos tonos cortos ─────────────
	var npc1 := _sine(600.0, 0.05, 35.0, 0.40)
	var npc2 := _sine(800.0, 0.06, 30.0, 0.45)
	_streams["npc_talk"] = _wav(_concatenar([npc1, npc2]))

	# ── Abrir cofre — crujido de madera + brillo de recompensa ───────────────
	var cofre_madera := _ruido(0.12, 20.0, 0.60)
	var cofre_brillo := _sine(1000.0, 0.15, 12.0, 0.40)
	_streams["chest_open"] = _wav(_concatenar([cofre_madera, cofre_brillo]))
