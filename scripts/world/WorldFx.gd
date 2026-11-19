class_name WorldFx
extends RefCounted

# Effets de décor partagés (rendu C et E, docs/VISUEL_ETUDE_2026-10-08.md) :
# balancement des palmiers par shader, phase par position, et activation du
# tri en Y sur les conteneurs du monde. L'eau et l'écume ne sont plus
# déformées ici : elles sont peintes et animées sur la grille de pixels par
# le shader de tuiles de DistrictDresser (frames + défilement entier).

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

static var _sway: Shader = null


static func _sway_shader() -> Shader:
	if _sway == null:
		_sway = Shader.new()
		_sway.code = SWAY_SHADER_CODE
	return _sway


# Phase (0..TAU) dérivée de la position : jamais deux effets en chœur.
static func phase_at(pos: Vector2) -> float:
	return fmod(absf(pos.x * 0.013 + pos.y * 0.031), TAU)


static func sway_material(pos: Vector2) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = _sway_shader()
	m.set_shader_parameter("phase", phase_at(pos))
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


# Perso posé « origine aux pieds » (spots de dialogue, suiveurs) : les corps
# (NPC, joueur) se trient par le centre de leur sprite, ~21 px au-dessus des
# pieds. Le nœud trie ses enfants avec le monde et son sprite prend la même
# hauteur de tri ; le dessin ne bouge pas (compensé par l'offset).
static func sort_feet_sprite_like_bodies(owner: Node2D, spr: Sprite2D) -> void:
	owner.y_sort_enabled = true
	var drawn_y: float = spr.position.y
	spr.position.y = -PropSprites.WORLD_SORT_LIFT
	spr.offset.y += (drawn_y - spr.position.y) / spr.scale.y
