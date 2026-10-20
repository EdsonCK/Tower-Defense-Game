class_name CombatIndex
extends RefCounted
## Spatial broad phase only. Callers retain exact distance/swept hit tests.
## Insertion order matches SceneTree enemy group order, including equal-distance ties.
const BUCKET_SIZE := 64.0
var _buckets: Dictionary = {}
var _cells: Dictionary = {}
var _order: Dictionary = {}
var _serial := 0

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / BUCKET_SIZE), floori(point.y / BUCKET_SIZE))

func update(node: Node2D) -> void:
	var key := _cell(node.position)
	if _cells.has(node):
		if _cells[node] == key:
			return
		_erase_bucket(node, _cells[node])
	else:
		_order[node] = _serial
		_serial += 1
	_cells[node] = key
	if not _buckets.has(key): _buckets[key] = []
	_buckets[key].append(node)

func remove(node: Node2D) -> void:
	if _cells.has(node):
		_erase_bucket(node, _cells[node])
		_cells.erase(node)
		_order.erase(node)

func _erase_bucket(node: Node2D, key: Vector2i) -> void:
	_buckets[key].erase(node)
	if _buckets[key].is_empty(): _buckets.erase(key)

func query(rect: Rect2) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var first := _cell(rect.position)
	var last := _cell(rect.end)
	if _buckets.is_empty():
		return result
	var width := last.x - first.x + 1
	var height := last.y - first.y + 1
	# Large/mostly empty queries inspect occupied buckets, bounding work even
	# for a transformed range much larger than the board.
	if width > _buckets.size() or height > _buckets.size() or width * height > _buckets.size():
		for key in _buckets:
			if key.x >= first.x and key.x <= last.x and key.y >= first.y and key.y <= last.y:
				for node in _buckets[key]: result.append(node)
	else:
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var key := Vector2i(x, y)
				if _buckets.has(key):
					for node in _buckets[key]: result.append(node)
	result.sort_custom(func(a: Node2D, b: Node2D) -> bool: return _order[a] < _order[b])
	return result

func query_global(center: Vector2, radius: float, container: Node2D) -> Array[Node2D]:
	# Transform the whole rectangle, not just its center; nonuniform parent scales
	# and rotation must not prune enemies which pass the global narrow phase.
	var inverse := container.global_transform.affine_inverse()
	var rect := inverse * Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2)
	return query(rect.grow(0.01)) # Conservative rounding margin; exact range is checked by caller.
