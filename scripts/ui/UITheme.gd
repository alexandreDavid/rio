class_name UITheme
extends RefCounted

# Thème de l'interface, construit en code au démarrage et posé sur la fenêtre
# racine (il s'applique à tous les Controls, y compris les étiquettes du monde).
# Les cadres sont des 9-slices peints en pixel-art à la densité du jeu (trait
# sombre / liseré clair / trait sombre / fond), les boutons tactiles des
# pastilles rondes translucides. Les scènes qui gardent un style propre (le
# téléphone) conservent leurs surcharges locales.
# Étude : docs/VISUEL_ETUDE_2026-10-08.md (piste G).

const DENSITY: int = 3
const INK: Color = Color(0.08, 0.09, 0.12, 1)
const PAPER: Color = Color(0.12, 0.14, 0.18, 0.92)
const GOLD: Color = Color(0.95, 0.85, 0.4, 1)
const CREAM: Color = Color(0.96, 0.92, 0.82, 1)
const SKY: Color = Color(0.6, 0.85, 1.0, 1)
const BUTTON_EDGE: Color = Color(0.72, 0.70, 0.62, 1)
const BUTTON_FILL: Color = Color(0.17, 0.19, 0.24, 0.9)
const BUTTON_HOVER_FILL: Color = Color(0.22, 0.25, 0.31, 0.95)
const BUTTON_PRESSED_FILL: Color = Color(0.55, 0.47, 0.2, 0.95)
const TOUCH_EDGE: Color = Color(1, 1, 1, 0.55)
const TOUCH_FILL: Color = Color(0, 0, 0, 0.32)
const TOUCH_PRESSED_FILL: Color = Color(0.95, 0.85, 0.4, 0.6)

static var _theme: Theme = null
static var _textures: Dictionary = {}
static var _merged: bool = false


# Fusionne le thème dans le thème par défaut du moteur (idempotent). Un thème
# posé sur la fenêtre ou sur un Control ne traverse ni les CanvasLayer ni les
# Node2D (la chaîne d'héritage s'arrête au premier nœud qui n'est pas un
# Control) ; le thème par défaut, lui, est le dernier recours de TOUS les
# Controls, y compris ceux instanciés plus tard (mini-jeux, toasts).
static func apply(root: Window = null) -> void:
	if _merged:
		return
	_merged = true
	var base: Theme = ThemeDB.get_default_theme()
	if base != null:
		base.merge_with(build())
	if root != null:
		root.theme = build()


static func build() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	# Panneaux.
	var panel: StyleBoxTexture = frame_box(GOLD, PAPER)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "PopupPanel", panel)
	# Boutons.
	t.set_stylebox("normal", "Button", frame_box(BUTTON_EDGE, BUTTON_FILL, 10, 6))
	t.set_stylebox("hover", "Button", frame_box(GOLD, BUTTON_HOVER_FILL, 10, 6))
	t.set_stylebox("pressed", "Button", frame_box(GOLD, BUTTON_PRESSED_FILL, 10, 6))
	t.set_stylebox("disabled", "Button", frame_box(Color(0.4, 0.4, 0.42, 1), Color(0.12, 0.13, 0.16, 0.6), 10, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.6, 0.6, 1))
	# Pastilles tactiles (joystick, sprint, action).
	t.add_type("TouchButton")
	t.set_type_variation("TouchButton", "Button")
	t.set_stylebox("normal", "TouchButton", pastille_box(TOUCH_EDGE, TOUCH_FILL))
	t.set_stylebox("hover", "TouchButton", pastille_box(TOUCH_EDGE, TOUCH_FILL))
	t.set_stylebox("pressed", "TouchButton", pastille_box(GOLD, TOUCH_PRESSED_FILL))
	t.set_stylebox("disabled", "TouchButton", pastille_box(Color(1, 1, 1, 0.2), Color(0, 0, 0, 0.2)))
	t.set_font_size("font_size", "TouchButton", 40)
	# Barres.
	t.set_stylebox("background", "ProgressBar", thin_box(Color(0.32, 0.34, 0.4, 1), Color(0.06, 0.07, 0.1, 0.9)))
	t.set_stylebox("fill", "ProgressBar", thin_box(INK, GOLD))
	# Curseurs (volumes) : la piste vide doit se voir, pas seulement la partie pleine.
	var track: StyleBoxTexture = thin_box(Color(0.32, 0.34, 0.4, 1), Color(0.06, 0.07, 0.1, 0.9))
	var filled: StyleBoxTexture = thin_box(GOLD, GOLD)
	for sb in [track, filled]:
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	# Étiquette « pastille » (prompt d'interaction, badges).
	t.add_type("Pastille")
	t.set_type_variation("Pastille", "Label")
	t.set_stylebox("normal", "Pastille", frame_box(GOLD, PAPER, 14, 8))
	t.set_color("font_color", "Pastille", CREAM)
	t.set_font_size("font_size", "Pastille", 20)
	# Titre en police pixel (en-têtes, badge du Diário).
	t.add_type("PixelTitle")
	t.set_type_variation("PixelTitle", "Label")
	t.set_font("font", "PixelTitle", PixelFont.font(2, false))
	t.set_font_size("font_size", "PixelTitle", PixelFont.SIZE * 2)
	t.set_color("font_color", "PixelTitle", GOLD)
	# Bouton à titre pixel (badge repliable).
	t.add_type("PixelButton")
	t.set_type_variation("PixelButton", "Button")
	t.set_font("font", "PixelButton", PixelFont.font(2, false))
	t.set_font_size("font_size", "PixelButton", PixelFont.SIZE * 2)
	t.set_color("font_color", "PixelButton", GOLD)
	t.set_color("font_hover_color", "PixelButton", Color.WHITE)
	t.set_color("font_pressed_color", "PixelButton", Color.WHITE)
	_theme = t
	return t


