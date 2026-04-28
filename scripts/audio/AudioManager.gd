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
	"copacabana":      "res://assets/audio/music/beach.ogg",
	"corcovado":       "res://assets/audio/music/corcovado.ogg",
	"pao_acucar":      "res://assets/audio/music/sunset.ogg",
	"lagoa":           "res://assets/audio/music/lagoa.ogg",
	"maracana":        "res://assets/audio/music/torcida.ogg",
	"santos_dumont":   "res://assets/audio/music/airport.ogg",
	"aterro_flamengo": "res://assets/audio/music/aterro.ogg",
	"cagarras":        "res://assets/audio/music/sea.ogg",
	"sambodromo":      "res://assets/audio/music/carnaval.ogg",
}

const AMBIENT_PATH: String = "res://assets/audio/sfx/waves.ogg"
const SFX_PATHS: Dictionary = {
	"coin":            "res://assets/audio/sfx/coin.ogg",
	"whistle":         "res://assets/audio/sfx/whistle.ogg",
	"dialogue":        "res://assets/audio/sfx/dialogue.ogg",
	"quest_complete":  "res://assets/audio/sfx/quest_complete.ogg",
	"quest_accepted":  "res://assets/audio/sfx/quest_accepted.ogg",
	"minigame_win":    "res://assets/audio/sfx/minigame_win.ogg",
	"minigame_lose":   "res://assets/audio/sfx/minigame_lose.ogg",
	"basket_swish":    "res://assets/audio/sfx/basket_swish.ogg",
	"paddle":          "res://assets/audio/sfx/paddle.ogg",
	"carnaval_drum":   "res://assets/audio/sfx/carnaval_drum.ogg",
}

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
var _ambient: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}
var _district_streams: Dictionary = {}  # id -> AudioStream (préchargés)
var _last_money: int = 0
var _current_district: String = ""

func _ready() -> void:
	_music_a = _make_player(-80.0)  # commence muets, on fade in
	_music_b = _make_player(-80.0)
	_ambient = _make_player(ambient_volume_db)
	for i in 4:
		_sfx_pool.append(_make_player(sfx_volume_db))

	_load_loop(AMBIENT_PATH, _ambient)
	for key in SFX_PATHS:
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			_sfx_streams[key] = load(path)
	for id in DISTRICT_MUSIC:
		var path2: String = DISTRICT_MUSIC[id]
		if ResourceLoader.exists(path2):
			var s: AudioStream = load(path2)
			if s and "loop" in s:
				s.loop = true
			_district_streams[id] = s

	# Démarre sur la piste Copacabana par défaut.
	_swap_music("copacabana")

	EventBus.money_changed.connect(_on_money_changed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.quest_accepted.connect(_on_quest_accepted)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.minigame_ended.connect(_on_minigame_ended)
	if Engine.has_singleton("DistrictManager") or get_tree().root.has_node("DistrictManager"):
		DistrictManager.district_changed.connect(_on_district_changed)

func play(key: String) -> void:
	var stream: AudioStream = _sfx_streams.get(key)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return

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
		_fade(incoming, music_volume_db, FADE_DURATION)
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
	_last_money = new_amount

func _on_dialogue_started(npc_id: String) -> void:
	play("dialogue")
	if npc_id == "pm" or npc_id == "ramos":
		play("whistle")

func _on_quest_accepted(_quest_id: String) -> void:
	play("quest_accepted")

func _on_quest_completed(_quest_id: String) -> void:
	play("quest_complete")

func _on_minigame_ended(minigame_id: String, result: Dictionary) -> void:
	# `qualifies` vrai = victoire, sinon échec partiel.
	var won: bool = bool(result.get("qualifies", result.get("won", false)))
	if won:
		var key: String = MINIGAME_WIN_SFX.get(minigame_id, "minigame_win")
		play(key)
	else:
		play("minigame_lose")

func _on_district_changed(district_id: String) -> void:
	_swap_music(district_id)
