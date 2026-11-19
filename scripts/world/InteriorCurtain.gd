class_name InteriorCurtain
extends Node

# Les intérieurs sont posés côte à côte loin du monde (700 px d'entraxe) : sur
# un écran 20:9 la caméra voit 800 px de large et le voisin dépassait au bord
# (la padaria depuis la maison, le Palace depuis l'église — playtest mobile
# 2026-11-18). Tant que le joueur est DANS un intérieur, les autres se cachent.
# Hors de tout intérieur rien ne change (les PNJ postés dedans restent
# « visibles » pour le guidage et les tests).

const MARGIN: float = 48.0   # seuil de porte, murs extérieurs

static var _curtains: Array[InteriorCurtain] = []
static var _frame: int = -1
static var _inside: InteriorCurtain = null

var floor_rect: ColorRect = null
# Fond sombre autour des murs : montré seulement quand le joueur est dedans
# (un intérieur de district posé près de son quartier y ferait une tache noire).
var void_rect: ColorRect = null


static func attach(root: Node, floor: ColorRect, void_bg: ColorRect = null) -> void:
	var c: InteriorCurtain = InteriorCurtain.new()
	c.name = "InteriorCurtain"
	c.floor_rect = floor
	c.void_rect = void_bg
	if void_bg != null:
		void_bg.visible = false
	root.add_child(c)


func _enter_tree() -> void:
	_curtains.append(self)


func _exit_tree() -> void:
	_curtains.erase(self)
	if _inside == self:
		_inside = null


func _process(_delta: float) -> void:
	var root: CanvasItem = get_parent() as CanvasItem
	if root == null:
		return
	var here: InteriorCurtain = _current(get_tree())
	root.visible = here == null or here == self
	if is_instance_valid(void_rect):
		void_rect.visible = here == self


func contains(point: Vector2) -> bool:
	return is_instance_valid(floor_rect) and floor_rect.get_global_rect().grow(MARGIN).has_point(point)


# Racine de l'intérieur où se trouve le joueur (null dehors) — pour la minimap.
static func current_root(tree: SceneTree) -> Node:
	var c: InteriorCurtain = _current(tree)
	return c.get_parent() if c != null else null


# L'intérieur où se trouve le joueur, calculé une fois par trame.
# (Par le groupe « player », pas par l'autoload : l'habilleur tourne aussi dans
# les outils de capture sans autoloads.)
static func _current(tree: SceneTree) -> InteriorCurtain:
	var f: int = Engine.get_process_frames()
	if f == _frame:
		return _inside
	_frame = f
	_inside = null
	var player: Node2D = tree.get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	for c in _curtains:
		if c.contains(player.global_position):
			_inside = c
			break
	return _inside
