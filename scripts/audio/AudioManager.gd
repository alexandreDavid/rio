extends Node

# Autoload. Écoute l'EventBus et joue des sons en réponse aux événements jeu.
# Les fichiers audio sont optionnels : si un fichier n'existe pas, le slot est
# silencieux — aucun crash.
#
# Drop des fichiers .ogg/.wav ici pour activer les pistes (boucler en import) :
#   res://assets/audio/music/<district>.ogg  — voir DISTRICT_MUSIC plus bas
#   res://assets/audio/sfx/waves.ogg         — ambiance par défaut (vagues)
#   res://assets/audio/sfx/coin.ogg, whistle.ogg, dialogue.ogg,
#                          quest_complete.ogg, minigame_win.ogg,
#                          minigame_lose.ogg, basket_swish.ogg, paddle.ogg,
#                          carnaval_drum.ogg

# Musique par district (cross-fade sur district_changed). Une absence de fichier
# = silence sur ce district. La piste de Copacabana est aussi la piste de fond
# par défaut tant qu'aucun district n'est entré.
const DISTRICT_MUSIC: Dictionary = {
	"copacabana":         "res://assets/audio/music/beach.ogg",        # samba lounge
	"corcovado":          "res://assets/audio/music/corcovado.ogg",
	"pao_acucar":         "res://assets/audio/music/sunset.ogg",
	"maracana":           "res://assets/audio/music/torcida.ogg",
	"santos_dumont":      "res://assets/audio/music/airport.ogg",
	"aterro_flamengo":    "res://assets/audio/music/aterro.ogg",
	"sambodromo":         "res://assets/audio/music/carnaval.ogg",
	"favela_morro":       "res://assets/audio/music/favela.ogg",       # forró doux + radio lointaine
	"zona_sul":           "res://assets/audio/music/ipanema.ogg",      # bossa lounge
	"barra_tijuca":       "res://assets/audio/music/barra.ogg",        # funk carioca chic
	"niteroi":            "res://assets/audio/music/niteroi.ogg",      # MPB contemplatif
	"botafogo_flamengo":  "res://assets/audio/music/botafogo.ogg",     # groove urbain calme
}

# Ambient global de fallback si le district courant n'a pas d'override.
const AMBIENT_FALLBACK_PATH: String = "res://assets/audio/sfx/waves.ogg"

# Ambient par district (boucle longue, volume bas, crossfade). Absence = fallback waves.
const DISTRICT_AMBIENT: Dictionary = {
	"copacabana":         "res://assets/audio/sfx/waves.ogg",
	"zona_sul":           "res://assets/audio/sfx/waves.ogg",
	"aterro_flamengo":    "res://assets/audio/sfx/ambient_park.ogg",
	"botafogo_flamengo":  "res://assets/audio/sfx/ambient_city.ogg",
	"favela_morro":       "res://assets/audio/sfx/ambient_favela.ogg",
	"corcovado":          "res://assets/audio/sfx/ambient_forest.ogg",
	"pao_acucar":         "res://assets/audio/sfx/ambient_wind_high.ogg",
	"maracana":           "res://assets/audio/sfx/ambient_stadium.ogg",
	"santos_dumont":      "res://assets/audio/sfx/ambient_airport.ogg",
	"sambodromo":         "res://assets/audio/sfx/ambient_carnaval_distant.ogg",
}

