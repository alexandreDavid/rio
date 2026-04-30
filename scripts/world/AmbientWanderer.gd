class_name AmbientWanderer
extends Node2D

# Passant ambiant — style "premiers jeux Pokemon" (Gen 1/2). NPCs majoritairement
# immobiles, qui font occasionnellement un demi-tour aléatoire pour donner un
# signe de vie. Pas de salutations spontanées, pas de réaction au passage du
# joueur (l'interaction est explicite — touche A sur eux pour leur parler).
# Trois modes de déplacement :
#  - `path` : aller-retour entre waypoints fixes (mode marche minimal).
#  - `roam_zone` (Rect2 non-vide) : pioche des destinations aléatoires.
#  - `static` (path vide ET roam_zone vide ET stationary=true) : reste sur place
#    avec retournement aléatoire toutes les 3-8s.
#
# Style global toggle : POKEMON_STYLE_DEFAULT (en-tête). Quand vrai, désactive
# bulle de salutation, look-at-player, séparation, et atténue le bob — les
# wanderers sont quasi-décoratifs comme dans les premiers Pokemon.
# Phase de la journée : `active_phases` (vide = toujours actif).
const POKEMON_STYLE_DEFAULT: bool = true

# Toggle global de rendu. Mis à false, tous les AmbientWanderer du jeu sont
# cachés et n'occupent aucun CPU. Les .tscn ne sont pas modifiés — les
# instances restent dans l'arbre de scène mais invisibles. Utile quand on
# n'aime pas le rendu ColorRect-composé et qu'on attend un set d'assets.
# Pour les remettre, basculer à true.
const RENDER_DEFAULT: bool = false

@export var color: Color = Color(0.85, 0.55, 0.4, 1)
@export var skin_color: Color = Color(0.92, 0.78, 0.62, 1)
@export var hair_color: Color = Color(0.18, 0.12, 0.08, 1)
@export var size: Vector2 = Vector2(10, 18)

# Mode 1 : waypoints fixes (rétro-compatible avec scènes existantes).
@export var path: Array[Vector2] = []

# Mode 2 : roam libre dans une boîte (en coords locales par rapport au spawn).
# Si la taille est non-nulle, ce mode supplante `path`.
@export var roam_zone: Rect2 = Rect2()

# Mode 3 : stationnaire — pas de déplacement, juste l'idle bob.
@export var stationary: bool = false

@export var speed: float = 28.0

# Pause aux waypoints / nouvelles destinations. La pause effective est tirée
# dans [pause - jitter, pause + jitter] si jitter > 0, ce qui casse la
# régularité mécanique des allers-retours.
@export var pause_at_waypoints: float = 1.4
@export var pause_random_jitter: float = 0.0

@export var bob_strength: float = 1.2
@export var hat: bool = false
@export var hat_color: Color = Color(0.85, 0.85, 0.4, 1)

# Quand le joueur s'approche à moins de cette distance, le passant interrompt
# sa marche et tourne le sprite vers lui (curiosité passive). 0 = désactivé.
@export var look_at_player_distance: float = 0.0

# Phases de la journée pendant lesquelles ce passant est visible/actif
# (TimeOfDay.Phase : 0=MORNING, 1=AFTERNOON, 2=EVENING). Vide = toujours actif.
@export var active_phases: Array[int] = []

const STATE_MOVE: int = 0
const STATE_PAUSE: int = 1
const STATE_LOOKING: int = 2

# Réactions du passant quand le joueur passe à portée. Choisi à partir de la
# voie endgame + réputation civique/charisma/street.
enum Greeting { NONE, WAVE, BOW, AVOID }

const GREETING_DURATION: float = 1.4
# Distance min entre wanderers pour la séparation douce (re-tirage de cible).
const ROAM_SEPARATION: float = 18.0
const ROAM_RETRY_COUNT: int = 3

