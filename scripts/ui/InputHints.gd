class_name InputHints
extends RefCounted

# Préfixe d'action des prompts : ✋ (le bouton d'action à l'écran) sur tactile,
# [E] au clavier. Mobile d'abord : un joueur iPhone ne doit jamais lire « [E] ».
static func act() -> String:
	return "✋" if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") else "[E]"
