class_name StakeoutZone
extends Node2D

# Planque / filature — le verbe de la voie Polícia. Un suspect marche en boucle
# dans le quartier ; le joueur doit rester dans la bonne bande de distance
# (assez près pour observer, assez loin pour ne pas être grillé) le temps de
# monter le dossier. Trop près trois fois ou trop loin trop longtemps = suspect
# envolé, on retente depuis le spot donneur. Succès = objectif de quête coché.
#
# Spawnée par le verbe DialogueBridge `start_stakeout` :
#   {"quest": "policia_b2_filature", "objective": "filer_suspect",
#    "duration": 18.0, "seed": "suspect_b2"}
# Une seule planque à la fois (groupe "stakeout"). Aucun .tscn.

const OUTER_DIST: float = 240.0     # au-delà : on perd le suspect de vue
const INNER_DIST: float = 70.0      # en deçà : il te repère
const LOST_GRACE_SEC: float = 5.0   # tolérance hors de vue avant de le perdre
const SPOTTED_MAX: int = 3          # approches de trop avant qu'il file
const SPOTTED_COOLDOWN: float = 1.6 # anti-double-compte quand on frôle la limite
const WALK_SPEED: float = 46.0
const WAYPOINT_RADIUS: float = 90.0
const CHRONO_SOURCE: String = "stakeout"

const ANIM_FPS: float = 7.0
const WALK_CYCLE: Array[int] = [0, 1, 0, 2]

var quest_id: String = ""
var objective_id: String = ""
var duration: float = 18.0
var sprite_seed: String = "suspect"

var _watched: float = 0.0
var _lost_for: float = 0.0
var _spotted: int = 0
var _spotted_cd: float = 0.0
var _done: bool = false
var _waypoint: Vector2 = Vector2.ZERO
var _sprite: Sprite2D = null
var _anim_accum: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

static func spawn(params: Dictionary) -> StakeoutZone:
	var player: Node2D = GameManager.player as Node2D
	if player == null or not is_instance_valid(player):
		return null
	var tree: SceneTree = player.get_tree()
	if not tree.get_nodes_in_group("stakeout").is_empty():
		return null
	var zone: StakeoutZone = StakeoutZone.new()
	zone.quest_id = String(params.get("quest", ""))
	zone.objective_id = String(params.get("objective", ""))
	zone.duration = float(params.get("duration", 18.0))
	zone.sprite_seed = String(params.get("seed", "suspect"))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	# Le suspect démarre à mi-bande, côté aléatoire le long de la rue.
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	zone.position = player.global_position + Vector2(side * 150.0, rng.randf_range(-30.0, 30.0))
	var world: Node = tree.current_scene.get_node_or_null("World")
	if world == null:
		world = tree.current_scene
	world.add_child(zone)
	return zone

func _ready() -> void:
	add_to_group("stakeout")
	z_index = 1
	_rng.randomize()
	_pick_waypoint()
	_build_visual()
	EventBus.notification_requested.emit(
		"👁 Filature — reste à distance, ni trop près ni trop loin.",
		Color(0.5, 0.7, 0.95, 1))

func _build_visual() -> void:
	_sprite = Sprite2D.new()
	var config: Dictionary = CharacterSpriteFactory.random_config(hash(sprite_seed))
	_sprite.texture = CharacterSpriteFactory.build_sheet(config)
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sf: float = 48.0 / float(CharacterSpriteFactory.CELL_H)
	_sprite.scale = Vector2(sf, sf)
	add_child(_sprite)

# Déambulation : cap sur un point proche, re-tiré à l'arrivée. Le suspect longe
# la rue (dérive surtout en x) — pas de collision, il « connaît » son quartier.
func _pick_waypoint() -> void:
	_waypoint = global_position + Vector2(
		_rng.randf_range(-WAYPOINT_RADIUS, WAYPOINT_RADIUS) * 2.0,
		_rng.randf_range(-WAYPOINT_RADIUS, WAYPOINT_RADIUS) * 0.4)