# Cadre 9-slice : 12×12 natifs (marges de 3), agrandi ×3 (NEAREST, aucune
# interpolation à l'écran), coins échancrés d'un pixel.
static func frame_box(edge: Color, fill: Color, content_x: int = 12, content_y: int = 10) -> StyleBoxTexture:
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = frame_texture(edge, fill)
	var m: float = 3.0 * DENSITY
	sb.texture_margin_left = m
	sb.texture_margin_top = m
	sb.texture_margin_right = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = content_x
	sb.content_margin_right = content_x
	sb.content_margin_top = content_y
	sb.content_margin_bottom = content_y
	return sb


# Cadre fin (barres) : 6×6 natifs, marges de 2.
static func thin_box(edge: Color, fill: Color) -> StyleBoxTexture:
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = thin_texture(edge, fill)
	var m: float = 2.0 * DENSITY
	sb.texture_margin_left = m
	sb.texture_margin_top = m
	sb.texture_margin_right = m
	sb.texture_margin_bottom = m
	return sb


# Pastille ronde : 24×24 natifs ; les marges gardent les arcs des coins, le
# milieu s'étire (un bouton carré reste une pastille, un bouton large devient
# une gélule).
static func pastille_box(edge: Color, fill: Color) -> StyleBoxTexture:
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = pastille_texture(edge, fill)
	var m: float = 10.0 * DENSITY
	sb.texture_margin_left = m
	sb.texture_margin_top = m
	sb.texture_margin_right = m
	sb.texture_margin_bottom = m
	return sb


static func frame_texture(edge: Color, fill: Color) -> ImageTexture:
	var key: String = "frame_%s_%s" % [edge.to_html(true), fill.to_html(true)]
	if _textures.has(key):
		return _textures[key]
	var n: int = 12
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var ring: int = mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			var on_corner: bool = (x == 0 or x == n - 1) and (y == 0 or y == n - 1)
			var c: Color
			if ring == 0:
				c = Color(0, 0, 0, 0) if on_corner else INK
			elif ring == 1:
				var inner_corner: bool = (x == 1 or x == n - 2) and (y == 1 or y == n - 2)
				c = INK if inner_corner else edge
			elif ring == 2:
				c = INK
			else:
				c = fill
			img.set_pixel(x, y, c)
	var tex: ImageTexture = _scaled(img)
	_textures[key] = tex
	return tex


static func thin_texture(edge: Color, fill: Color) -> ImageTexture:
	var key: String = "thin_%s_%s" % [edge.to_html(true), fill.to_html(true)]
	if _textures.has(key):
		return _textures[key]
	var n: int = 6
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var ring: int = mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			var c: Color = INK if ring == 0 else (edge if ring == 1 else fill)
			img.set_pixel(x, y, c)
	var tex: ImageTexture = _scaled(img)
	_textures[key] = tex
	return tex


static func pastille_texture(edge: Color, fill: Color) -> ImageTexture:
	var key: String = "pastille_%s_%s" % [edge.to_html(true), fill.to_html(true)]
	if _textures.has(key):
		return _textures[key]
	var n: int = 24
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(n * 0.5, n * 0.5)
	for y in n:
		for x in n:
			var d: float = (Vector2(x + 0.5, y + 0.5) - center).length()
			var c: Color
			if d > 12.0:
				c = Color(0, 0, 0, 0)
			elif d > 11.0:
				c = INK
			elif d > 10.0:
				c = edge
			elif d > 9.0:
				c = Color(INK.r, INK.g, INK.b, 0.6)
			else:
				c = fill
			img.set_pixel(x, y, c)
	var tex: ImageTexture = _scaled(img)
	_textures[key] = tex
	return tex


static func _scaled(img: Image) -> ImageTexture:
	img.resize(img.get_width() * DENSITY, img.get_height() * DENSITY, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
