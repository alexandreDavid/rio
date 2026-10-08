class_name DayLighting
extends CanvasModulate

# Tint global appliqué à l'ensemble du monde (CanvasItems) selon la phase de la
# journée. Les variations restent subtiles pour ne pas écraser les districts
# qui ont déjà un ciel thématique (Corcovado nuit, Pão de Açúcar sunset...).

const PHASE_TINTS: Array[Color] = [
	Color(1.0, 0.85, 0.62, 1),   # MORNING : aube dorée chaleureuse
	Color(1.0, 1.0, 1.0, 1),     # AFTERNOON : neutre, plein jour
	Color(0.42, 0.45, 0.70, 1),  # EVENING : nuit bleutée (~55% luminosité)
]

const FADE_DURATION: float = 3.0

# Matériau « émissif » : ignore la couleur de vertex (donc le CanvasModulate)
# et affiche la texture × tint telle quelle. Posé sur tout nœud `nightlight`
# (halos, ampoules, fenêtres allumées) pour que la nuit ait des lumières au
# lieu de taches jaunes assombries (rendu D, docs/VISUEL_ETUDE_2026-10-08.md).
const EMISSIVE_SHADER_CODE: String = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool use_texture = true;
void fragment() {
	vec4 t = use_texture ? texture(TEXTURE, UV) : vec4(1.0);
	COLOR = vec4(t.rgb * tint.rgb, t.a * tint.a);
}
"""
static var _emissive_shader: Shader = null
static var _glow_texture: GradientTexture2D = null

func _ready() -> void:
	color = _phase_tint(TimeOfDay.current_phase)
	# Le monde (frère suivant) n'est pas encore prêt : on passe par un différé.
	call_deferred("_refresh_nightlights", TimeOfDay.current_phase)
	EventBus.time_of_day_changed.connect(_on_phase_changed)


static func emissive_material(tint: Color, use_texture: bool) -> ShaderMaterial:
	if _emissive_shader == null:
		_emissive_shader = Shader.new()
		_emissive_shader.code = EMISSIVE_SHADER_CODE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _emissive_shader
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("use_texture", use_texture)
	return m


static func glow_texture() -> GradientTexture2D:
	if _glow_texture == null:
		var g: Gradient = Gradient.new()
		g.set_color(0, Color(1.0, 0.92, 0.6, 0.85))
		g.set_color(1, Color(1.0, 0.85, 0.45, 0.0))
		g.add_point(0.45, Color(1.0, 0.88, 0.5, 0.35))
		var t: GradientTexture2D = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_glow_texture = t
	return _glow_texture


# Un halo en rect (lampadaires de Copa et des districts) devient un dégradé
# radial deux fois plus large ; les autres nœuds reçoivent le matériau émissif.
func _prepare_nightlight(node: CanvasItem) -> void:
	if node.has_meta("emissive"):
		return
	node.set_meta("emissive", true)
	if node is ColorRect:
		var cr: ColorRect = node as ColorRect
		if String(cr.name).contains("Halo"):
			var glow: Sprite2D = Sprite2D.new()
			glow.name = cr.name + "Glow"
			glow.texture = glow_texture()
			var size: Vector2 = cr.size * 2.4
			glow.scale = size / Vector2(64, 64)
			glow.position = cr.position + cr.size * 0.5
			glow.material = emissive_material(Color(1, 1, 1, 1), true)
			glow.add_to_group("nightlight")
			glow.set_meta("emissive", true)
			glow.visible = cr.visible
			cr.get_parent().add_child(glow)
			cr.get_parent().move_child(glow, cr.get_index())
			cr.visible = false
			cr.remove_from_group("nightlight")
			return
		cr.material = emissive_material(cr.color, false)
	elif node is Sprite2D:
		node.material = emissive_material(Color(1, 1, 1, 1), true)

func _phase_tint(phase: int) -> Color:
	if phase < 0 or phase >= PHASE_TINTS.size():
		return Color(1, 1, 1, 1)
	return PHASE_TINTS[phase]

func _on_phase_changed(phase: int) -> void:
	var target: Color = _phase_tint(phase)
	var tween: Tween = create_tween()
	tween.tween_property(self, "color", target, FADE_DURATION)
	_refresh_nightlights(phase)

# Allume/éteint tous les CanvasItem dans le groupe "nightlight" selon la phase.
# Convention : un noeud tagué `nightlight` est éteint le jour, allumé le soir.
# Les districts les placent (lampadaires, vitres jaunes, halos de phare).
func _refresh_nightlights(phase: int) -> void:
	var is_night: bool = phase == TimeOfDay.Phase.EVENING
	for node in get_tree().get_nodes_in_group("nightlight"):
		if node is CanvasItem:
			_prepare_nightlight(node as CanvasItem)
	for node in get_tree().get_nodes_in_group("nightlight"):
		if node is CanvasItem:
			(node as CanvasItem).visible = is_night