# Registre statique des wanderers actifs (utilisé par la séparation douce). Les
# instances s'inscrivent à _ready et se désinscrivent à _exit_tree.
static var _registry: Array = []

var _current: int = 0
var _state: int = STATE_MOVE
var _pause_until: float = 0.0
var _local_target: Vector2 = Vector2.ZERO
var _bob_t: float = 0.0
var _walk_t: float = 0.0
var _facing: int = 1  # 1 = right, -1 = left (legacy)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_position: Vector2 = Vector2.ZERO  # ancre pour roam_zone

# Direction 4-axes style Pokemon. UP montre l'arrière de la tête (couleur cheveux),
# DOWN/LEFT/RIGHT montrent le visage (couleur peau).
const DIR_DOWN: int = 0
const DIR_UP: int = 1
const DIR_RIGHT: int = 2
const DIR_LEFT: int = 3
var _facing_4: int = DIR_DOWN

# Retournement aléatoire style Pokemon — un NPC stationnaire change son facing
# de temps en temps pour montrer qu'il est vivant sans être réactif.
const POKEMON_TURN_INTERVAL_MIN: float = 3.0
const POKEMON_TURN_INTERVAL_MAX: float = 8.0
var _next_turn_at: float = 0.0

# État de la salutation en cours (visuelle uniquement, ne bloque pas la marche).
var _greeting_kind: int = Greeting.NONE
var _greeting_until: float = 0.0
var _greeting_started_at: float = 0.0
var _was_looking: bool = false  # détection de la transition look → look
var _greeting_bubble: Label = null  # bulle de texte créée en code (pas dans la scène)

# Phrases dites selon le type de salutation. Phase de la journée modifie le
# greeting WAVE pour Bom dia/Boa tarde/Boa noite.
const WAVE_PHRASES: Dictionary = {
	0: ["Bom dia, sobrinho!", "Olá!", "Tudo bem?", "Salve!"],         # MORNING
	1: ["Boa tarde!", "E aí, sobrinho!", "Tudo joia?", "Beleza!"],   # AFTERNOON
	2: ["Boa noite!", "Sobrinho!", "Salve, freguês!"],                # EVENING
}
const BOW_PHRASES: Array[String] = ["Coronel.", "Senhor.", "Vossa Excelência."]
const SALUTE_PHRASES: Array[String] = ["Capitão!", "Chefe!", "Senhor agente!"]

@onready var sprite: Node2D = $Sprite
@onready var body: ColorRect = $Sprite/Body
@onready var head: ColorRect = $Sprite/Head
@onready var hair: ColorRect = $Sprite/Hair
@onready var hat_rect: ColorRect = $Sprite/Hat
@onready var leg_l: ColorRect = $Sprite/LegL
@onready var leg_r: ColorRect = $Sprite/LegR
@onready var arm_l: ColorRect = $Sprite/ArmL
@onready var arm_r: ColorRect = $Sprite/ArmR
@onready var shadow: ColorRect = $Shadow

func _ready() -> void:
	_rng.randomize()
	_spawn_position = position
	# Toggle global : si RENDER_DEFAULT est false, on cache la node entière et
	# on coupe son _process. Aucun coût CPU, les .tscn restent intacts pour
	# pouvoir réactiver d'un changement de constante quand on aura un set
	# d'assets propres.
	if not RENDER_DEFAULT:
		visible = false
		set_process(false)
		return
	# Mode Pokemon : neutralise les comportements réactifs (look_at + bulle +
	# bob trop visible). Les wanderers deviennent décoratifs, on parle aux
	# NPCs scriptés via la touche A — comme dans les premiers Pokemon.
	if POKEMON_STYLE_DEFAULT:
		look_at_player_distance = 0.0
		bob_strength = min(bob_strength, 0.3)
	_layout_sprite()
	if not POKEMON_STYLE_DEFAULT:
		_setup_greeting_bubble()
	# Initialise la cible selon le mode.
	if _uses_roam_zone():
		_local_target = _pick_random_in_zone()
	elif not stationary:
		if path.is_empty():
			path = [Vector2(-30, 0), Vector2(30, 0)]
		_local_target = path[_current]
	else:
		_schedule_next_pokemon_turn()
	# Phase awareness : abonne-toi si filtre actif.
	if not active_phases.is_empty():
		EventBus.time_of_day_changed.connect(_on_phase_changed)
		_apply_phase_visibility(TimeOfDay.current_phase)
	_registry.append(self)

