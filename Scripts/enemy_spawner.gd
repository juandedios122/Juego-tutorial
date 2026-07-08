extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
#  CONFIGURACIÓN (Inspector)
# ─────────────────────────────────────────────────────────────────────────────
@export var slime_scene    : PackedScene
@export var mushroom_scene : PackedScene
@export var spawn_points   : Array[Vector2] = []

@export var min_enemies    : int   = 3
@export var max_enemies    : int   = 6
@export_range(0.0, 1.0) var mushroom_ratio : float = 0.25
@export var wave_delay     : float = 3.0

## Cada cuántas oleadas aparece un jefe
@export var boss_wave_interval : int = 5
## Oleada del jefe final — derrotarlo gana la partida
@export var final_wave         : int = 10

# ─────────────────────────────────────────────────────────────────────────────
#  TIPOS DE ENCUENTRO
#  Cada ciclo de `boss_wave_interval` sigue el mismo patrón de ritmo:
#    posición 1 → NORMAL · 2 → HORDA · 3 → ÉLITE · 4 → NORMAL+ · 0 → JEFE
# ─────────────────────────────────────────────────────────────────────────────
enum WaveType { NORMAL, SWARM, ELITE, BOSS, FINAL_BOSS }

const _ANUNCIO_TEXTO : Dictionary = {
	WaveType.NORMAL:    "NUEVA OLEADA",
	WaveType.SWARM:     "⚡  ¡HORDA!",
	WaveType.ELITE:     "💀  ¡ÉLITE!",
	WaveType.BOSS:      "⚠   ¡JEFE!",
	WaveType.FINAL_BOSS:"☠   ¡JEFE FINAL!  ☠",
}
const _ANUNCIO_COLOR : Dictionary = {
	WaveType.NORMAL:    Color(0.80, 0.88, 1.00),
	WaveType.SWARM:     Color(1.00, 0.75, 0.20),
	WaveType.ELITE:     Color(0.80, 0.50, 1.00),
	WaveType.BOSS:      Color(1.00, 0.40, 0.40),
	WaveType.FINAL_BOSS:Color(0.95, 0.15, 0.15),
}

# ─────────────────────────────────────────────────────────────────────────────
#  ESTADO INTERNO
# ─────────────────────────────────────────────────────────────────────────────
var _active_enemies       : Array    = []
var _wave_active          : bool     = false
var _waiting_for_next_wave: bool     = false
var _wave_number          : int      = 0
var _tipo_oleada_actual   : WaveType = WaveType.NORMAL
var _path_positions       : Array[Vector2] = []


# ═════════════════════════════════════════════════════════════════════════════
#  INIT
# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	call_deferred("_deferred_setup")

func _deferred_setup() -> void:
	_setup_path_positions()
	# Soporte de checkpoint: si Global.start_from_wave > 1, saltamos oleadas
	_wave_number = max(0, Global.start_from_wave - 1)
	_spawn_wave()

func _setup_path_positions() -> void:
	var tile_map = get_parent().get_node_or_null("TileMap")
	if tile_map == null:
		push_warning("EnemySpawner: TileMap no encontrado.")
		return
	for cell in tile_map.get_used_cells(0):
		if tile_map.get_cell_source_id(0, cell) != 0:
			continue
		var td = tile_map.get_cell_tile_data(0, cell)
		if td == null or td.get_collision_polygons_count(0) > 0:
			continue
		_path_positions.append(tile_map.to_global(tile_map.map_to_local(cell)))
	print("EnemySpawner: %d posiciones de spawn." % _path_positions.size())