const SFX_PATHS: Dictionary = {
	"coin":            "res://assets/audio/sfx/coin.ogg",
	"whistle":         "res://assets/audio/sfx/whistle.ogg",
	"dialogue":        "res://assets/audio/sfx/dialogue.ogg",
	"quest_complete":  "res://assets/audio/sfx/quest_complete.ogg",
	"quest_accepted":  "res://assets/audio/sfx/quest_accepted.ogg",
	"quest_failed":    "res://assets/audio/sfx/quest_failed.ogg",
	"minigame_win":    "res://assets/audio/sfx/minigame_win.ogg",
	"minigame_lose":   "res://assets/audio/sfx/minigame_lose.ogg",
	"basket_swish":    "res://assets/audio/sfx/basket_swish.ogg",
	"paddle":          "res://assets/audio/sfx/paddle.ogg",
	"carnaval_drum":   "res://assets/audio/sfx/carnaval_drum.ogg",
	# Feedback UI / interaction
	"prompt_chime":    "res://assets/audio/sfx/prompt_chime.ogg",
	# Story beats
	"act_stinger":     "res://assets/audio/sfx/act_stinger.ogg",
	# Inventaire + commerce
	"item_pickup":     "res://assets/audio/sfx/item_pickup.ogg",
	"customer_cling":  "res://assets/audio/sfx/customer_cling.ogg",
	"debt_paid":       "res://assets/audio/sfx/debt_paid.ogg",
	# Charrette de milho
	"cart_lift":       "res://assets/audio/sfx/cart_lift.ogg",
	"cart_drop":       "res://assets/audio/sfx/cart_drop.ogg",
	# Pas du joueur (par surface)
	"step_sand":       "res://assets/audio/sfx/step_sand.ogg",
	"step_road":       "res://assets/audio/sfx/step_road.ogg",
	"step_grass":      "res://assets/audio/sfx/step_grass.ogg",
	"step_wood":       "res://assets/audio/sfx/step_wood.ogg",
	"ui_click":        "res://assets/audio/sfx/ui_click.ogg",
	"chase_escaped":   "res://assets/audio/sfx/chase_escaped.ogg",
	# Retour en cours de mini-jeu (MinigameBase.sfx)
	"mg_perfect":      "res://assets/audio/sfx/mg_perfect.ogg",
	"mg_good":         "res://assets/audio/sfx/mg_good.ogg",
	"mg_miss":         "res://assets/audio/sfx/mg_miss.ogg",
	"mg_hit":          "res://assets/audio/sfx/mg_hit.ogg",
	"mg_drop":         "res://assets/audio/sfx/mg_drop.ogg",
	"checkpoint":      "res://assets/audio/sfx/checkpoint.ogg",
	"splash":          "res://assets/audio/sfx/splash.ogg",
	"fish_bite":       "res://assets/audio/sfx/fish_bite.ogg",
	"oven_ding":       "res://assets/audio/sfx/oven_ding.ogg",
	"torcida_cheer":   "res://assets/audio/sfx/torcida_cheer.ogg",
	"dj_kick":         "res://assets/audio/sfx/dj_kick.ogg",
	"dj_snare":        "res://assets/audio/sfx/dj_snare.ogg",
	"dj_hat":          "res://assets/audio/sfx/dj_hat.ogg",
	"dj_synth":        "res://assets/audio/sfx/dj_synth.ogg",
	"samba_tamborim":  "res://assets/audio/sfx/samba_tamborim.ogg",
	"samba_surdo":     "res://assets/audio/sfx/samba_surdo.ogg",
	"samba_cuica":     "res://assets/audio/sfx/samba_cuica.ogg",
	"samba_agogo":     "res://assets/audio/sfx/samba_agogo.ogg",
}

# Baisse de la musique pendant un mini-jeu ou une poursuite : les SFX du jeu
# passent devant sans couper l'ambiance.
const DUCK_DB: float = -9.0

# Mappings minigame_id → SFX déclenché à la fin (gain ou échec).
const MINIGAME_WIN_SFX: Dictionary = {
	"aterro_basket":     "basket_swish",
	"cagarras_sup":      "paddle",
	"carnaval_samba":    "carnaval_drum",
}

const FADE_DURATION: float = 1.2

@export var music_volume_db: float = -10.0
@export var ambient_volume_db: float = -14.0
@export var sfx_volume_db: float = -6.0

