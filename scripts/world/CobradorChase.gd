class_name CobradorChase
extends CharacterBody2D

# Poursuite de rue générique : un poursuivant surgit et course le joueur.
# Le sprint draine la stamina (PlayerController), donc semer se joue : sprinter
# par à-coups, couper par les rues, sauter sur un vélo, acheter une água de
# coco au vol. Le poursuivant fatigue lui aussi, plus vite que toi.
#
# Cas d'usage : le cobrador du consortium (défaut, spawné par
# CreditorVisitManager) et les poursuites de mission (PM sur la voie Tráfico…)
# déclenchées par le verbe DialogueBridge `start_chase`. La fin émet
# EventBus.chase_ended(chaser_id, escaped) — les objectifs FUITE de
# QuestManager s'y accrochent (filtrés par chaser_id).
#
# Configuration par le dict `config` (posé AVANT add_child) ; défauts = cobrador.
# Spawné en code ; aucun .tscn.

const DEFAULTS: Dictionary = {
	"chaser_id": "cobrador",
	"speed_start": 126.0,     # entre marche (80) et sprint (140)
	"speed_tired": 96.0,      # lui aussi s'essouffle
	"tire_after_sec": 22.0,
	"give_up_dist": 560.0,
	"give_up_sec": 40.0,
	"catch_pct": 0.15,        # part du cash de poche prélevée si rattrapé
	"catch_min": 20,
	"escape_rep_street": 1,   # la malandragem paie
	"broke_rep_street": -2,   # rattrapé les poches vides : le quartier a vu
	"sprite_seed": "cobrador_consorcio",
	"spotted_text": "⚠ Um cobrador te viu — corre !",
	"caught_text": "✋ « Os juros, parceiro. » Le cobrador prend R$ %d.",
	"broke_text": "✋ « Sem grana ? Da próxima vez... » Le quartier a vu la scène.",
	"escaped_text": "💨 Semeou o cobrador ! O bairro viu.",
	"chrono_label": "Semeia o cobrador !",
	# Clémence (0 = aucune) : après ce nombre de captures d'affilée par le
	# même poursuivant, il repart déjà entamé. Pour les poursuites qui barrent
	# la trame (A8, Niterói) — jamais bloquant, comme Juca qui cède.
	"mercy_after": 0,
	"mercy_text": "😮‍💨 Il a déjà couru après toi — il souffle avant même de partir.",
}

const CATCH_DIST: float = 26.0
const ANIM_FPS: float = 9.0
const WALK_CYCLE: Array[int] = [0, 1, 0, 2]
const SPAWN_DIST: float = 380.0

# La rue travaille pour qui elle respecte : à partir de ce seuil STREET, la
# foule se referme derrière toi — le poursuivant abandonne plus tôt et
# fatigue plus vite. S'applique à toutes les chasses (cobrador, PM…).
const STREET_COVER_THRESHOLD: int = 50
const STREET_GIVE_UP_FACTOR: float = 0.75
const STREET_TIRE_FACTOR: float = 0.8

var config: Dictionary = {}

# Config effective selon la réputation STREET — pure, testable.
static func adjusted_config(cfg: Dictionary, street_value: int) -> Dictionary:
	if street_value < STREET_COVER_THRESHOLD:
		return cfg
	var out: Dictionary = cfg.duplicate()
	var base_give_up: float = float(out.get("give_up_sec", DEFAULTS["give_up_sec"]))
	var base_tire: float = float(out.get("tire_after_sec", DEFAULTS["tire_after_sec"]))
	out["give_up_sec"] = base_give_up * STREET_GIVE_UP_FACTOR
	out["tire_after_sec"] = base_tire * STREET_TIRE_FACTOR
	return out

# Poursuivant entamé : plus lent, fatigue et abandon plus tôt — pure, testable.
const MERCY_SPEED_FACTOR: float = 0.92
const MERCY_TIRE_FACTOR: float = 0.6
const MERCY_GIVE_UP_FACTOR: float = 0.75

