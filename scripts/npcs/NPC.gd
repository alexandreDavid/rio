class_name NPC
extends CharacterBody2D

@export var data: NPCData
@export var interactable: Interactable

# Constantes d'animation d'interaction.
const PUNCH_SCALE: float = 1.12
const PUNCH_DURATION: float = 0.18

# Si un PNG individuel est trouvé à res://assets/sprites/npcs/<id>.png, on l'utilise
# à la place de la région de l'atlas. Le sprite est alors auto-redimensionné pour
# faire SPRITE_TARGET_HEIGHT pixels de haut à l'écran — calé sur la taille du joueur
# (sprite player 256×256 × scale 0.1875 = 48 px) pour des proportions homogènes.
const SPRITE_TARGET_HEIGHT: float = 48.0
const NPC_SPRITES_DIR: String = "res://assets/sprites/npcs/"

# Sprite-sheet 3 colonnes × 3 lignes (9 cellules) :
#   Colonne 0 = idle (stoppé dans la direction)
#   Colonne 1 = pas (gauche)
#   Colonne 2 = pas (droite)
#   Ligne 0 = DOWN (face caméra) / 1 = UP (de dos) / 2 = RIGHT
# La direction LEFT est obtenue en flippant horizontalement la ligne RIGHT.
enum Direction { DOWN = 0, UP = 1, RIGHT = 2, LEFT = 3 }
const FRAMES_PER_DIRECTION: int = 3
const SHEET_ROWS: int = 3  # 3 directions stockées (LEFT = flip de RIGHT)
const WALK_FRAME_DURATION: float = 0.18

var _sprite: Node = null
var _sprite_base_scale: Vector2 = Vector2.ONE
var _has_walk_sheet: bool = false
var _facing: int = Direction.DOWN
var _walk_tween: Tween = null

# Approche du joueur à l'interaction : un NPC inerte fait un pas dans la direction
# du joueur si la distance dépasse APPROACH_TRIGGER_DIST. Donne du vivant aux échanges.
const APPROACH_TRIGGER_DIST: float = 70.0
const APPROACH_STOP_DIST: float = 36.0
const APPROACH_SPEED: float = 140.0
# Plafond dur : même si le NPC est très loin, il rejoint le joueur en au plus
# ce temps (il accélère au besoin). Évite l'attente de plusieurs secondes.
const APPROACH_MAX_TIME: float = 1.4
var _approach_tween: Tween = null

# Mode escort/follow : NPC suit le joueur. Activé par les quêtes d'escorte
# (Contessa, TouristVIP, DonSalvatore). Le NPC marche à FOLLOW_SPEED jusqu'à
# FOLLOW_DISTANCE du joueur, puis s'arrête. Utilise move_and_slide pour les murs.
# Cross-district : à district_changed, le NPC se téléporte près du joueur dans
# le nouveau district (offset latéral). Sinon il resterait coincé dans l'ancien.
const FOLLOW_DEFAULT_DISTANCE: float = 56.0
const FOLLOW_SPEED: float = 90.0
const FOLLOW_STOP_HYSTERESIS: float = 12.0  # évite le jitter à la limite
const FOLLOW_TELEPORT_OFFSET: Vector2 = Vector2(-48.0, 8.0)
var _following: bool = false
var _follow_distance: float = FOLLOW_DEFAULT_DISTANCE
var _follow_district_listener_connected: bool = false

func _ready() -> void:
	# Fallback si @export n'a pas résolu (hérédité de scène + script override).
	if interactable == null:
		interactable = get_node_or_null("Interactable") as Interactable
	if interactable:
		interactable.prompt = "Parler"
		interactable.interacted.connect(_on_interacted)
	else:
		push_error("[NPC:%s] PAS D'INTERACTABLE — l'enfant 'Interactable' est introuvable" % name)
	# Positionnement dynamique : si le NPC a un id déclaré, il est piloté par le scheduler.
	if data and data.id != "":
		NPCScheduler.register(data.id, self)
	_setup_visual_polish()
	_setup_quest_indicator()

# --- Indicateur de quête ("!" au-dessus de la tête) ---

const QI_FONT_SIZE: int = 22
const QI_OFFSET_Y: float = -52.0
const QI_BOB_AMPLITUDE: float = 2.5
const QI_VISIBLE_DISTANCE: float = 140.0
const QI_CHECK_INTERVAL: float = 0.4   # throttle : check distance + état tous les 0.4s

