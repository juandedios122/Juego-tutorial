extends Node
## Achievements.gd  —  Autoload Singleton
## Sistema de 10 logros atados a eventos ya existentes en el juego.
## Los logros dan algo tangible al jugador entre sesiones, aumentando la
## retención (punto 15 de la crítica).
##
## Añadir al Autoload: Nombre "Achievements"  Ruta "res://Scripts/Achievements.gd"
##
## Uso:
##   Achievements.check("primera_sangre")    # comprueba y desbloquea
##   Achievements.check("oleadas", 5)        # comprueba con valor
##   signal desbloqueado(id, titulo, icono)  # conectar en mundo.gd / HUD

const SAVE_KEY := "achievements"

## Emitida cuando se desbloquea un logro.
## mundo.gd lo conecta para mostrar el popup al jugador.
signal desbloqueado(id: String, titulo: String, icono: String)

# ─── Definición de logros ─────────────────────────────────────────────────────
# Cada entrada: id → { titulo, icono, descripcion, objetivo (int o 0 si booleano) }
const DEFINICIONES := {
	"primera_sangre": {
		"titulo"      : "Primera Sangre",
		"icono"       : "⚔",
		"descripcion" : "Mata a tu primer enemigo",
		"objetivo"    : 0
	},
	"guerrero_10": {
		"titulo"      : "Guerrero",
		"icono"       : "🗡",
		"descripcion" : "Mata 10 enemigos en total",
		"objetivo"    : 10
	},
	"carnicero": {
		"titulo"      : "Carnicero",
		"icono"       : "💀",
		"descripcion" : "Mata 100 enemigos en total",
		"objetivo"    : 100
	},
	"superviviente": {
		"titulo"      : "Superviviente",
		"icono"       : "🛡",
		"descripcion" : "Completa la oleada 5",
		"objetivo"    : 5
	},
	"cazador_de_jefes": {
		"titulo"      : "Cazador de Jefes",
		"icono"       : "👑",
		"descripcion" : "Derrota a tu primer jefe",
		"objetivo"    : 0
	},
	"nivel_5": {
		"titulo"      : "En Forma",
		"icono"       : "⭐",
		"descripcion" : "Alcanza el nivel 5",
		"objetivo"    : 5
	},
	"inmortal": {
		"titulo"      : "Inmortal",
		"icono"       : "🔥",
		"descripcion" : "Llega a la oleada 10 (el jefe final)",
		"objetivo"    : 10
	},
	"diez_muertes": {
		"titulo"      : "Persistente",
		"icono"       : "💪",
		"descripcion" : "Muere 10 veces y sigue jugando",
		"objetivo"    : 10
	},
	"veterano": {
		"titulo"      : "Veterano",
		"icono"       : "🏆",
		"descripcion" : "Mata 500 enemigos en total",
		"objetivo"    : 500
	},
	"leyenda": {
		"titulo"      : "Leyenda",
		"icono"       : "🌟",
		"descripcion" : "Derrota al jefe final",
		"objetivo"    : 0
	},
}

# ─── Estado interno ───────────────────────────────────────────────────────────
# Diccionario persistido: id → true (desbloqueado) o false (pendiente)
var _estado : Dictionary = {}

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar()
	# Conectar a señales globales existentes para auto-check
	Global.enemy_count_changed.connect(_on_enemy_count_changed)
	Global.xp_gained.connect(_on_xp_gained)
	Global.wave_changed.connect(_on_wave_changed)
	print("✅ Achievements — %d logros (%d desbloqueados)" % [
		DEFINICIONES.size(), _estado.values().count(true)
	])

# ─────────────────────────────────────────────────────────────────────────────
#  API PÚBLICA
# ─────────────────────────────────────────────────────────────────────────────

## Comprueba un logro por su id. valor es el progreso actual (o 0 si booleano).
func check(id: String, valor: int = 1) -> void:
	if not id in DEFINICIONES:
		return
	if _estado.get(id, false):
		return   # ya desbloqueado

	var def     : Dictionary = DEFINICIONES[id]
	var objetivo: int        = def["objetivo"]

	var desbloquear := false
	if objetivo == 0:
		desbloquear = valor >= 1
	else:
		desbloquear = valor >= objetivo

	if desbloquear:
		_desbloquear(id)

## Devuelve cuántos logros están desbloqueados.
func progreso() -> int:
	return _estado.values().count(true)

## Devuelve true si el logro con ese id ya está desbloqueado.
func esta_desbloqueado(id: String) -> bool:
	return _estado.get(id, false)

## Lista de todos los logros con su estado actual (para pantalla de logros).
func lista_completa() -> Array[Dictionary]:
	var lista : Array[Dictionary] = []
	for id in DEFINICIONES:
		var entry = DEFINICIONES[id].duplicate()
		entry["id"]           = id
		entry["desbloqueado"] = _estado.get(id, false)
		lista.append(entry)
	return lista

# ─────────────────────────────────────────────────────────────────────────────
#  CONEXIONES AUTOMÁTICAS
# ─────────────────────────────────────────────────────────────────────────────
func _on_enemy_count_changed(_alive: int, killed: int) -> void:
	if killed >= 1:
		check("primera_sangre")
	check("guerrero_10",  Global.enemies_killed_total)
	check("carnicero",    Global.enemies_killed_total)
	check("veterano",     Global.enemies_killed_total)

func _on_xp_gained(_cantidad: int, nuevo_nivel: int, _subio: bool) -> void:
	check("nivel_5", nuevo_nivel)

func _on_wave_changed(numero: int) -> void:
	check("superviviente", numero)
	check("inmortal",      numero)

## Llamado manualmente desde enemy_spawner cuando muere un jefe.
func jefe_derrotado(es_final: bool) -> void:
	check("cazador_de_jefes")
	if es_final:
		check("leyenda")

## Llamado manualmente desde Global.registrar_muerte() o pantalla_muerte.gd.
func muerte_registrada() -> void:
	check("diez_muertes", Global.death_count)

# ─────────────────────────────────────────────────────────────────────────────
#  PERSISTENCIA
# ─────────────────────────────────────────────────────────────────────────────
func _desbloquear(id: String) -> void:
	_estado[id] = true
	_guardar()
	var def : Dictionary = DEFINICIONES[id]
	print("🏆 Logro desbloqueado: %s %s" % [def["icono"], def["titulo"]])
	desbloqueado.emit(id, def["titulo"], def["icono"])

func _guardar() -> void:
	var cfg := ConfigFile.new()
	for id in _estado:
		cfg.set_value("logros", id, _estado[id])
	cfg.save("user://logros.cfg")

func _cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://logros.cfg") != OK:
		for id in DEFINICIONES:
			_estado[id] = false
		return
	for id in DEFINICIONES:
		_estado[id] = cfg.get_value("logros", id, false)