# Programme le prochain demi-tour aléatoire pour un NPC stationnaire.
func _schedule_next_pokemon_turn() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_next_turn_at = now + _rng.randf_range(POKEMON_TURN_INTERVAL_MIN, POKEMON_TURN_INTERVAL_MAX)

# Applique l'orientation 4-axes au sprite : DOWN/RIGHT/LEFT face visible
# (skin_color sur la tête + cheveux en sliver), UP montre l'arrière de la tête
# (head colorée en hair_color, sliver de cheveux masqué pour ne pas dépasser).
func _apply_facing_4(dir: int) -> void:
	_facing_4 = dir
	if sprite == null:
		return
	match dir:
		DIR_DOWN:
			sprite.scale.x = 1.0
			if head:
				head.color = skin_color
			if hair:
				hair.visible = hair_color.a > 0.0
			_facing = 1
		DIR_UP:
			sprite.scale.x = 1.0
			if head:
				head.color = hair_color  # back-of-head : tout cheveux
			if hair:
				hair.visible = false  # déjà couvert par la tête
			_facing = 1
		DIR_RIGHT:
			sprite.scale.x = 1.0
			if head:
				head.color = skin_color
			if hair:
				hair.visible = hair_color.a > 0.0
			_facing = 1
		DIR_LEFT:
			sprite.scale.x = -1.0
			if head:
				head.color = skin_color
			if hair:
				hair.visible = hair_color.a > 0.0
			_facing = -1

# Direction la plus saillante d'un vecteur (utile pour walk-by-velocity).
func _direction_from_vector(v: Vector2) -> int:
	if abs(v.x) > abs(v.y):
		return DIR_RIGHT if v.x > 0 else DIR_LEFT
	return DIR_DOWN if v.y > 0 else DIR_UP

# Crée une petite Label au-dessus de la tête, masquée par défaut. Animée par
# `_process` (alpha fade in/out) pendant la salutation.
func _setup_greeting_bubble() -> void:
	_greeting_bubble = Label.new()
	_greeting_bubble.name = "GreetingBubble"
	_greeting_bubble.position = Vector2(-40.0, -size.y - 14.0)
	_greeting_bubble.size = Vector2(80.0, 14.0)
	_greeting_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_greeting_bubble.add_theme_font_size_override("font_size", 9)
	_greeting_bubble.add_theme_color_override("font_color", Color(0.98, 0.95, 0.82, 1))
	_greeting_bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_greeting_bubble.add_theme_constant_override("outline_size", 3)
	_greeting_bubble.modulate.a = 0.0
	_greeting_bubble.z_index = 100
	# `scale.x` du sprite se retourne quand le passant change de direction —
	# on garde la bulle non miroir en la mettant hors de Sprite.
	add_child(_greeting_bubble)

func _exit_tree() -> void:
	_registry.erase(self)

func _uses_roam_zone() -> bool:
	return roam_zone.size.x > 0.0 and roam_zone.size.y > 0.0

func _on_phase_changed(phase: int) -> void:
	_apply_phase_visibility(phase)

func _apply_phase_visibility(phase: int) -> void:
	var active: bool = active_phases.is_empty() or active_phases.has(phase)
	visible = active
	# Couper le _process quand caché évite les ticks inutiles.
	set_process(active)

