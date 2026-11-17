class_name InputHints
extends RefCounted

# Préfixe d'action des prompts : ✋ (le bouton d'action à l'écran) sur tactile,
# [E] au clavier, Ⓐ à la manette. Mobile d'abord : un joueur iPhone ne doit jamais lire « [E] ».
static func act() -> String:
	if GamepadBridge.active:
		return "Ⓐ"
	return "✋" if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") else "[E]"