static func mercy_config(cfg: Dictionary, caught_streak: int) -> Dictionary:
	var after: int = int(cfg.get("mercy_after", DEFAULTS["mercy_after"]))
	if after <= 0 or caught_streak < after:
		return cfg
	var out: Dictionary = cfg.duplicate()
	out["speed_start"] = float(out.get("speed_start", DEFAULTS["speed_start"])) * MERCY_SPEED_FACTOR
	out["tire_after_sec"] = float(out.get("tire_after_sec", DEFAULTS["tire_after_sec"])) * MERCY_TIRE_FACTOR
	out["give_up_sec"] = float(out.get("give_up_sec", DEFAULTS["give_up_sec"])) * MERCY_GIVE_UP_FACTOR
	return out

# Captures d'affilée par poursuivant (remis à zéro dès qu'on le sème).
static var _caught_streak: Dictionary = {}

var _elapsed: float = 0.0
var _done: bool = false
var _sprite: Sprite2D = null
var _anim_accum: float = 0.0

# Instancie une poursuite près du joueur, le long de l'axe des rues (la map est
# horizontale : évite la mer et le cœur des immeubles). Refuse (null) si pas de
# joueur ou si une poursuite est déjà en cours — jamais deux chasses empilées.
static func spawn(cfg: Dictionary = {}) -> CobradorChase:
	var player: Node2D = GameManager.player as Node2D
	if player == null or not is_instance_valid(player):
		return null
	var tree: SceneTree = player.get_tree()
	if not tree.get_nodes_in_group("cobrador_chase").is_empty():
		return null
	var chase: CobradorChase = CobradorChase.new()
	var street: int = ReputationSystem.get_value(ReputationSystem.Axis.STREET)
	var streak: int = int(_caught_streak.get(String(cfg.get("chaser_id", DEFAULTS["chaser_id"])), 0))
	var eased: Dictionary = mercy_config(cfg, streak)
	chase.config = adjusted_config(eased, street)
	if not is_same(eased, cfg):
		EventBus.notification_requested.emit(
			String(cfg.get("mercy_text", DEFAULTS["mercy_text"])), Color(0.55, 0.85, 0.6, 1))
	if street >= STREET_COVER_THRESHOLD:
		EventBus.notification_requested.emit(
			"🤝 Le morro te couvre — la rue se referme derrière toi.",
			Color(0.55, 0.85, 0.6, 1))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	# Spawn sur du sol libre : coincé dans un rocher ou l'eau (couture de
	# l'Arpoador), il ne bougeait pas et la fuite se gagnait en 1,4 s
	# (playtest 2026-10-08, F10). On essaie les deux côtés, de plus en plus près.
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var probe: CircleShape2D = CircleShape2D.new()
	probe.radius = 10.0
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = probe
	params.collision_mask = 1 | 4
	params.collide_with_areas = false
	var spawn_pos: Vector2 = player.global_position + Vector2(side * SPAWN_DIST, rng.randf_range(-40.0, 40.0))
	var found: bool = false
	for d in [SPAWN_DIST, 300.0, 240.0, 180.0]:
		for sd in [side, -side]:
			var cand: Vector2 = player.global_position + Vector2(sd * d, rng.randf_range(-40.0, 40.0))
			params.transform = Transform2D(0.0, cand)
			if space.intersect_shape(params, 1).is_empty():
				spawn_pos = cand
				found = true
				break
		if found:
			break
	chase.position = spawn_pos
	var world: Node = tree.current_scene.get_node_or_null("World")
	if world == null:
		world = tree.current_scene
	world.add_child(chase)
	return chase

func _cfg(key: String) -> Variant:
	return config.get(key, DEFAULTS[key])

func _chrono_source() -> String:
	return "chase:%s" % String(_cfg("chaser_id"))

func _ready() -> void:
	add_to_group("cobrador_chase")
	collision_layer = 0
	collision_mask = 1 | 4  # murs + eau : il court comme un piéton, pas sur la baie
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)
	_build_visual()
	EventBus.chase_started.emit(String(_cfg("chaser_id")))
	EventBus.notification_requested.emit(String(_cfg("spotted_text")), Color(0.95, 0.4, 0.35, 1))

