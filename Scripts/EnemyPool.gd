extends Node
## EnemyPool.gd  —  Autoload Singleton
##
## Gestor real de object pooling para enemigos (slime, mushroom, futuros tipos).
## Antes de este script, slime.gd y mushroom.gd emitían la señal
## `devolver_al_pool` pero NADIE la escuchaba: el nodo nunca se liberaba ni
## se reutilizaba, quedando como un "cadáver" en el árbol para siempre
## (con su CollisionShape2D raíz aún activo), lo que causaba que enemigos ya
## muertos siguieran golpeando al jugador y que su barra de vida y sprite
## quedaran huérfanos en pantalla.
##
## Este autoload:
##   1. Instancia un enemigo nuevo SOLO si no hay ninguno libre en el pool.
##   2. Cuando un enemigo emite `devolver_al_pool`, lo oculta/desactiva
##      (no lo libera) y lo guarda para la siguiente oleada.
##   3. Reutilizar nodos evita instantiate()/queue_free() constantes durante
##      las oleadas, lo cual es importante para evitar hitches de GC en Android.

# scene.resource_path -> Array[Node] de instancias libres para reutilizar
var _libres: Dictionary = {}

## Reserva un enemigo de esta escena (reciclado del pool o recién creado) y
## le aplica reset_stats(), pero SIN activarlo todavía ni fijar su posición.
## Se separa de activar_desde_pool() a propósito: quien llama necesita una
## ventana para aplicar escalar_para_oleada()/convertir_en_jefe() ANTES de
## que se recalculen los valores del ProgressBar — igual que en el flujo
## original, donde el spawner escalaba antes de add_child() (antes de
## _ready()). Si activáramos aquí directamente, un enemigo reciclado
## mostraría una barra de vida con el max_value desactualizado.
func reservar_enemigo(scene: PackedScene, contenedor: Node) -> Node:
	if scene == null:
		return null

	var lista: Array = _libres.get(scene, [])
	var enemigo: Node = null

	while not lista.is_empty():
		var candidato: Node = lista.pop_back()
		if is_instance_valid(candidato):
			enemigo = candidato
			break

	if enemigo == null:
		enemigo = scene.instantiate()
		if enemigo.has_signal("devolver_al_pool"):
			enemigo.devolver_al_pool.connect(_on_enemigo_devuelto.bind(scene))
		contenedor.add_child(enemigo)
	elif enemigo.get_parent() != contenedor:
		enemigo.get_parent().remove_child(enemigo)
		contenedor.add_child(enemigo)

	if enemigo.has_method("reset_stats"):
		enemigo.reset_stats()

	_libres[scene] = lista
	return enemigo

## Atajo para el caso simple (sin escalado por oleada): reserva y activa
## en un solo paso.
func obtener_enemigo(scene: PackedScene, contenedor: Node, pos: Vector2) -> Node:
	var enemigo := reservar_enemigo(scene, contenedor)
	if enemigo != null and enemigo.has_method("activar_desde_pool"):
		enemigo.activar_desde_pool(pos)
	return enemigo

func _on_enemigo_devuelto(enemigo: Node, scene: PackedScene) -> void:
	if not is_instance_valid(enemigo):
		return
	if not _libres.has(scene):
		_libres[scene] = []
	(_libres[scene] as Array).append(enemigo)

## Vacía el pool por completo (llamar al reiniciar partida desde cero,
## p. ej. en pantalla_muerte.gd / pantalla_victoria.gd, para no arrastrar
## enemigos escalados de una sesión anterior).
func limpiar_pool() -> void:
	for scene in _libres.keys():
		for enemigo in _libres[scene]:
			if is_instance_valid(enemigo):
				enemigo.queue_free()
	_libres.clear()