var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _music_active_a: bool = true  # true = _music_a est actif, false = _music_b
var _ambient_a: AudioStreamPlayer = null
var _ambient_b: AudioStreamPlayer = null
var _ambient_active_a: bool = true
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}
var _district_streams: Dictionary = {}  # id -> AudioStream (préchargés)
var _district_ambient_streams: Dictionary = {}  # id -> AudioStream (préchargés)
var _ambient_fallback_stream: AudioStream = null
var _last_money: int = 0
var _current_district: String = ""
var _current_ambient_district: String = ""
# Cooldown footsteps : on accumule la distance parcourue, step toutes les ~24 px.
var _step_distance: float = 0.0
var _last_player_pos: Vector2 = Vector2.ZERO
var _duck_sources: Dictionary = {}  # source -> true (mini-jeu, poursuite)

func _ready() -> void:
	_music_a = _make_player(-80.0)  # commence muets, on fade in
	_music_b = _make_player(-80.0)
	_ambient_a = _make_player(-80.0)
	_ambient_b = _make_player(-80.0)
	# 10 voix : les jeux de rythme superposent frappe, retour et fin de note.
	for i in 10:
		_sfx_pool.append(_make_player(sfx_volume_db))

	# Préchargement SFX (silencieux si fichier absent)
	for key in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			_sfx_streams[key] = load(path)
	# Préchargement musique par district
	for id in DISTRICT_MUSIC:
		var path2: String = DISTRICT_MUSIC[id]
		if ResourceLoader.exists(path2):
			var s: AudioStream = load(path2)
			if s and "loop" in s:
				s.loop = true
			_district_streams[id] = s
	# Préchargement ambient par district
	for id_amb in DISTRICT_AMBIENT:
		var path_amb: String = DISTRICT_AMBIENT[id_amb]
		if ResourceLoader.exists(path_amb):
			var sa: AudioStream = load(path_amb)
			if sa and "loop" in sa:
				sa.loop = true
			_district_ambient_streams[id_amb] = sa
	# Ambient fallback (waves) au cas où un district n'a pas d'override
	if ResourceLoader.exists(AMBIENT_FALLBACK_PATH):
		_ambient_fallback_stream = load(AMBIENT_FALLBACK_PATH)
		if _ambient_fallback_stream and "loop" in _ambient_fallback_stream:
			_ambient_fallback_stream.loop = true

	# Démarre sur la piste Copacabana par défaut.
	_swap_music("copacabana")
	_swap_ambient("copacabana")

	EventBus.money_changed.connect(_on_money_changed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.quest_accepted.connect(_on_quest_accepted)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.quest_failed.connect(_on_quest_failed)
	EventBus.minigame_ended.connect(_on_minigame_ended)
	EventBus.interaction_available.connect(_on_interaction_available)
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.item_acquired.connect(_on_item_acquired)
	EventBus.customer_served.connect(_on_customer_served)
	EventBus.debt_paid.connect(_on_debt_paid)
	EventBus.corn_cart_state_changed.connect(_on_corn_cart_state_changed)
	EventBus.minigame_started.connect(_on_minigame_started)
	EventBus.chase_started.connect(_on_chase_started)
	EventBus.chase_ended.connect(_on_chase_ended)
	DialogueBridge.line_shown.connect(_on_line_shown)
	# Chaque bouton de l'UI (créé maintenant ou plus tard) clique.
	get_tree().node_added.connect(_on_node_added)
	if Engine.has_singleton("DistrictManager") or get_tree().root.has_node("DistrictManager"):
		DistrictManager.district_changed.connect(_on_district_changed)
	# Réagit aux changements de volumes depuis l'app Ajustes (Phone).
	Settings.volumes_changed.connect(_apply_settings_volumes)
	_apply_settings_volumes()

# Mappe les volumes linéaires 0-1 stockés dans Settings vers les dB internes
# de l'AudioManager. Applique aux streams actifs en live (musique, ambient,
# SFX pool). Plages calées pour éviter la zone très basse en dB inaudible.
const _MUSIC_DB_MIN: float = -28.0
const _MUSIC_DB_MAX: float = 0.0
const _AMBIENT_DB_MIN: float = -32.0
const _AMBIENT_DB_MAX: float = -2.0
const _SFX_DB_MIN: float = -24.0
const _SFX_DB_MAX: float = 0.0

func _apply_settings_volumes() -> void:
	music_volume_db = _slider_to_db(Settings.music_volume, _MUSIC_DB_MIN, _MUSIC_DB_MAX)
	ambient_volume_db = _slider_to_db(Settings.ambient_volume, _AMBIENT_DB_MIN, _AMBIENT_DB_MAX)
	sfx_volume_db = _slider_to_db(Settings.sfx_volume, _SFX_DB_MIN, _SFX_DB_MAX)
	if _music_a:
		_music_a.volume_db = _music_target_db() if _music_active_a else -80.0
	if _music_b:
		_music_b.volume_db = _music_target_db() if not _music_active_a else -80.0
	if _ambient_a:
		_ambient_a.volume_db = ambient_volume_db if _ambient_active_a else -80.0
	if _ambient_b:
		_ambient_b.volume_db = ambient_volume_db if not _ambient_active_a else -80.0
	for p in _sfx_pool:
		p.volume_db = sfx_volume_db

func _slider_to_db(linear: float, min_db: float, max_db: float) -> float:
	if linear <= 0.001:
		return -80.0
	return lerpf(min_db, max_db, linear)

func play(key: String, pitch: float = 1.0) -> void:
	var stream: AudioStream = _sfx_streams.get(key)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.play()
			return

func _music_target_db() -> float:
	return music_volume_db + (DUCK_DB if not _duck_sources.is_empty() else 0.0)

func _set_duck(source: String, on: bool) -> void:
	var was: bool = not _duck_sources.is_empty()
	if on:
		_duck_sources[source] = true
	else:
		_duck_sources.erase(source)
	if was == (not _duck_sources.is_empty()):
		return
	var active: AudioStreamPlayer = _music_a if _music_active_a else _music_b
	if active and active.playing:
		_fade(active, _music_target_db(), 0.4)

func set_music_muted(muted: bool) -> void:
	var target_db: float = -80.0 if muted else music_volume_db
	if _music_a:
		_music_a.volume_db = target_db if _music_active_a else -80.0
	if _music_b:
		_music_b.volume_db = target_db if not _music_active_a else -80.0

func _make_player(volume_db: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.volume_db = volume_db
	add_child(p)
	return p

func _load_loop(path: String, player: AudioStreamPlayer) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	if "loop" in stream:
		stream.loop = true
	player.stream = stream
	player.play()

# Crossfade entre les deux players musicaux. Si la piste cible n'a pas de
# fichier, on coupe le player actif (silence pour ce district).
func _swap_music(district_id: String) -> void:
	if district_id == _current_district:
		return
	_current_district = district_id
	var stream: AudioStream = _district_streams.get(district_id)
	var outgoing: AudioStreamPlayer = _music_a if _music_active_a else _music_b
	var incoming: AudioStreamPlayer = _music_b if _music_active_a else _music_a
	_music_active_a = not _music_active_a
	if stream:
		incoming.stream = stream
		incoming.volume_db = -80.0
		incoming.play()
		_fade(incoming, _music_target_db(), FADE_DURATION)
	else:
		incoming.stop()
	if outgoing.playing:
		_fade(outgoing, -80.0, FADE_DURATION, true)

# Fade linéaire géré via Tween. Si stop_after, on arrête le player après fade.
func _fade(player: AudioStreamPlayer, target_db: float, duration: float, stop_after: bool = false) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, duration)
	if stop_after:
		tween.tween_callback(player.stop)

# --- Event handlers ---

func _on_money_changed(new_amount: int) -> void:
	if new_amount > _last_money:
		play("coin")
		GamepadBridge.pulse(0.25, 0.04)
	_last_money = new_amount

func _on_dialogue_started(npc_id: String) -> void:
	if npc_id == "pm" or npc_id == "ramos":
		play("whistle")

func _on_quest_accepted(_quest_id: String) -> void:
	play("quest_accepted")

func _on_quest_completed(_quest_id: String) -> void:
	play("quest_complete")
	GamepadBridge.pulse(0.6, 0.12)

func _on_minigame_started(_minigame_id: String) -> void:
	_set_duck("minigame", true)

func _on_chase_started(_chaser_id: String) -> void:
	play("whistle")
	_set_duck("chase", true)

func _on_chase_ended(_chaser_id: String, escaped: bool) -> void:
	_set_duck("chase", false)
	play("chase_escaped" if escaped else "quest_failed")
	GamepadBridge.pulse(0.5 if escaped else 0.9, 0.15 if escaped else 0.3)

# « Voix » à la Animal Crossing : un tic par réplique, à une hauteur propre à
# chaque orateur (stable d'une partie à l'autre).
func _on_line_shown(speaker: String, _text: String) -> void:
	var h: int = absi(speaker.hash()) % 1000
	play("dialogue", 0.8 + 0.45 * float(h) / 1000.0)

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("silent_click"):
		var b: BaseButton = node
		if not b.pressed.is_connected(_on_button_pressed):
			b.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	play("ui_click", randf_range(0.96, 1.04))

func _on_minigame_ended(minigame_id: String, result: Dictionary) -> void:
	_set_duck("minigame", false)
	# `qualifies` vrai = victoire, sinon échec partiel.
	var won: bool = bool(result.get("qualifies", result.get("won", false)))
	if won:
		var key: String = MINIGAME_WIN_SFX.get(minigame_id, "minigame_win")
		play(key)
		GamepadBridge.pulse(0.6, 0.15)
	else:
		play("minigame_lose")

func _on_district_changed(district_id: String) -> void:
	# Un voyage clôt tout mini-jeu ou poursuite : pas de musique coincée en bas.
	_duck_sources.clear()
	_swap_music(district_id)
	_swap_ambient(district_id)

func _on_quest_failed(_quest_id: String) -> void:
	play("quest_failed")

func _on_interaction_available(_interactable: Node) -> void:
	play("prompt_chime")

func _on_act_changed(_new_act: int) -> void:
	play("act_stinger")
	GamepadBridge.pulse(1.0, 0.35)

func _on_item_acquired(_item_id: String, _quantity: int) -> void:
	play("item_pickup")

func _on_customer_served(_npc_id: String) -> void:
	play("customer_cling")

func _on_debt_paid(_amount: int, _remaining: int) -> void:
	play("debt_paid")

func _on_corn_cart_state_changed(carrying: bool) -> void:
	play("cart_lift" if carrying else "cart_drop")

# Crossfade ambient. Si aucun fichier dispo pour le district, on tombe sur le
# fallback waves. Si fallback absent, on coupe l'ambient (silence).
func _swap_ambient(district_id: String) -> void:
	if district_id == _current_ambient_district:
		return
	_current_ambient_district = district_id
	var stream: AudioStream = _district_ambient_streams.get(district_id, _ambient_fallback_stream)
	var outgoing: AudioStreamPlayer = _ambient_a if _ambient_active_a else _ambient_b
	var incoming: AudioStreamPlayer = _ambient_b if _ambient_active_a else _ambient_a
	_ambient_active_a = not _ambient_active_a
	if stream:
		incoming.stream = stream
		incoming.volume_db = -80.0
		incoming.play()
		_fade(incoming, ambient_volume_db, FADE_DURATION)
	else:
		incoming.stop()
	if outgoing.playing:
		_fade(outgoing, -80.0, FADE_DURATION, true)

# API footstep : à appeler depuis le PlayerController à chaque physics_frame
# avec la position courante. On accumule la distance et on déclenche un step
# toutes les ~24 px. `surface` est libre ("sand", "road", "grass", "wood").
func notify_player_position(pos: Vector2, surface: String = "road") -> void:
	if _last_player_pos == Vector2.ZERO:
		_last_player_pos = pos
		return
	var delta: float = pos.distance_to(_last_player_pos)
	_last_player_pos = pos
	if delta <= 0.01:
		return
	_step_distance += delta
	if _step_distance >= 24.0:
		_step_distance = 0.0
		var key: String = "step_" + surface
		if not _sfx_streams.has(key):
			key = "step_road"  # fallback
		play(key, randf_range(0.88, 1.12))