func _layout_sprite() -> void:
	# Toutes les pièces sont positionnées par rapport à un sprite de hauteur `size.y`.
	# Body occupe les 55 % du bas (hors jambes), tête les 30 % du haut.
	var w: float = size.x
	var h: float = size.y
	var leg_h: float = h * 0.20
	var body_h: float = h * 0.42
	var head_h: float = h * 0.28
	var hair_h: float = h * 0.10
	var head_w: float = w * 0.78
	var leg_w: float = w * 0.32
	var arm_w: float = w * 0.18
	var arm_h: float = h * 0.30
	# Body
	if body:
		body.size = Vector2(w, body_h)
		body.position = Vector2(-w / 2.0, head_h - h / 2.0)
		body.color = color
	# Head
	if head:
		head.size = Vector2(head_w, head_h)
		head.position = Vector2(-head_w / 2.0, hair_h - h / 2.0)
		head.color = skin_color
	# Hair (sliver au-dessus de la tête)
	if hair:
		hair.size = Vector2(head_w, hair_h)
		hair.position = Vector2(-head_w / 2.0, -h / 2.0)
		hair.color = hair_color
		hair.visible = hair_color.a > 0.0
	# Hat (optionnel — recouvre les cheveux)
	if hat_rect:
		hat_rect.size = Vector2(head_w * 1.05, hair_h * 1.4)
		hat_rect.position = Vector2(-head_w * 0.525, -h / 2.0 - hair_h * 0.4)
		hat_rect.color = hat_color
		hat_rect.visible = hat
	# Bras (pendent depuis le haut du buste)
	var arm_y: float = head_h - h / 2.0
	if arm_l:
		arm_l.size = Vector2(arm_w, arm_h)
		arm_l.position = Vector2(-w / 2.0 - arm_w * 0.3, arm_y)
		arm_l.color = color
	if arm_r:
		arm_r.size = Vector2(arm_w, arm_h)
		arm_r.position = Vector2(w / 2.0 - arm_w * 0.7, arm_y)
		arm_r.color = color
	# Jambes (sous le buste, légèrement plus foncées)
	var leg_y: float = head_h + body_h - h / 2.0
	var dark_color: Color = color.darkened(0.35)
	if leg_l:
		leg_l.size = Vector2(leg_w, leg_h)
		leg_l.position = Vector2(-leg_w - w * 0.05, leg_y)
		leg_l.color = dark_color
	if leg_r:
		leg_r.size = Vector2(leg_w, leg_h)
		leg_r.position = Vector2(w * 0.05, leg_y)
		leg_r.color = dark_color
	# Ombre (ellipse simulée par un rect aplati)
	if shadow:
		shadow.size = Vector2(w * 1.25, h * 0.18)
		shadow.position = Vector2(-shadow.size.x / 2.0, h / 2.0 - shadow.size.y * 0.4)
		shadow.color = Color(0, 0, 0, 0.32)