# ═════════════════════════════════════════════════════════════════════════════
#  OLEADA
# ═════════════════════════════════════════════════════════════════════════════
func _spawn_wave() -> void:
	if slime_scene == null and mushroom_scene == null:
		push_error("EnemySpawner: sin escenas de enemigo asignadas.")
		return
	if _path_positions.is_empty() and spawn_points.is_empty():
		push_error("EnemySpawner: sin posiciones de spawn.")
		return

	_active_enemies.clear()
	_wave_active         = true
	_waiting_for_next_wave = false
	_wave_number        += 1
	_tipo_oleada_actual  = _get_wave_type(_wave_number)

	Global.set_current_wave(_wave_number)
	Global.wave_encounter_started.emit(
		_ANUNCIO_TEXTO[_tipo_oleada_actual],
		_ANUNCIO_COLOR[_tipo_oleada_actual]
	)

	print("EnemySpawner: oleada %d — %s" % [_wave_number, WaveType.keys()[_tipo_oleada_actual]])

	match _tipo_oleada_actual:
		WaveType.BOSS, WaveType.FINAL_BOSS:
			_spawn_boss()
		_:
			var cantidad := _get_num_enemies(_wave_number, _tipo_oleada_actual)
			for i in range(cantidad):
				_spawn_one(_wave_number, _tipo_oleada_actual)

# ─── Tipo de oleada según posición en el ciclo ───────────────────────────────
func _get_wave_type(numero: int) -> WaveType:
	if boss_wave_interval <= 0:
		return WaveType.NORMAL
	if numero >= final_wave and numero % boss_wave_interval == 0:
		return WaveType.FINAL_BOSS
	if numero % boss_wave_interval == 0:
		return WaveType.BOSS
	var pos := numero % boss_wave_interval  # 1, 2, 3, 4...
	if pos == 2:
		return WaveType.SWARM
	if pos == 3:
		return WaveType.ELITE
	return WaveType.NORMAL

# ─── Cantidad de enemigos escalada por número de oleada ──────────────────────
func _get_num_enemies(numero: int, tipo: WaveType) -> int:
	var ciclo := int(numero / boss_wave_interval)   # cuántos ciclos completos
	match tipo:
		WaveType.SWARM:
			return randi_range(min_enemies + 4 + ciclo * 2,
							   max_enemies + 7 + ciclo * 3)
		WaveType.ELITE:
			return randi_range(2 + ciclo, 4 + ciclo)
		_:  # NORMAL
			return randi_range(min_enemies + ciclo, max_enemies + ciclo + 1)

# ─── Ratio de mushrooms escalado por tipo y número de oleada ─────────────────
func _get_mushroom_ratio(numero: int, tipo: WaveType) -> float:
	match tipo:
		WaveType.SWARM:  return 0.0      # pura horda de slimes
		WaveType.ELITE:  return 1.0      # sólo mushrooms duros
		_:
			return clampf(mushroom_ratio + float(numero) * 0.04, 0.0, 0.85)

# ─────────────────────────────────────────────────────────────────────────────
#  SPAWN
# ─────────────────────────────────────────────────────────────────────────────
func _elegir_posicion() -> Vector2:
	if not _path_positions.is_empty():
		var intentos := 0
		var pos := _path_positions[randi() % _path_positions.size()]
		while pos.distance_to(Vector2(54, 68)) < 110.0 and intentos < 30:
			pos = _path_positions[randi() % _path_positions.size()]
			intentos += 1
		return pos
	return spawn_points[randi() % spawn_points.size()]

func _spawn_one(numero_oleada: int, tipo: WaveType) -> void:
	var ratio := _get_mushroom_ratio(numero_oleada, tipo)
	var scene : PackedScene
	if mushroom_scene != null and slime_scene != null:
		scene = mushroom_scene if randf() < ratio else slime_scene
	else:
		scene = mushroom_scene if mushroom_scene != null else slime_scene
	if scene == null:
		return

	# Antes: scene.instantiate() + add_child() en CADA spawn, y nunca se
	# liberaba (ver fix en slime.gd/mushroom.gd). Ahora se reutiliza del
	# pool: mismo comportamiento para quien llama, pero sin fugas de nodos
	# ni costo de instanciar/GC en cada oleada.
	var enemy = EnemyPool.reservar_enemigo(scene, get_parent())
	if enemy == null:
		return

	# Escalar ANTES de activar (igual que el flujo original escalaba antes
	# de add_child/_ready), para que activar_desde_pool calcule el
	# ProgressBar.max_value ya con los stats de esta oleada.
	if enemy.has_method("escalar_para_oleada"):
		enemy.escalar_para_oleada(numero_oleada)

	if enemy.has_method("activar_desde_pool"):
		enemy.activar_desde_pool(_elegir_posicion())

	# devolver_al_pool sustituye a tree_exited: con el pool activo el nodo
	# YA NO sale del árbol al morir, así que tree_exited nunca se dispararía
	# y la oleada quedaría bloqueada para siempre.
	if enemy.has_signal("devolver_al_pool") and not enemy.devolver_al_pool.is_connected(_on_enemy_died):
		enemy.devolver_al_pool.connect(_on_enemy_died)

	_active_enemies.append(enemy)

