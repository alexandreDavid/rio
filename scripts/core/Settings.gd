extends Node

# Autoload : Settings. Persiste les préférences joueur dans user://settings.cfg.
# Volumes en linéaire 0-1, AudioManager les convertit en dB et les applique
# en live aux streams actifs via le signal volumes_changed.

signal volumes_changed

const PATH: String = "user://settings.cfg"

var music_volume: float = 0.7
var sfx_volume: float = 0.85
var ambient_volume: float = 0.55
# Vrai après dismiss du tutoriel d'accueil. Persiste globalement (pas par save)
# pour qu'un retour de Nouvelle Partie ne le re-déclenche pas inutilement.
var tutorial_seen: bool = false
# Astuces contextuelles déjà montrées (ContextTips) : globales, comme le guide.
var tips_seen: PackedStringArray = PackedStringArray()
# Slot de save courant (1..3). Persiste globalement pour que la session
# suivante reprenne sur le même emplacement.
var current_slot: int = 1
# Compteurs "vu pour la dernière fois" par app du Phone — alimentent les
# badges rouges quand le compteur actuel les dépasse.
var last_seen_cronica: int = 0
var last_seen_conquistas: int = 0
var last_seen_photos: int = 0

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(PATH)
	if err != OK:
		return
	music_volume = clampf(float(cfg.get_value("volumes", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("volumes", "sfx", sfx_volume)), 0.0, 1.0)
	ambient_volume = clampf(float(cfg.get_value("volumes", "ambient", ambient_volume)), 0.0, 1.0)
	tutorial_seen = bool(cfg.get_value("ui", "tutorial_seen", tutorial_seen))
	tips_seen = PackedStringArray(cfg.get_value("ui", "tips_seen", tips_seen))
	# Joueur d'avant les astuces : il a lu le guide, on ne lui réapprend rien.
	if tutorial_seen and not cfg.has_section_key("ui", "tips_seen"):
		tips_seen = PackedStringArray(ContextTips.TIPS.keys())
	current_slot = clampi(int(cfg.get_value("save", "current_slot", current_slot)), 1, 3)
	last_seen_cronica = int(cfg.get_value("phone", "last_seen_cronica", last_seen_cronica))
	last_seen_conquistas = int(cfg.get_value("phone", "last_seen_conquistas", last_seen_conquistas))
	last_seen_photos = int(cfg.get_value("phone", "last_seen_photos", last_seen_photos))
	volumes_changed.emit()

func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("volumes", "music", music_volume)
	cfg.set_value("volumes", "sfx", sfx_volume)
	cfg.set_value("volumes", "ambient", ambient_volume)
	cfg.set_value("ui", "tutorial_seen", tutorial_seen)
	cfg.set_value("ui", "tips_seen", tips_seen)
	cfg.set_value("save", "current_slot", current_slot)
	cfg.set_value("phone", "last_seen_cronica", last_seen_cronica)
	cfg.set_value("phone", "last_seen_conquistas", last_seen_conquistas)
	cfg.set_value("phone", "last_seen_photos", last_seen_photos)
	cfg.save(PATH)

func set_music(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	volumes_changed.emit()
	save_settings()

func set_sfx(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	volumes_changed.emit()
	save_settings()

func set_ambient(v: float) -> void:
	ambient_volume = clampf(v, 0.0, 1.0)
	volumes_changed.emit()
	save_settings()

func mark_tutorial_seen() -> void:
	tutorial_seen = true
	save_settings()

func has_seen_tip(id: String) -> bool:
	return tips_seen.has(id)

func mark_tip_seen(id: String) -> void:
	if tips_seen.has(id):
		return
	tips_seen.append(id)
	save_settings()

func reset_tips() -> void:
	tips_seen = PackedStringArray()
	save_settings()

func set_current_slot(slot: int) -> void:
	current_slot = clampi(slot, 1, 3)
	save_settings()

func mark_seen(app_id: String, count: int) -> void:
	match app_id:
		"cronica": last_seen_cronica = count
		"conquistas": last_seen_conquistas = count
		"photos": last_seen_photos = count
	save_settings()