func _process(delta: float) -> void:
	_bob_t += delta * 4.0
	# Bob vertical général du sprite (un peu de vie même stationnaire).
	if sprite:
		sprite.position.y = sin(_bob_t) * bob_strength

	# Mode Pokemon : court-circuite tous les comportements réactifs et
	# applique juste le retournement aléatoire si stationnaire.
	if POKEMON_STYLE_DEFAULT:
		_pokemon_process()
		return

	# Animation de fade de la bulle de salutation, indépendante du look state
	# (pour qu'elle puisse fade-out après que le joueur soit parti).
	_update_greeting_bubble_alpha()

	# Conscience du joueur : si à portée, on s'arrête et on tourne la tête.
	if _check_look_at_player():
		# Pose de salutation pendant la durée, sinon idle pose.
		if _greeting_kind != Greeting.NONE \
				and Time.get_ticks_msec() / 1000.0 < _greeting_until:
			_greeting_pose(_greeting_kind)
		else:
			_idle_pose()
		return

	# Si on revenait d'un look_at_player, transitionne vers move/pause normalement.
	if _state == STATE_LOOKING:
		_state = STATE_MOVE
		_was_looking = false
		_greeting_kind = Greeting.NONE

	# Mode stationnaire : juste idle, rien d'autre.
	if stationary:
		_idle_pose()
		return

	# Pause en cours.
	if _state == STATE_PAUSE:
		_idle_pose()
		if Time.get_ticks_msec() / 1000.0 >= _pause_until:
			_state = STATE_MOVE
		return

	# Mouvement vers cible.
	var to_target: Vector2 = _local_target - position
	var dist: float = to_target.length()
	if dist < 1.5:
		_advance()
		return
	var step: float = min(speed * delta, dist)
	position += to_target.normalized() * step
	# Direction visuelle.
	if to_target.x < -0.1:
		_facing = -1
	elif to_target.x > 0.1:
		_facing = 1
	if sprite:
		sprite.scale.x = _facing
	# Cycle de pas — fréquence proportionnelle à la vitesse.
	_walk_t += delta * (speed / 18.0)
	_walk_pose()

# Vrai si le joueur est à portée et qu'on doit le regarder. Met à jour _facing
# pour pointer vers lui et bascule l'état en LOOKING. Déclenche aussi une
# salutation à l'entrée dans l'état (1 fois par approche, pas en boucle).
func _check_look_at_player() -> bool:
	if look_at_player_distance <= 0.0 or GameManager.player == null:
		return false
	var player_pos: Vector2 = GameManager.player.global_position
	var d: float = global_position.distance_to(player_pos)
	if d > look_at_player_distance:
		return false
	# Première frame d'entrée dans l'état → choisis la salutation.
	if not _was_looking:
		_was_looking = true
		_state = STATE_LOOKING
		_greeting_kind = _evaluate_greeting()
		if _greeting_kind != Greeting.NONE:
			var now: float = Time.get_ticks_msec() / 1000.0
			_greeting_started_at = now
			_greeting_until = now + GREETING_DURATION
			_setup_greeting_text()
	# Tourne le sprite face au joueur — sauf en AVOID (tourne le dos).
	var face_to_player: int = 1 if player_pos.x >= global_position.x else -1
	if _greeting_kind == Greeting.AVOID \
			and Time.get_ticks_msec() / 1000.0 < _greeting_until:
		_facing = -face_to_player
	else:
		_facing = face_to_player
	if sprite:
		sprite.scale.x = _facing
	return true

# Boucle simplifiée style Pokemon Gen 1/2 :
#   - stationnaire → idle pose + retournement aléatoire toutes les 3-8 s
#   - path → marche entre waypoints sans interaction (pause à chaque end)
#   - roam_zone → marche aléatoire dans la zone (pause variable)
# Pas de bulle, pas de look-at-player, pas de séparation entre wanderers. Le
# joueur peut leur passer dessus s'il veut, ils ne se figent pas. C'est la
# touche A sur eux (via NPC scripté) qui déclenche le dialogue, pas la proximité.
func _pokemon_process() -> void:
	# Stationnaire : idle pose + retournement 4-directions occasionnel.
	if stationary:
		_idle_pose()
		var now: float = Time.get_ticks_msec() / 1000.0
		if now >= _next_turn_at:
			# 60% de chance de changer de direction, sinon on reprogramme.
			if _rng.randf() < 0.6:
				# Pioche une direction différente de la courante (sinon le
				# joueur ne voit rien).
				var new_dir: int = _facing_4
				while new_dir == _facing_4:
					new_dir = _rng.randi() % 4
				_apply_facing_4(new_dir)
			_schedule_next_pokemon_turn()
		return

	# En pause entre waypoints / cibles.
	if _state == STATE_PAUSE:
		_idle_pose()
		if Time.get_ticks_msec() / 1000.0 >= _pause_until:
			_state = STATE_MOVE
		return

	# Mouvement vers cible (path ou roam_zone). Direction 4-axes inférée
	# de la velocity pour montrer le bon profil (face / dos / profil).
	var to_target: Vector2 = _local_target - position
	var dist: float = to_target.length()
	if dist < 1.5:
		_advance()
		return
	var step: float = min(speed * get_process_delta_time(), dist)
	position += to_target.normalized() * step
	_apply_facing_4(_direction_from_vector(to_target))
	_walk_t += get_process_delta_time() * (speed / 18.0)
	_walk_pose()