var _qi_label: Label = null
var _qi_has_available: bool = false
var _qi_last_check: float = 0.0

func _setup_quest_indicator() -> void:
	# Un seul Label visuel, créé en code pour ne pas modifier la scène NPC.
	_qi_label = Label.new()
	_qi_label.name = "QuestIndicator"
	_qi_label.text = "!"
	_qi_label.position = Vector2(-6.0, QI_OFFSET_Y)
	_qi_label.add_theme_font_size_override("font_size", QI_FONT_SIZE)
	_qi_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1))
	_qi_label.add_theme_color_override("font_outline_color", Color(0.4, 0.1, 0.05, 0.95))
	_qi_label.add_theme_constant_override("outline_size", 3)
	_qi_label.z_index = 100
	_qi_label.visible = false
	add_child(_qi_label)
	# Refresh sur les transitions d'état des quêtes (accept/complete).
	EventBus.quest_accepted.connect(_qi_refresh_availability)
	EventBus.quest_completed.connect(_qi_refresh_availability)
	EventBus.act_changed.connect(_qi_refresh_availability_from_act)
	_qi_refresh_availability("")

func _qi_refresh_availability(_quest_id: String) -> void:
	if data == null or data.id == "":
		_qi_has_available = false
		return
	# Cherche une quête disponible dont le NPC est le giver.
	_qi_has_available = false
	for q in QuestManager._quests.values():
		if q is Quest and (q as Quest).giver_npc_id == data.id and QuestManager.is_available((q as Quest).id):
			_qi_has_available = true
			break

func _qi_refresh_availability_from_act(_act: int) -> void:
	# Les quêtes peuvent devenir disponibles au passage d'acte (gating required_act).
	_qi_refresh_availability("")

func _process(_delta: float) -> void:
	if _qi_label == null:
		return
	# Throttle des checks : 2-3 fois par seconde suffit pour le visuel.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _qi_last_check >= QI_CHECK_INTERVAL:
		_qi_last_check = now
		var should_show: bool = _qi_has_available and _qi_player_nearby()
		if should_show != _qi_label.visible:
			_qi_label.visible = should_show
	# Bob vertical + léger pulse de taille pour attirer l'œil quand visible.
	if _qi_label.visible:
		_qi_label.position.y = QI_OFFSET_Y + sin(now * 5.0) * QI_BOB_AMPLITUDE
		var pulse: float = 1.0 + sin(now * 6.0) * 0.14
		_qi_label.pivot_offset = _qi_label.size / 2.0
		_qi_label.scale = Vector2(pulse, pulse)

func _qi_player_nearby() -> bool:
	if GameManager.player == null:
		return false
	return global_position.distance_to(GameManager.player.global_position) <= QI_VISIBLE_DISTANCE

# Stratégie de sprite, par ordre de priorité :
# 1. PNG individuel `assets/sprites/npcs/<id>.png` ou `<id>_walk.png` — haute
#    qualité, fait à la main, utilisé pour les NPCs majeurs (32 existants).
# 2. Région nommée dans `characters_ai.png` via NAMED_NPC_REGIONS — atlas
#    16 personnages style joueur, mappée thématiquement (cop→Ramos, chef→Padeiro…)
# 3. Région hash-pickée dans `characters_ai.png` — déterministe par id, donne
#    une variété cohérente aux NPCs non-mappés.
# 4. Fallback ultime : sprite procédural pixel-art via CharacterSpriteFactory
#    (16×24, plus pixely — utilisé pour les NPCs très secondaires).
#
# Objectif : tous les NPCs ressemblent au joueur en qualité d'art, plus de
# sprites procéduraux 16×24 chunky pour les NPCs scriptés.
const USE_PROCEDURAL_FALLBACK: bool = true

