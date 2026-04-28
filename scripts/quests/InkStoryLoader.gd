class_name InkStoryLoader
extends Node

# Encapsule le runtime inkgd (https://github.com/ephread/inkgd).
# Chargement dynamique : si le plugin n'est pas installé ou le .ink absent,
# is_ready() reste faux et DialogueBridge retombe sur ses dialogues placeholder.
#
# Setup (côté projet) :
#   1. AssetLib dans Godot → installer "Ink" (inkgd 1.x pour Godot 4)
#   2. Project Settings > Plugins → activer "ink"
#   3. Placer les .ink dans res://ink/ (Godot les importe automatiquement)
#   4. Redémarrer l'éditeur une fois après activation du plugin.

signal line_produced(speaker: String, text: String)
signal choices_produced(choices: Array)
signal story_ended()
signal ready_to_play()

const INK_PLAYER_SCRIPT: String = "res://addons/inkgd/ink_player.gd"
const INK_STORY_PATH: String = "res://ink/milho.ink"

var _ink_player: Node = null
var _ready_to_play: bool = false

func _ready() -> void:
	if not _try_create_ink_player():
		push_warning("[InkStoryLoader] inkgd absent ou .ink introuvable — dialogues en mode placeholder.")

func is_ready() -> bool:
	return _ready_to_play

func start_from_knot(knot: String) -> bool:
	if not _ready_to_play or _ink_player == null:
		return false
	_ink_player.choose_path(knot)
	_pump()
	return true

func choose(index: int) -> void:
	if _ink_player == null:
		return
	_ink_player.choose_choice_index(index)
	_pump()

func bind_external(fn_name: String, callable: Callable) -> void:
	if _ink_player == null:
		return
	if _ink_player.has_method("bind_external_function"):
		_ink_player.bind_external_function(fn_name, callable)

func _try_create_ink_player() -> bool:
	if not ResourceLoader.exists(INK_PLAYER_SCRIPT):
		return false
	var script: Script = load(INK_PLAYER_SCRIPT)
	if script == null:
		return false
	_ink_player = script.new()
	_ink_player.name = "InkPlayer"
	add_child(_ink_player)
	if not ResourceLoader.exists(INK_STORY_PATH):
		push_warning("[InkStoryLoader] %s introuvable." % INK_STORY_PATH)
		return false
	_ink_player.ink_file = load(INK_STORY_PATH)
	_ink_player.loaded.connect(_on_loaded)
	_ink_player.continued.connect(_on_continued)
	_ink_player.prompt_choices.connect(_on_prompt_choices)
	_ink_player.ended.connect(_on_ended)
	_ink_player.create_story()
	return true

func _pump() -> void:
	# Avance ligne par ligne jusqu'à un choix ou la fin.
	while _ink_player.can_continue:
		_ink_player.continue_story()

func _on_loaded(success: bool) -> void:
	_ready_to_play = success
	if success:
		ready_to_play.emit()
	else:
		push_error("[InkStoryLoader] échec du chargement de %s" % INK_STORY_PATH)

func _on_continued(text: String, tags: Array) -> void:
	var speaker: String = _parse_speaker(text, tags)
	var body: String = _parse_body(text)
	line_produced.emit(speaker, body)

func _on_prompt_choices(choices: Array) -> void:
	var strings: Array = []
	for c in choices:
		if c is String:
			strings.append(c)
		elif c and "text" in c:
			strings.append(c.text)
		else:
			strings.append(str(c))
	choices_produced.emit(strings)

func _on_ended() -> void:
	story_ended.emit()

# Convention d'écriture Ink : "Speaker: texte de la réplique".
# Alternative : tag `#speaker:Seu João` avant la ligne.
func _parse_speaker(text: String, tags: Array) -> String:
	for tag in tags:
		var t: String = str(tag)
		if t.begins_with("speaker:"):
			return t.substr(8).strip_edges()
	var colon: int = text.find(":")
	if colon > 0 and colon < 40:
		return text.substr(0, colon).strip_edges()
	return ""

func _parse_body(text: String) -> String:
	var colon: int = text.find(":")
	if colon > 0 and colon < 40:
		return text.substr(colon + 1).strip_edges()
	return text.strip_edges()
