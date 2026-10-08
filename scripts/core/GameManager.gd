extends Node

# Global game state and references. Autoload name: GameManager.

var player: Node = null
var current_world: Node = null
var is_paused: bool = false

# Apparence du joueur — dict d'indices CharacterSpriteFactory (cf.
# CharacterSpriteFactory.ATTRIBUTES). Vide ⇒ apparence par défaut. Persistée
# par save (SaveSystem._serialize_player) ; éditée via CharacterCreator.
var player_appearance: Dictionary = {}
# Posé par l'épilogue (« Nouvelle partie+ ») : la prochaine partie lit la méta
# NG+. Une « Nouvelle partie » depuis l'écran des slots reste vierge
# (playtest 2026-10-07, F9).
var ng_plus_requested: bool = false

# Indices effectifs (défaut si non personnalisé). Toujours sûr à passer à
# CharacterSpriteFactory.config_from_indices.
func effective_appearance() -> Dictionary:
	if player_appearance.is_empty():
		return CharacterSpriteFactory.default_indices()
	return CharacterSpriteFactory.sanitize_indices(player_appearance)

# Applique une nouvelle apparence + rafraîchit le sprite du joueur live.
func set_player_appearance(indices: Dictionary) -> void:
	player_appearance = CharacterSpriteFactory.sanitize_indices(indices)
	if player and player.has_method("apply_appearance"):
		player.apply_appearance()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_paused:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false

func register_player(node: Node) -> void:
	player = node

func unregister_player() -> void:
	player = null