# Mapping thématique id → cellule dans characters_ai.png (1024×1024, 4×4 de
# 256×256 chacune). Adapté aux archétypes visuels disponibles.
const NAMED_NPC_REGIONS: Dictionary = {
	# Police / cops : casquette bleue (1,0)
	"ramos":          Rect2(256, 0, 256, 256),
	"policier":       Rect2(256, 0, 256, 256),
	"military_pm":    Rect2(256, 0, 256, 256),
	"pm_patrol":      Rect2(256, 0, 256, 256),
	# Chef / boulanger : toque blanche (2,0)
	"padeiro":        Rect2(512, 0, 256, 256),
	"chef_restaurant":Rect2(512, 0, 256, 256),
	# Grand-mère / Vovó : chapeau jaune (3,0)
	"vovo":           Rect2(768, 0, 256, 256),
	"mae":            Rect2(768, 0, 256, 256),
	"dona_irene":     Rect2(768, 0, 256, 256),
	# Casquette rouge / favela : (0,1)
	"tito":           Rect2(0, 256, 256, 256),
	"miguel":         Rect2(0, 256, 256, 256),
	"ze_bar":         Rect2(0, 256, 256, 256),
	# Costume mafia / consortium : (1,1)
	"don_vincenzo":   Rect2(256, 256, 256, 256),
	"consortium":     Rect2(256, 256, 256, 256),
	"magalhaes":      Rect2(256, 256, 256, 256),
	"carrasco":       Rect2(256, 256, 256, 256),
	"mendonca":       Rect2(256, 256, 256, 256),
	# Costume brun / civic : (2,1)
	"don_salvatore":  Rect2(512, 256, 256, 256),
	"otavio":         Rect2(512, 256, 256, 256),
	"jorge":          Rect2(512, 256, 256, 256),
	# Padre / religieux : (3,1) chapeau bleu
	"padre":          Rect2(768, 256, 256, 256),
	# Blond chemise blanche : (0,2)
	"lucas":          Rect2(0, 512, 256, 256),
	"contessa":       Rect2(0, 512, 256, 256),
	"tourist_vip":    Rect2(0, 512, 256, 256),
	# Lady headscarf vert : (1,2)
	"helena_curator": Rect2(256, 512, 256, 256),
	"yara":           Rect2(256, 512, 256, 256),
	"olga_mendez":    Rect2(256, 512, 256, 256),
	"vendeuse_boutique": Rect2(256, 512, 256, 256),
	# Yellow hat suit : (2,2) — agente Silva / madame Dubois
	"madame_dubois":  Rect2(512, 512, 256, 256),
	"beatriz":        Rect2(512, 512, 256, 256),
	# Bald casquette bleue : (3,2) — Seu João, vieux
	"seu_joao":       Rect2(768, 512, 256, 256),
	"bruno":          Rect2(768, 512, 256, 256),
	"pecheur":        Rect2(768, 512, 256, 256),
	"mateus":         Rect2(768, 512, 256, 256),
	"caldeira":       Rect2(768, 512, 256, 256),
	# Muscle tank blanc : (0,3) — sportifs
	"diego":          Rect2(0, 768, 256, 256),
	"musicien":       Rect2(0, 768, 256, 256),
	"joggeur":        Rect2(0, 768, 256, 256),
	# Bandana blanc : (1,3) — pêcheurs / outsider
	"ivan":           Rect2(256, 768, 256, 256),
	"bandeira":       Rect2(256, 768, 256, 256),
	"roberto_maia":   Rect2(256, 768, 256, 256),
	"farmaceutico":   Rect2(256, 768, 256, 256),
	# Rouge tanné : (2,3) — jeunes femmes
	"camila":         Rect2(512, 768, 256, 256),
	"sofia":          Rect2(512, 768, 256, 256),
	# Vert jaune back : (3,3) — neutre
	"coconut_vendor": Rect2(768, 768, 256, 256),
	"concierge":      Rect2(768, 768, 256, 256),
	"bar_patrao":     Rect2(768, 768, 256, 256),
}

func _setup_visual_polish() -> void:
	# Repère le sprite principal pour le scale-punch d'interaction.
	_sprite = get_node_or_null("Sprite2D")
	if _sprite is Sprite2D and data and data.id != "":
		# Cascade de stratégies : PNG → région nommée → hash atlas → procédural.
		if not _try_load_individual_sprite():
			if not _try_apply_atlas_region():
				if USE_PROCEDURAL_FALLBACK:
					_setup_procedural_sprite()
	if _sprite is Node2D:
		_sprite_base_scale = (_sprite as Node2D).scale
	_spawn_shadow()

# Applique une région de characters_ai.png mappée par id, ou hash-pickée
# parmi les 16 cellules disponibles si non mappée. Garde l'échelle d'origine
# du Sprite2D dans NPC.tscn (256→48 px = scale 0.1875).
func _try_apply_atlas_region() -> bool:
	if not (_sprite is Sprite2D) or data == null or data.id == "":
		return false
	var spr: Sprite2D = _sprite as Sprite2D
	var region: Rect2
	if NAMED_NPC_REGIONS.has(data.id):
		region = NAMED_NPC_REGIONS[data.id]
	else:
		# Hash-pick déterministe parmi les 16 cellules (4×4 de 256×256).
		var h: int = abs(data.id.hash())
		var col: int = (h % 4) * 256
		var row: int = ((h / 4) % 4) * 256
		region = Rect2(col, row, 256, 256)
	spr.region_enabled = true
	spr.region_rect = region
	spr.hframes = 1
	spr.vframes = 1
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(0.1875, 0.1875)
	return true