# Met à jour l'alpha de la bulle : fade-in 0.2s, hold, fade-out 0.2s, dans la
# fenêtre [_greeting_started_at, _greeting_until]. Hors fenêtre = invisible.
func _update_greeting_bubble_alpha() -> void:
	if _greeting_bubble == null:
		return
	if _greeting_kind == Greeting.NONE or _greeting_bubble.text == "":
		_greeting_bubble.modulate.a = 0.0
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _greeting_started_at
	var remaining: float = _greeting_until - now
	const FADE: float = 0.2
	if elapsed < 0.0 or remaining < 0.0:
		_greeting_bubble.modulate.a = 0.0
		return
	var alpha: float = 1.0
	if elapsed < FADE:
		alpha = elapsed / FADE
	elif remaining < FADE:
		alpha = remaining / FADE
	_greeting_bubble.modulate.a = clamp(alpha, 0.0, 1.0)

# Pose le texte de la bulle selon le greeting + phase de la journée +
# voie endgame. Les WAVE deviennent "Capitão!" si voie POLICIA. Les BOW utilisent
# leur propre pool. AVOID reste silencieux (pas de bulle).
func _setup_greeting_text() -> void:
	if _greeting_bubble == null:
		return
	var phrase: String = ""
	match _greeting_kind:
		Greeting.WAVE:
			# Si voie POLICIA scellée, salutation de respect militaire.
			if CampaignManager.chosen_endgame == CampaignManager.Endgame.POLICIA:
				phrase = SALUTE_PHRASES[_rng.randi() % SALUTE_PHRASES.size()]
			else:
				var phase: int = TimeOfDay.current_phase
				var pool: Array = WAVE_PHRASES.get(phase, WAVE_PHRASES[1])
				phrase = pool[_rng.randi() % pool.size()]
		Greeting.BOW:
			phrase = BOW_PHRASES[_rng.randi() % BOW_PHRASES.size()]
		Greeting.AVOID, _:
			# Silencieux : la bulle reste vide / cachée pendant l'AVOID.
			phrase = ""
	_greeting_bubble.text = phrase
	_greeting_bubble.modulate.a = 0.0  # le fade-in s'occupe du reste

# Choisit la réaction selon la voie endgame d'abord (priorité), puis selon
# les axes de réputation.
func _evaluate_greeting() -> int:
	# Priorité : la voie scellée prend toujours le dessus.
	match CampaignManager.chosen_endgame:
		CampaignManager.Endgame.PREFEITO:
			return Greeting.BOW
		CampaignManager.Endgame.POLICIA:
			return Greeting.WAVE
		CampaignManager.Endgame.TRAFICO:
			return Greeting.AVOID
	# Sinon, la réputation décide.
	var civic: int = ReputationSystem.get_value(ReputationSystem.Axis.CIVIC)
	if civic >= 30:
		return Greeting.WAVE
	var charisma: int = ReputationSystem.get_value(ReputationSystem.Axis.CHARISMA)
	if charisma >= 50:
		return Greeting.WAVE
	var street: int = ReputationSystem.get_value(ReputationSystem.Axis.STREET)
	if street >= 30:
		return Greeting.AVOID
	return Greeting.NONE

