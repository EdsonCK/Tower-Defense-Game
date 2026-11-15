class_name MapLayout
extends RefCounted
## The fixed path network for one run, generated from the run seed.
##
## The network is a tree rooted at the single exit (the map center). Branches wind
## outward to the edge of the full grid; fork branches split off existing paths, which
## creates crossroads. Every path cell knows its parent (the next cell toward the exit),
## so enemies simply follow parents. Rules that hold for every generated map:
## - the path is exactly 1 tile wide: a new cell never touches another path cell
##   side-by-side except the cell it continues from;
## - moving outward along a branch never brings it closer to the exit (by the window
##   "ring" metric), so a branch crosses every window border exactly once. That means
##   enemies entering a window never leave it again on their way to the exit;
## - branches turn often (they are deliberately windy).
## After the path, a few lakes ("features": water, lava, ice or bog depending on the
## biome's look) are placed well away from every path cell, so they shape the land
## without ever blocking the best tower spots.

const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const MAX_ATTEMPTS: int = 40
const MAX_STEPS: int = 600
const MAX_STRAIGHT: int = 8  # a branch never runs straighter than this many tiles
const FEATURE_MIN_PATH_GAP: int = 3  # lake tiles are at least this many steps from any path
const FEATURE_LAKES: Vector2i = Vector2i(6, 10)  # lakes per map (min, max)

var exit: Vector2i = GameConfig.EXIT_CELL
## Path cell -> parent cell (one step closer to the exit). The exit maps to itself.
var parent: Dictionary = {}
## Path cell -> Array of child cells (one step further from the exit).
var children: Dictionary = {}
## Path cell -> number of steps to the exit.
var distance: Dictionary = {}
## Lake cell -> true. Never on or near the path; towers can't be built there.
var features: Dictionary = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Per-map style, rolled from the seed in generate().
var _keep_straight_chance: float = 0.8
var _straight_min: int = 2
var _straight_max: int = 5


func _init(seed_value: int = 0) -> void:
	generate(seed_value)


## Window "ring" of a cell: a cell is inside the window of half-width hw exactly when
## ring <= 3 * hw (the window is hw wide and floor(3*hw/5) tall on each side).
static func ring(cell: Vector2i) -> int:
	var d: Vector2i = cell - GameConfig.EXIT_CELL
	return maxi(3 * absi(d.x), 5 * absi(d.y))


static func half_height(half_width: int) -> int:
	return floori(3.0 * half_width / 5.0)


static func in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GameConfig.GRID_COLUMNS and cell.y < GameConfig.GRID_ROWS


static func in_window(cell: Vector2i, half_width: int) -> bool:
	return in_grid(cell) and ring(cell) <= 3 * half_width


static func max_ring() -> int:
	return 3 * GameConfig.MAP_MAX_HALF_WIDTH


func is_path(cell: Vector2i) -> bool:
	return parent.has(cell)


## The next cell toward the exit (the exit returns itself).
func next_cell(cell: Vector2i) -> Vector2i:
	return parent.get(cell, exit)


## Path cells, from `cell` to the exit inclusive.
func route_from(cell: Vector2i) -> Array[Vector2i]:
	var route: Array[Vector2i] = [cell]
	while route[route.size() - 1] != exit:
		route.append(parent[route[route.size() - 1]])
	return route


## Where enemies enter the window of `half_width`: path cells inside it that are dead
## ends or continue outside it. Sorted so the order is stable.
func entrances(half_width: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in parent:
		if cell == exit or not in_window(cell, half_width):
			continue
		var kids: Array = children.get(cell, [])
		if kids.is_empty():
			result.append(cell)
			continue
		for kid: Vector2i in kids:
			if not in_window(kid, half_width):
				result.append(cell)
				break
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * 1000 + a.y < b.x * 1000 + b.y)
	return result