# Génère et applique un sprite pixel-art via CharacterSpriteFactory. Le NPC
# affiche par défaut sa cellule DOWN/idle (1ère colonne, 1ère ligne).
# Synchronisé avec la factory (taille de cellule unique source de vérité).
const PROCEDURAL_CELL_W: int = CharacterSpriteFactory.CELL_W
const PROCEDURAL_CELL_H: int = CharacterSpriteFactory.CELL_H

func _setup_procedural_sprite() -> void:
	var spr: Sprite2D = _sprite as Sprite2D
	var factory: GDScript = preload("res://scripts/world/CharacterSpriteFactory.gd")
	var config: Dictionary = factory.config_for_npc(data.id)
	var sheet: ImageTexture = factory.build_sheet(config)
	spr.texture = sheet
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, PROCEDURAL_CELL_W, PROCEDURAL_CELL_H)
	# Scale pour matcher SPRITE_TARGET_HEIGHT à partir de la hauteur de cellule.
	var s: float = SPRITE_TARGET_HEIGHT / float(PROCEDURAL_CELL_H)
	spr.scale = Vector2(s, s)
	# LINEAR : feuille haute résolution réduite en douceur (rendu lissé,
	# cohérent avec le joueur — plus le pixel-art chunky d'avant).
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

# Helper static : charge un sprite individuel (idle ou walk-sheet 3×3) depuis
# assets/sprites/npcs/<id>.png ou <id>_walk.png et l'applique au Sprite2D fourni.
# Renvoie true si une texture a été chargée, false sinon (pas de fichier).
# Utilisable depuis n'importe quel script (PMPatrol, Customer…).
static func try_load_sprite(sprite: Sprite2D, npc_id: String, target_height: float = 48.0) -> bool:
	if sprite == null or npc_id == "":
		return false
	var walk_path: String = "%s%s_walk.png" % [NPC_SPRITES_DIR, npc_id]
	var idle_path: String = "%s%s.png" % [NPC_SPRITES_DIR, npc_id]
	var path: String = ""
	var is_walk_sheet: bool = false
	if ResourceLoader.exists(walk_path):
		path = walk_path
		is_walk_sheet = true
	elif ResourceLoader.exists(idle_path):
		path = idle_path
	else:
		return false
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return false
	sprite.texture = tex
	sprite.region_enabled = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if is_walk_sheet:
		sprite.hframes = FRAMES_PER_DIRECTION
		sprite.vframes = SHEET_ROWS
		sprite.frame = 0
	else:
		sprite.hframes = 1
		sprite.vframes = 1
	var cell_h: float = float(tex.get_height()) / (float(SHEET_ROWS) if is_walk_sheet else 1.0)
	if cell_h > 0.0:
		var s: float = target_height / cell_h
		sprite.scale = Vector2(s, s)
	return true

func _try_load_individual_sprite() -> bool:
	if data == null or data.id == "" or not (_sprite is Sprite2D):
		return false
	# Priorité : sprite-sheet de marche, sinon sprite idle simple.
	var walk_path: String = "%s%s_walk.png" % [NPC_SPRITES_DIR, data.id]
	var idle_path: String = "%s%s.png" % [NPC_SPRITES_DIR, data.id]
	var path: String = ""
	var is_walk_sheet: bool = false
	if ResourceLoader.exists(walk_path):
		path = walk_path
		is_walk_sheet = true
	elif ResourceLoader.exists(idle_path):
		path = idle_path
	else:
		return false
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return false
	var sprite: Sprite2D = _sprite as Sprite2D
	sprite.texture = tex
	sprite.region_enabled = false
	# NEAREST : garde les pixels nets quand on scale (sinon Godot floute par défaut).
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sheet 3 cols × 3 rows : on cale hframes/vframes et on démarre en idle face caméra.
	if is_walk_sheet:
		sprite.hframes = FRAMES_PER_DIRECTION  # 3
		sprite.vframes = SHEET_ROWS            # 3
		sprite.frame = int(Direction.DOWN) * FRAMES_PER_DIRECTION
		_has_walk_sheet = true
	else:
		sprite.hframes = 1
		sprite.vframes = 1
	# Redimensionne pour matcher la hauteur cible : cellule = tex.height / SHEET_ROWS.
	var cell_h: float = float(tex.get_height()) / (float(SHEET_ROWS) if is_walk_sheet else 1.0)
	if cell_h > 0.0:
		var s: float = SPRITE_TARGET_HEIGHT / cell_h
		sprite.scale = Vector2(s, s)
	return true

