extends Node

# Autoload : Settings. Persiste les préférences joueur dans user://settings.cfg.
# Volumes en linéaire 0-1, AudioManager les convertit en dB et les applique
# en live aux streams actifs via le signal volumes_changed.

signal volumes_changed

const PATH: String = "user://settings.cfg"

var music_volume: float = 0.7
var sfx_volume: float = 0.85
var ambient_volume: float = 0.55

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
	volumes_changed.emit()

func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("volumes", "music", music_volume)
	cfg.set_value("volumes", "sfx", sfx_volume)
	cfg.set_value("volumes", "ambient", ambient_volume)
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
