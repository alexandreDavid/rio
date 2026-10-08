class_name WorldFx
extends RefCounted

# Effets de décor partagés (rendu C et E, docs/VISUEL_ETUDE_2026-10-08.md) :
# shaders d'eau (ondulation + reflets), d'écume (pulsation), de balancement
# (palmiers), et activation du tri en Y sur les conteneurs du monde.

const WATER_SHADER_CODE: String = """
shader_type canvas_item;
uniform float amp = 1.2;
uniform float speed = 1.0;
uniform float glint = 0.05;
uniform float phase = 0.0;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
void fragment() {
	vec2 uv = UV;
	uv.x += sin(TIME * speed * 1.3 + UV.y * 18.0 + phase) * amp * TEXTURE_PIXEL_SIZE.x;
	uv.y += cos(TIME * speed * 0.9 + UV.x * 14.0 + phase) * amp * TEXTURE_PIXEL_SIZE.y;
	vec4 c = texture(TEXTURE, uv);
	float g = glint * sin(TIME * 2.0 + UV.x * 30.0 + UV.y * 22.0 + phase);
	COLOR = vec4(c.rgb + g, c.a) * vcol;
}
"""

const FOAM_SHADER_CODE: String = """
shader_type canvas_item;
uniform float phase = 0.0;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
void fragment() {
	vec2 uv = UV;
	uv.x += sin(TIME * 1.1 + phase) * 0.6 * TEXTURE_PIXEL_SIZE.x;
	vec4 c = texture(TEXTURE, uv) * vcol;
	c.a *= 0.72 + 0.28 * sin(TIME * 1.6 + phase);
	COLOR = c;
}
"""

const SWAY_SHADER_CODE: String = """
shader_type canvas_item;
uniform float amp = 1.4;
uniform float phase = 0.0;
varying vec4 vcol;
void vertex() {
	float k = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 1.4 + phase) * amp * k * k;
	vcol = COLOR;
}
void fragment() { COLOR = texture(TEXTURE, UV) * vcol; }
"""

static var _water: Shader = null
static var _foam: Shader = null
static var _sway: Shader = null


static func _shader(which: String) -> Shader:
	match which:
		"water":
			if _water == null:
				_water = Shader.new()
				_water.code = WATER_SHADER_CODE
			return _water
		"foam":
			if _foam == null:
				_foam = Shader.new()
				_foam.code = FOAM_SHADER_CODE
			return _foam
		_:
			if _sway == null:
				_sway = Shader.new()
				_sway.code = SWAY_SHADER_CODE
			return _sway


static func _phase_at(pos: Vector2) -> float:
	return fmod(absf(pos.x * 0.013 + pos.y * 0.031), TAU)


static func water_material(pos: Vector2) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader("water")
	m.set_shader_parameter("phase", _phase_at(pos))
	return m


static func foam_material(pos: Vector2) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader("foam")
	m.set_shader_parameter("phase", _phase_at(pos))
	return m


static func sway_material(pos: Vector2) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _shader("sway")
	m.set_shader_parameter("phase", _phase_at(pos))
	return m


# Tri en Y : la racine et tous les conteneurs sans script (Node2D, StaticBody2D
# créés par le code ou posés dans les scènes) trient leurs enfants par y ; les
# nœuds à script (personnages, spots, lanceurs) gardent leur ordre interne
# (ombre sous le sprite). Les niveaux imbriqués sont fusionnés par Godot.
static func enable_y_sort(root: Node) -> void:
	if root is Node2D:
		(root as Node2D).y_sort_enabled = true
	for n in root.find_children("*", "Node2D", true, false):
		if n.get_script() != null or n is Sprite2D or n.get_child_count() == 0:
			continue
		if n is CharacterBody2D:
			continue
		(n as Node2D).y_sort_enabled = true