func _spawn_shadow() -> void:
	# Ombre ovale plate sous le NPC pour l'ancrer au sol.
	if get_node_or_null("Shadow") != null:
		return
	var shadow: ColorRect = ColorRect.new()
	shadow.name = "Shadow"
	shadow.offset_left = -14.0
	shadow.offset_top = 6.0
	shadow.offset_right = 14.0
	shadow.offset_bottom = 12.0
	shadow.color = Color(0.0, 0.0, 0.0, 0.28)
	shadow.z_index = -1
	# Ajouté en premier pour passer SOUS les autres enfants visuels.
	add_child(shadow)
	move_child(shadow, 0)

func _punch_scale() -> void:
	if not (_sprite is Node2D):
		return
	var node: Node2D = _sprite as Node2D
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", _sprite_base_scale * PUNCH_SCALE, PUNCH_DURATION * 0.4)
	t.tween_property(node, "scale", _sprite_base_scale, PUNCH_DURATION * 0.6)

# --- API d'animation walk-sheet (no-op si <id>_walk.png absent) ---

# Renvoie la ligne stockée + le flip nécessaire pour afficher une direction.
# LEFT n'est pas dessiné : on prend la ligne RIGHT et on flippe horizontalement.
func _row_and_flip_for(dir: int) -> Array:
	if dir == Direction.LEFT:
		return [Direction.RIGHT, true]
	return [dir, false]

# Tourne le NPC vers une direction, sans le faire marcher.
func face(dir: int) -> void:
	if not _has_walk_sheet or not (_sprite is Sprite2D):
		return
	stop_walk()
	_facing = dir
	var info: Array = _row_and_flip_for(dir)
	var sprite: Sprite2D = _sprite as Sprite2D
	sprite.flip_h = info[1]
	sprite.frame = int(info[0]) * FRAMES_PER_DIRECTION

# Boucle l'animation de marche dans la direction donnée jusqu'à un stop_walk().
# Cycle : pas-gauche → idle → pas-droit → idle (mouvement à 4 temps avec 3 frames).
func play_walk(dir: int) -> void:
	if not _has_walk_sheet or not (_sprite is Sprite2D):
		return
	stop_walk()
	_facing = dir
	var info: Array = _row_and_flip_for(dir)
	var sprite: Sprite2D = _sprite as Sprite2D
	sprite.flip_h = info[1]
	var base: int = int(info[0]) * FRAMES_PER_DIRECTION
	var idle_f: int = base + 0
	var step_l: int = base + 1
	var step_r: int = base + 2
	_walk_tween = create_tween().set_loops()
	_walk_tween.tween_callback(func(): sprite.frame = step_l)
	_walk_tween.tween_interval(WALK_FRAME_DURATION)
	_walk_tween.tween_callback(func(): sprite.frame = idle_f)
	_walk_tween.tween_interval(WALK_FRAME_DURATION)
	_walk_tween.tween_callback(func(): sprite.frame = step_r)
	_walk_tween.tween_interval(WALK_FRAME_DURATION)
	_walk_tween.tween_callback(func(): sprite.frame = idle_f)
	_walk_tween.tween_interval(WALK_FRAME_DURATION)

# Stoppe l'animation de marche et revient sur la frame idle de la direction courante.
func stop_walk() -> void:
	if _walk_tween and _walk_tween.is_valid():
		_walk_tween.kill()
	_walk_tween = null
	if _has_walk_sheet and _sprite is Sprite2D:
		var info: Array = _row_and_flip_for(_facing)
		var sprite: Sprite2D = _sprite as Sprite2D
		sprite.flip_h = info[1]
		sprite.frame = int(info[0]) * FRAMES_PER_DIRECTION

func _exit_tree() -> void:
	stop_walk()
	if data and data.id != "":
		NPCScheduler.unregister(data.id)

# --- Approche du joueur à l'interaction ---

