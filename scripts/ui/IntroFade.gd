extends CanvasLayer

# Fade-in noir au démarrage (effet "réveil"). Couvre tout l'écran à pleine
# opacité pendant 0.6s, puis fade vers transparent en 1.4s, puis se masque.
# Ne se rejoue pas si le flag intro_seen est déjà set (resave loaded).

const HOLD_DURATION: float = 0.6
const FADE_DURATION: float = 1.4

@onready var rect: ColorRect = $Rect

func _ready() -> void:
	if CampaignManager.has_flag("intro_seen"):
		visible = false
		return
	if rect == null:
		return
	rect.modulate = Color(1, 1, 1, 1)
	var tween: Tween = create_tween()
	tween.tween_interval(HOLD_DURATION)
	tween.tween_property(rect, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func(): visible = false)