func _process(delta: float) -> void:
	if _done:
		return
	var player: Node2D = GameManager.player as Node2D
	if player == null or not is_instance_valid(player):
		_abort()
		return
	if DialogueBridge.is_active() or CutsceneRunner.is_running():
		return
	# Marche du suspect.
	var to_wp: Vector2 = _waypoint - global_position
	if to_wp.length() < 8.0:
		_pick_waypoint()
	else:
		global_position += to_wp.normalized() * WALK_SPEED * delta
		_update_visual(delta, to_wp)
	# Bande d'observation.
	_spotted_cd = maxf(0.0, _spotted_cd - delta)
	var dist: float = player.global_position.distance_to(global_position)
	if dist < INNER_DIST:
		if _spotted_cd <= 0.0:
			_spotted += 1
			_spotted_cd = SPOTTED_COOLDOWN
			if _spotted >= SPOTTED_MAX:
				_fail("Il t'a grillé — le suspect se fond dans la foule.")
				return
			EventBus.notification_requested.emit(
				"⚠ Trop près ! (%d/%d)" % [_spotted, SPOTTED_MAX],
				Color(0.95, 0.6, 0.3, 1))
	elif dist > OUTER_DIST:
		_lost_for += delta
		if _lost_for >= LOST_GRACE_SEC:
			_fail("Perdu de vue — le suspect s'est évaporé.")
			return
	else:
		_lost_for = 0.0
		_watched += delta
	EventBus.chrono_updated.emit(CHRONO_SOURCE, "Filature en cours",
		maxf(duration - _watched, 0.0))
	if _watched >= duration:
		_succeed()
	queue_redraw()

func _succeed() -> void:
	if _done:
		return
	_done = true
	EventBus.chrono_cleared.emit(CHRONO_SOURCE)
	EventBus.notification_requested.emit("📋 Dossier bouclé — Ramos va apprécier.",
		Color(0.6, 0.9, 0.6, 1))
	if quest_id != "" and objective_id != "":
		QuestManager.complete_objective(quest_id, objective_id)
	queue_free()

func _fail(reason: String) -> void:
	if _done:
		return
	_done = true
	EventBus.chrono_cleared.emit(CHRONO_SOURCE)
	EventBus.notification_requested.emit("👁 %s Retourne voir ton contact." % reason,
		Color(0.95, 0.5, 0.4, 1))
	queue_free()

func _abort() -> void:
	_done = true
	EventBus.chrono_cleared.emit(CHRONO_SOURCE)
	queue_free()

func _update_visual(delta: float, dir: Vector2) -> void:
	if _sprite == null:
		return
	_anim_accum += delta * ANIM_FPS
	var col: int = WALK_CYCLE[int(_anim_accum) % WALK_CYCLE.size()]
	var row: int = 0
	if absf(dir.x) > absf(dir.y):
		row = 2
		_sprite.flip_h = dir.x < 0.0
	else:
		row = 1 if dir.y < 0.0 else 0
		_sprite.flip_h = false
	_sprite.region_rect = Rect2(
		col * CharacterSpriteFactory.CELL_W,
		row * CharacterSpriteFactory.CELL_H,
		CharacterSpriteFactory.CELL_W,
		CharacterSpriteFactory.CELL_H)

# Anneaux de bande : rouge en deçà (repérage), blanc au-delà (perte de vue).
# Dessinés autour du suspect pour que la règle soit lisible sans tutoriel.
func _draw() -> void:
	if _done:
		return
	draw_arc(Vector2.ZERO, INNER_DIST, 0, TAU, 40, Color(0.95, 0.4, 0.35, 0.4), 1.6)
	draw_arc(Vector2.ZERO, OUTER_DIST, 0, TAU, 56, Color(1, 1, 1, 0.28), 1.6)