# Direction dominante (DOWN/UP/LEFT/RIGHT) du NPC vers le joueur.
func _dir_toward_player() -> int:
	if GameManager.player == null:
		return Direction.DOWN
	var to_p: Vector2 = GameManager.player.global_position - global_position
	if abs(to_p.x) > abs(to_p.y):
		return Direction.RIGHT if to_p.x > 0 else Direction.LEFT
	return Direction.DOWN if to_p.y > 0 else Direction.UP

# Si le joueur est loin, le NPC fait un pas vers lui (s'arrête à APPROACH_STOP_DIST)
# avec animation walk-sheet. Awaitable depuis les sous-classes :
#     await _approach_player_if_far()
#     DialogueBridge.start_dialogue(...)
func _approach_player_if_far() -> void:
	if _following:
		return  # Déjà collé en mode escort.
	if GameManager.player == null:
		return
	var to_p: Vector2 = GameManager.player.global_position - global_position
	var dist: float = to_p.length()
	if dist <= APPROACH_TRIGGER_DIST:
		face(_dir_toward_player())
		return
	var step: float = dist - APPROACH_STOP_DIST
	if step <= 0.0:
		return
	var target: Vector2 = global_position + to_p.normalized() * step
	play_walk(_dir_toward_player())
	if _approach_tween and _approach_tween.is_valid():
		_approach_tween.kill()
	_approach_tween = create_tween()
	var approach_time: float = minf(step / APPROACH_SPEED, APPROACH_MAX_TIME)
	_approach_tween.tween_property(self, "global_position", target, approach_time)
	await _approach_tween.finished
	stop_walk()
	face(_dir_toward_player())

# --- Mode escort/follow ---

# Démarre le mode escort : le NPC suit le joueur jusqu'à `distance` pixels.
# Utilisé par les quêtes escort_contessa, tourist_vip_tour, consortium_airport_pickup.
func start_following(distance: float = FOLLOW_DEFAULT_DISTANCE) -> void:
	_following = true
	_follow_distance = distance
	if not _follow_district_listener_connected:
		DistrictManager.district_changed.connect(_on_follow_district_changed)
		_follow_district_listener_connected = true

func stop_following() -> void:
	_following = false
	velocity = Vector2.ZERO
	stop_walk()
	if _follow_district_listener_connected:
		DistrictManager.district_changed.disconnect(_on_follow_district_changed)
		_follow_district_listener_connected = false

# Téléporte le NPC près du joueur quand le joueur change de district. Sans ça,
# le NPC resterait dans l'ancien district et la quête d'escort serait cassée.
func _on_follow_district_changed(_district_id: String) -> void:
	if not _following or GameManager.player == null:
		return
	# Petit délai pour laisser le joueur arriver / les caméras se caler.
	await get_tree().process_frame
	if not is_instance_valid(self) or GameManager.player == null:
		return
	global_position = GameManager.player.global_position + FOLLOW_TELEPORT_OFFSET
	velocity = Vector2.ZERO
	stop_walk()
	face(_dir_toward_player())

func _physics_process(_delta: float) -> void:
	if not _following:
		return
	if GameManager.player == null:
		return
	if DialogueBridge.is_active():
		# Pendant un dialogue, le NPC reste planté.
		if velocity != Vector2.ZERO:
			velocity = Vector2.ZERO
			stop_walk()
		return
	var to_p: Vector2 = GameManager.player.global_position - global_position
	var dist: float = to_p.length()
	# Hystéresis : on s'arrête à follow_distance, on repart à follow_distance + threshold.
	if dist <= _follow_distance:
		if velocity != Vector2.ZERO:
			velocity = Vector2.ZERO
			stop_walk()
			face(_dir_toward_player())
		return
	if dist <= _follow_distance + FOLLOW_STOP_HYSTERESIS and velocity == Vector2.ZERO:
		return
	var dir_vec: Vector2 = to_p.normalized()
	velocity = dir_vec * FOLLOW_SPEED
	move_and_slide()
	var dir: int = _dir_toward_player()
	if _walk_tween == null or not _walk_tween.is_valid() or dir != _facing:
		play_walk(dir)

func _on_interacted(_by: Node) -> void:
	print("[NPC:%s] _on_interacted" % name)
	_punch_scale()
	if data == null or data.ink_knot == "":
		push_warning("NPC %s: no data or ink_knot" % name)
		return
	await _approach_player_if_far()
	DialogueBridge.start_dialogue(data.id, data.ink_knot)