# Applique la pose de salutation par-dessus l'idle. Appelée tant que la durée
# de la salutation n'est pas expirée.
func _greeting_pose(kind: int) -> void:
	_idle_pose()
	match kind:
		Greeting.WAVE:
			# Bras droit levé en signe de salutation.
			if arm_r:
				arm_r.position.y -= size.y * 0.45
		Greeting.BOW:
			# Tête baissée + léger fléchissement.
			if head:
				head.position.y += size.y * 0.06
			if sprite:
				sprite.position.y += 1.2
		Greeting.AVOID:
			# Tête baissée. Le sprite est déjà retourné côté opposé dans
			# _check_look_at_player.
			if head:
				head.position.y += size.y * 0.04

func _walk_pose() -> void:
	if leg_l == null or leg_r == null:
		return
	var swing: float = sin(_walk_t * 2.0 * PI / 0.6) * 1.6
	# Décalage vertical opposé : une jambe avance pendant que l'autre recule.
	var base_y: float = size.y * 0.28 + size.y * 0.42 - size.y / 2.0
	leg_l.position.y = base_y - swing
	leg_r.position.y = base_y + swing
	# Bras : opposition des jambes (style marche naturelle).
	if arm_l:
		arm_l.position.y = (size.y * 0.28 - size.y / 2.0) + swing * 0.6
	if arm_r:
		arm_r.position.y = (size.y * 0.28 - size.y / 2.0) - swing * 0.6

func _idle_pose() -> void:
	if leg_l == null or leg_r == null:
		return
	var base_y: float = size.y * 0.28 + size.y * 0.42 - size.y / 2.0
	leg_l.position.y = base_y
	leg_r.position.y = base_y
	if arm_l:
		arm_l.position.y = size.y * 0.28 - size.y / 2.0
	if arm_r:
		arm_r.position.y = size.y * 0.28 - size.y / 2.0

func _advance() -> void:
	_state = STATE_PAUSE
	# Pause randomisée pour casser la mécanique : jitter symétrique autour
	# de la valeur configurée, planché à 0.
	var pause_dur: float = pause_at_waypoints
	if pause_random_jitter > 0.0:
		pause_dur += _rng.randf_range(-pause_random_jitter, pause_random_jitter)
		pause_dur = max(pause_dur, 0.1)
	_pause_until = Time.get_ticks_msec() / 1000.0 + pause_dur
	# Choix de la prochaine cible : roam aléatoire si possible, sinon waypoint suivant.
	if _uses_roam_zone():
		_local_target = _pick_random_in_zone()
	else:
		_current = (_current + 1) % path.size()
		_local_target = path[_current]

# Tire un point aléatoire dans la roam_zone, exprimé en coords locales par
# rapport au spawn. Tente jusqu'à ROAM_RETRY_COUNT fois pour éviter une
# destination trop proche d'un autre wanderer (séparation douce — empêche les
# chevauchements visuels). En dernier recours, accepte la dernière tentative.
func _pick_random_in_zone() -> Vector2:
	var candidate: Vector2 = Vector2.ZERO
	for attempt in ROAM_RETRY_COUNT:
		var x: float = _rng.randf_range(roam_zone.position.x, roam_zone.position.x + roam_zone.size.x)
		var y: float = _rng.randf_range(roam_zone.position.y, roam_zone.position.y + roam_zone.size.y)
		candidate = _spawn_position + Vector2(x, y)
		if not _is_too_close_to_others(candidate):
			return candidate
	return candidate

# Vrai si une cible (en coords parent) est à moins de ROAM_SEPARATION pixels
# d'un autre wanderer du registre. Ignore self.
func _is_too_close_to_others(candidate_local: Vector2) -> bool:
	# Convertit en global pour comparer aux global_position des autres.
	var candidate_global: Vector2 = global_position + (candidate_local - position)
	for other in _registry:
		if other == self or not is_instance_valid(other):
			continue
		if other.global_position.distance_to(candidate_global) < ROAM_SEPARATION:
			return true
	return false
