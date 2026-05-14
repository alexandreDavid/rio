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
# Slot de save courant (1..3). Persiste globalement pour que la session
# suivante reprenne sur le même emplacement.
var current_slot: int = 1

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
	current_slot = clampi(int(cfg.get_value("save", "current_slot", current_slot)), 1, 3)
	volumes_changed.emit()

func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("volumes", "music", music_volume)
	cfg.set_value("volumes", "sfx", sfx_volume)
	cfg.set_value("volumes", "ambient", ambient_volume)
	cfg.set_value("ui", "tutorial_seen", tutorial_seen)
	cfg.set_value("save", "current_slot", current_slot)
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

func set_current_slot(slot: int) -> void:
	current_slot = clampi(slot, 1, 3)
	save_settings()