## Path cells inside the window where two or more routes meet.
func junctions(half_width: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in children:
		if in_window(cell, half_width) and (children[cell] as Array).size() >= 2:
			result.append(cell)
	return result


func generate(seed_value: int) -> void:
	_rng.seed = hash(["map", seed_value])
	parent = {exit: exit}
	children = {}
	distance = {exit: 0}
	# Every map gets its own character: the angle the main branches leave the gate, how
	# many forks split off later, and how twisty the paths are all vary with the seed.
	_keep_straight_chance = _rng.randf_range(0.6, 0.8)
	_straight_min = _rng.randi_range(1, 3)
	_straight_max = _straight_min + _rng.randi_range(2, 3)
	var roots: int = GameConfig.MAP_ROOT_BRANCHES
	var fork_total: int = GameConfig.MAP_FORK_BRANCHES + _rng.randi_range(-1, 1)
	# Root branches spread evenly from the exit (with some jitter); the first heads roughly
	# sideways (the map is wider than tall) but at a different angle every run.
	var base_angle: float = (0.0 if _rng.randf() < 0.5 else PI) + _rng.randf_range(-0.6, 0.6)
	for i in roots:
		_carve_branch(exit, base_angle + TAU * i / roots + _rng.randf_range(-0.25, 0.25))
	# Fork branches split off existing paths at varied distances (so new entrances and
	# crossroads keep appearing as the window grows) and head for the emptiest direction.
	var forks_made: int = 0
	var tries: int = 0
	while forks_made < fork_total and tries < 200:
		tries += 1
		var lo: float = 0.2 + 0.5 * float(forks_made) / maxf(1.0, fork_total - 1)
		var target: float = _emptiest_angle()
		var start: Vector2i = _pick_fork_cell(lo * max_ring(), (lo + 0.25) * max_ring(), target)
		if start == Vector2i(-1, -1):
			continue
		if _carve_branch(start, target + _rng.randf_range(-0.3, 0.3)):
			forks_made += 1
	_place_features()


func is_feature(cell: Vector2i) -> bool:
	return features.has(cell)


## Steps (4-neighbour) from every grid cell to the nearest path cell.
func path_gap_field() -> Dictionary:
	var gap: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for cell: Vector2i in parent:
		gap[cell] = 0
		frontier.append(cell)
	var head: int = 0
	while head < frontier.size():
		var cell: Vector2i = frontier[head]
		head += 1
		for d: Vector2i in DIRECTIONS:
			var next: Vector2i = cell + d
			if in_grid(next) and not gap.has(next):
				gap[next] = int(gap[cell]) + 1
				frontier.append(next)
	return gap


## Scatters a handful of irregular lakes over open land, keeping clear of the path.
func _place_features() -> void:
	features = {}
	var gap: Dictionary = path_gap_field()
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in gap:
		if int(gap[cell]) >= FEATURE_MIN_PATH_GAP + 1 and cell.distance_to(exit) > 4.0:
			candidates.append(cell)
	if candidates.is_empty():
		return
	var lakes: int = _rng.randi_range(FEATURE_LAKES.x, FEATURE_LAKES.y)
	for i in lakes:
		var center: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
		# A lake is two or three overlapping ellipses, for an irregular shoreline.
		for blob in _rng.randi_range(2, 3):
			var offset: Vector2 = Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.0, 1.0))
			var radii: Vector2 = Vector2(_rng.randf_range(1.0, 2.4), _rng.randf_range(0.8, 1.8))
			for dy in range(-3, 4):
				for dx in range(-4, 5):
					var cell: Vector2i = center + Vector2i(dx, dy)
					var rel: Vector2 = (Vector2(dx, dy) - offset) / radii
					if rel.length_squared() <= 1.0 and int(gap.get(cell, 0)) >= FEATURE_MIN_PATH_GAP:
						features[cell] = true
	# Round the shorelines: drop spurs, fill notches (a couple of cellular-automaton passes).
	for pass_index in 2:
		var changes: Dictionary = {}
		var region: Dictionary = {}
		for cell: Vector2i in features:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					region[cell + Vector2i(dx, dy)] = true
		for cell: Vector2i in region:
			var around: int = 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dy != 0) and features.has(cell + Vector2i(dx, dy)):
						around += 1
			if features.has(cell) and around < 3:
				changes[cell] = false
			elif not features.has(cell) and around >= 5 and int(gap.get(cell, 0)) >= FEATURE_MIN_PATH_GAP:
				changes[cell] = true
		for cell: Vector2i in changes:
			if changes[cell]:
				features[cell] = true
			else:
				features.erase(cell)


## Direction from the exit (aspect-normalized) farthest from every existing branch end.
func _emptiest_angle() -> float:
	var used: Array[float] = []
	for cell: Vector2i in parent:
		if cell != exit and not children.has(cell):
			used.append(_normalized_angle(cell))
	var best: float = _rng.randf() * TAU
	var best_gap: float = -1.0
	for i in 24:
		var candidate: float = TAU * i / 24.0 + _rng.randf_range(-0.05, 0.05)
		var gap: float = PI
		for angle: float in used:
			gap = minf(gap, absf(angle_difference(candidate, angle)))
		if gap > best_gap:
			best_gap = gap
			best = candidate
	return best