# Même feuille 3×3 que le joueur (CharacterSpriteFactory), config déterministe
# par seed : chaque poursuivant a toujours la même tête, on le reconnaît de loin.
func _build_visual() -> void:
	_sprite = Sprite2D.new()
	var sprite_config: Dictionary = CharacterSpriteFactory.random_config(hash(String(_cfg("sprite_seed"))))
	_sprite.texture = CharacterSpriteFactory.build_sheet(sprite_config)
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sf: float = 48.0 / float(CharacterSpriteFactory.CELL_H)
	_sprite.scale = Vector2(sf, sf)
	add_child(_sprite)

func _physics_process(delta: float) -> void:
	if _done:
		return
	var player: Node2D = GameManager.player as Node2D
	if player == null or not is_instance_valid(player):
		_finish(false, false)
		return
	# Pendant un dialogue/cutscene le joueur est gelé : on gèle aussi (pas de
	# capture gratuite pendant qu'il lit).
	if DialogueBridge.is_active() or CutsceneRunner.is_running():
		velocity = Vector2.ZERO
		return
	_elapsed += delta
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var give_up_sec: float = float(_cfg("give_up_sec"))
	EventBus.chrono_updated.emit(_chrono_source(), String(_cfg("chrono_label")),
		max(give_up_sec - _elapsed, 0.0))
	# Abandon par distance seulement après 3 s : pas de fuite « gratuite » à
	# la seconde où il te repère.
	if (dist >= float(_cfg("give_up_dist")) and _elapsed >= 3.0) or _elapsed >= give_up_sec:
		_escape()
		return
	if dist <= CATCH_DIST:
		_catch(player)
		return
	var tired: bool = _elapsed >= float(_cfg("tire_after_sec"))
	var speed: float = float(_cfg("speed_tired")) if tired else float(_cfg("speed_start"))
	velocity = to_player.normalized() * speed
	move_and_slide()
	_update_visual(delta)

func _escape() -> void:
	EventBus.notification_requested.emit(String(_cfg("escaped_text")), Color(0.6, 0.9, 0.6, 1))
	var rep: int = int(_cfg("escape_rep_street"))
	if rep != 0:
		ReputationSystem.modify(ReputationSystem.Axis.STREET, rep)
	_finish(true)

func _catch(player: Node2D) -> void:
	var inv: Inventory = player.get_node_or_null("Inventory") as Inventory
	var taken: int = 0
	if inv and inv.money > 0:
		taken = clampi(maxi(int(_cfg("catch_min")), int(float(inv.money) * float(_cfg("catch_pct")))),
			1, inv.money)
		inv.spend_money(taken)
	if taken > 0:
		EventBus.notification_requested.emit(String(_cfg("caught_text")) % taken,
			Color(0.95, 0.5, 0.4, 1))
	else:
		# Poches vides : il repart avec un avertissement qui coûte de la rue.
		EventBus.notification_requested.emit(String(_cfg("broke_text")), Color(0.95, 0.5, 0.4, 1))
		var rep: int = int(_cfg("broke_rep_street"))
		if rep != 0:
			ReputationSystem.modify(ReputationSystem.Axis.STREET, rep)
	_finish(false)

func _finish(escaped: bool, emit_signal_end: bool = true) -> void:
	if _done:
		return
	_done = true
	if emit_signal_end:
		var id: String = String(_cfg("chaser_id"))
		if escaped:
			_caught_streak.erase(id)
		else:
			_caught_streak[id] = int(_caught_streak.get(id, 0)) + 1
	EventBus.chrono_cleared.emit(_chrono_source())
	if emit_signal_end:
		EventBus.chase_ended.emit(String(_cfg("chaser_id")), escaped)
	queue_free()

func _update_visual(delta: float) -> void:
	if _sprite == null:
		return
	_anim_accum += delta * ANIM_FPS
	var col: int = WALK_CYCLE[int(_anim_accum) % WALK_CYCLE.size()]
	var row: int = 0
	if absf(velocity.x) > absf(velocity.y):
		row = 2
		_sprite.flip_h = velocity.x < 0.0
	else:
		row = 1 if velocity.y < 0.0 else 0
		_sprite.flip_h = false
	_sprite.region_rect = Rect2(
		col * CharacterSpriteFactory.CELL_W,
		row * CharacterSpriteFactory.CELL_H,
		CharacterSpriteFactory.CELL_W,
		CharacterSpriteFactory.CELL_H)
