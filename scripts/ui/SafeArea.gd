class_name SafeArea
extends RefCounted

# Écarte une interface de l'encoche, des coins arrondis et de la barre
# d'accueil (iPhone, iPad, Android). Chaque bord ancré au bord de l'écran
# recule de l'encart correspondant ; un élément centré ne bouge pas. Les
# décalages d'origine sont gardés en méta : on peut réappliquer à chaque
# rotation sans dériver.

const META: StringName = &"_safe_area_base"


# Place un Control racine de scène par ancres + décalages, en code. À l'export,
# la conversion des .tscn en binaire ajoute layout_mode/anchors_preset à ces
# racines et leur position retombe à zéro sur l'appareil (minimap dans le coin,
# badge du Diário collé au bord) alors que tout est juste depuis l'éditeur.
static func place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


static func apply(c: Control) -> void:
	if not c.has_meta(META):
		c.set_meta(META, Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom))
		# Lambda (et pas apply.bind) : deux bind du même callable statique sont
		# jugés identiques, le 2e contrôle ne serait jamais connecté.
		c.get_viewport().size_changed.connect(func() -> void:
			if is_instance_valid(c):
				apply(c))
	var base: Vector4 = c.get_meta(META)
	var ins: Vector4 = insets(c.get_viewport())
	c.offset_left = base.x + _shift(c.anchor_left, ins.x, ins.z)
	c.offset_right = base.z + _shift(c.anchor_right, ins.x, ins.z)
	c.offset_top = base.y + _shift(c.anchor_top, ins.y, ins.w)
	c.offset_bottom = base.w + _shift(c.anchor_bottom, ins.y, ins.w)


# Un bord ancré à gauche/en haut recule de l'encart de début, à droite/en bas
# de l'encart de fin ; ancré au milieu, il reste en place.
static func _shift(anchor: float, start_inset: float, end_inset: float) -> float:
	if anchor <= 0.01:
		return start_inset
	if anchor >= 0.99:
		return -end_inset
	return 0.0


# Encarts (gauche, haut, droite, bas) en unités du canevas. Sur ordinateur la
# zone sûre décrit l'écran entier et pas la fenêtre : encarts nuls.
static func insets(vp: Viewport) -> Vector4:
	# Dev : simuler un téléphone sur ordinateur, en unités du canevas
	# (iPhone 17 paysage : RIO_SAFE_INSETS=167,0,167,54).
	if OS.has_environment("RIO_SAFE_INSETS"):
		var p: PackedFloat64Array = OS.get_environment("RIO_SAFE_INSETS").split_floats(",")
		if p.size() == 4:
			return Vector4(p[0], p[1], p[2], p[3])
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	if win.x <= 0.0 or win.y <= 0.0 or safe.size.x <= 0.0:
		return Vector4.ZERO
	var canvas: Vector2 = vp.get_visible_rect().size
	var k: Vector2 = canvas / win
	return Vector4(
		maxf(0.0, safe.position.x) * k.x,
		maxf(0.0, safe.position.y) * k.y,
		maxf(0.0, win.x - safe.end.x) * k.x,
		maxf(0.0, win.y - safe.end.y) * k.y)