func _normalized_angle(cell: Vector2i) -> float:
	var d: Vector2i = cell - exit
	return Vector2(float(d.x) / GameConfig.MAP_MAX_HALF_WIDTH, float(d.y) / half_height(GameConfig.MAP_MAX_HALF_WIDTH)).angle()


## A path cell (no junction yet) in the given ring band, nearest in direction to `target`.
func _pick_fork_cell(min_ring: float, max_ring_value: float, target: float) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: float = INF
	for cell: Vector2i in parent:
		var r: int = ring(cell)
		if cell == exit or r < min_ring or r > max_ring_value or (children.get(cell, []) as Array).size() != 1:
			continue
		var score: float = absf(angle_difference(_normalized_angle(cell), target)) + _rng.randf() * 0.3
		if score < best_score:
			best_score = score
			best = cell
	return best


## Carves one windy branch outward from `start` toward `angle` until it reaches the edge
## of the full grid. Returns false (changing nothing) if every attempt got stuck.
func _carve_branch(start: Vector2i, angle: float) -> bool:
	var bias: Vector2 = Vector2.RIGHT.rotated(angle)
	for attempt in MAX_ATTEMPTS:
		var walk: Array[Vector2i] = [start]
		var in_walk: Dictionary = {start: true}
		var heading: Vector2i = Vector2i.ZERO
		var straight_left: int = 0
		# A fork continues a straight stretch of its parent branch; count that stretch so the
		# junction can't be the middle of an overly long straight line.
		var run_length: int = _incoming_run(start)
		if run_length > 0:
			heading = start - (parent[start] as Vector2i)
		var ok: bool = false
		for step in MAX_STEPS:
			var current: Vector2i = walk[walk.size() - 1]
			if ring(current) >= max_ring():
				ok = true
				break
			var options: Array[Vector2i] = []
			for d: Vector2i in DIRECTIONS:
				if _can_step(current, current + d, in_walk):
					options.append(d)
			if run_length >= MAX_STRAIGHT and options.size() > 1:
				options.erase(heading)
			if options.is_empty():
				break
			var chosen: Vector2i
			if heading in options and straight_left > 0 and _rng.randf() < _keep_straight_chance:
				chosen = heading
			else:
				chosen = _weighted_direction(options, bias, heading)
			if chosen != heading:
				straight_left = _rng.randi_range(_straight_min, _straight_max)
				run_length = 0
			run_length += 1
			heading = chosen
			straight_left -= 1
			var next: Vector2i = current + chosen
			walk.append(next)
			in_walk[next] = true
		if ok and walk.size() > 1:
			for i in range(1, walk.size()):
				parent[walk[i]] = walk[i - 1]
				distance[walk[i]] = distance[walk[i - 1]] + 1
				if not children.has(walk[i - 1]):
					children[walk[i - 1]] = []
				(children[walk[i - 1]] as Array).append(walk[i])
			return true
		bias = bias.rotated(_rng.randf_range(-0.6, 0.6))
	return false


## Length of the straight stretch that ends at `cell`, walking toward the exit.
func _incoming_run(cell: Vector2i) -> int:
	if cell == exit:
		return 0
	var dir: Vector2i = cell - (parent[cell] as Vector2i)
	var length: int = 0
	var c: Vector2i = cell
	while c != exit and c - (parent[c] as Vector2i) == dir:
		length += 1
		c = parent[c]
	return length


func _can_step(current: Vector2i, next: Vector2i, in_walk: Dictionary) -> bool:
	if not in_grid(next) or parent.has(next) or in_walk.has(next):
		return false
	if ring(next) < ring(current):
		return false  # never back toward the exit
	# 1 tile wide: the new cell may only touch the cell it continues from.
	for d: Vector2i in DIRECTIONS:
		var neighbour: Vector2i = next + d
		if neighbour != current and (parent.has(neighbour) or in_walk.has(neighbour)):
			return false
	return true


func _weighted_direction(options: Array[Vector2i], bias: Vector2, heading: Vector2i) -> Vector2i:
	var weights: Array[float] = []
	var total: float = 0.0
	for d: Vector2i in options:
		# Favour the branch's general direction, but keep sideways turns likely (windy).
		var w: float = 1.4 + Vector2(d).dot(bias)
		if d == heading:
			w *= 0.6
		w = maxf(w, 0.15)
		weights.append(w)
		total += w
	var roll: float = _rng.randf() * total
	for i in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[options.size() - 1]