func _spawn_boss() -> void:
	var scene := mushroom_scene if mushroom_scene != null else slime_scene
	if scene == null:
		return

	var jefe := EnemyPool.reservar_enemigo(scene, get_parent())
	if jefe == null:
		return

	if jefe.has_signal("devolver_al_pool") and not jefe.devolver_al_pool.is_connected(_on_enemy_died):
		jefe.devolver_al_pool.connect(_on_enemy_died)

	if jefe.has_method("activar_desde_pool"):
		jefe.activar_desde_pool(_elegir_posicion())

	if jefe.has_method("convertir_en_jefe"):
		jefe.convertir_en_jefe()

	# El jefe también escala con el número de oleada (ciclos extra lo hacen
	# más duro en cada vuelta), pero DESPUÉS de convertir_en_jefe().
	if jefe.has_method("escalar_para_oleada"):
		jefe.escalar_para_oleada(_wave_number)

	_active_enemies.append(jefe)


# ═════════════════════════════════════════════════════════════════════════════
#  DETECCIÓN DE FIN DE OLEADA
# ═════════════════════════════════════════════════════════════════════════════
func _on_enemy_died(enemigo: Node = null) -> void:
	if not is_inside_tree():
		return
	# Con el pool activo, el enemigo NUNCA sale del árbol (is_instance_valid
	# seguiría dando true para siempre), así que hay que quitarlo del
	# registro explícitamente usando la referencia que llega en la señal
	# devolver_al_pool, en vez de filtrar por validez.
	if enemigo != null:
		_active_enemies.erase(enemigo)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_check_wave_cleared()

func _check_wave_cleared() -> void:
	# Limpieza defensiva por si algún nodo llegó a liberarse por otra vía
	# (p. ej. al cambiar de escena a mitad de oleada).
	_active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e))

	if not (_active_enemies.is_empty() and _wave_active and not _waiting_for_next_wave):
		return

	_waiting_for_next_wave = true
	_wave_active           = false

	# ── Logros de jefe ────────────────────────────────────────────────────
	if _tipo_oleada_actual in [WaveType.BOSS, WaveType.FINAL_BOSS]:
		var es_final := (_tipo_oleada_actual == WaveType.FINAL_BOSS)
		if has_node("/root/Achievements"):
			get_node("/root/Achievements").jefe_derrotado(es_final)

	# ── Condición de victoria: jefe final eliminado ───────────────────────
	if _tipo_oleada_actual == WaveType.FINAL_BOSS:
		print("EnemySpawner: ¡JEFE FINAL DERROTADO! Victoria.")
		SceneTransition.ir_a("res://Scenes/PantallaVictoria.tscn")
		return

	# ── Checkpoint tras vencer un jefe intermedio ─────────────────────────
	if _tipo_oleada_actual == WaveType.BOSS:
		Global.set_checkpoint(_wave_number + 1)
		print("EnemySpawner: checkpoint guardado en oleada %d." % (_wave_number + 1))

	# ── Siguiente oleada ──────────────────────────────────────────────────
	print("EnemySpawner: oleada %d completada. Próxima en %.1fs." % [_wave_number, wave_delay])
	await get_tree().create_timer(wave_delay).timeout
	if is_inside_tree():
		_spawn_wave()
