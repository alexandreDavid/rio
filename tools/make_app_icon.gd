extends SceneTree
# Fabrique l'icône de l'application dans le style de l'écran titre : le Pão de
# Açúcar au coucher du soleil, la baie, le sable et le calçadão de Copacabana,
# peints sur 64×64 pixels natifs avec la palette de TitleBackdrop. Écrit toutes
# les tailles de assets/icons/ios/ (la taille est dans le nom du fichier).
#   godot --headless --path . -s tools/make_app_icon.gd -- [apercu.png]
# Avec un chemin : n'écrit que cet aperçu 1024, sans toucher aux icônes.
const DIR: String = "res://assets/icons/ios/"
const GRID: int = 64   # l'icône est dessinée sur 64×64 pixels natifs


func _init() -> void:
	var img: Image = paint()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		var big: Image = img.duplicate()
		big.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
		big.save_png(args[0])
		quit()
		return
	var dir: DirAccess = DirAccess.open(DIR)
	for f in dir.get_files():
		if not f.ends_with(".png"):
			continue
		var n: int = int(f.get_basename().get_slice("_", f.get_basename().get_slice_count("_") - 1))
		if n <= 0:
			continue
		var out: Image = img.duplicate()
		# Multiple entier du dessin d'abord (pixels nets), puis réduction douce.
		var k: int = int(ceilf(float(n) / float(GRID)))
		out.resize(GRID * k, GRID * k, Image.INTERPOLATE_NEAREST)
		if GRID * k != n:
			out.resize(n, n, Image.INTERPOLATE_LANCZOS)
		out.save_png(ProjectSettings.globalize_path(DIR + f))
		print("%s -> %d px" % [f, n])
	quit()


const HORIZON: int = 37
const SHORE: int = 51
const STONES: int = 56


static func paint() -> Image:
	var img: Image = Image.create(GRID, GRID, false, Image.FORMAT_RGB8)
	var sky: Array[Color] = [Color(0.3, 0.17, 0.42), Color(0.72, 0.3, 0.47), Color(0.97, 0.52, 0.4), Color(1.0, 0.76, 0.45)]
	for y in HORIZON:
		var t: float = float(y) / float(HORIZON - 1) * 3.0
		var a: int = mini(int(t), 2)
		# Dégradé en paliers (bandes de 2 px) : un ciel de pixel-art, pas un fondu.
		var c: Color = sky[a].lerp(sky[a + 1], snappedf(t - float(a), 0.25))
		for x in GRID:
			img.set_pixel(x, y, c)
	# Soleil à demi couché, à droite du morne.
	var sun: Vector2 = Vector2(43.0, float(HORIZON) - 1.0)
	for y in range(HORIZON - 12, HORIZON):
		for x in GRID:
			var d: float = Vector2(x, y).distance_to(sun)
			if d <= 9.5:
				img.set_pixel(x, y, TitleBackdrop.SUN if d <= 8.0 else Color(1.0, 0.82, 0.5))
	# Collines lointaines, puis le Pão de Açúcar et le Morro da Urca.
	for x in GRID:
		var h: int = 2 + int(roundf(1.5 * sin(float(x) * 0.33) + 1.0 * sin(float(x) * 0.11 + 1.0)))
		for y in range(HORIZON - maxi(h, 1), HORIZON):
			if img.get_pixel(x, y) != TitleBackdrop.SUN:
				img.set_pixel(x, y, TitleBackdrop.FAR_HILLS)
	_dome(img, 17.0, 10.5, 25.0, 1.5)
	_dome(img, 31.0, 7.0, 9.0, 0.0)
	# Mer : du mauve de l'horizon au bleu du rivage, reflet du soleil en tirets.
	for y in range(HORIZON, SHORE):
		var t2: float = float(y - HORIZON) / float(SHORE - HORIZON - 1)
		var sea: Color = Color(0.5, 0.33, 0.5).lerp(Color(0.2, 0.38, 0.58), snappedf(t2, 0.2))
		for x in GRID:
			img.set_pixel(x, y, sea)
		var half: int = 2 + (y - HORIZON) / 3
		var shift: int = [0, 1, -1, 0, 1, -1, 0][((y - HORIZON) / 2) % 7]
		if (y - HORIZON) % 2 == 0:
			for x in range(int(sun.x) - half + shift, int(sun.x) + half + shift):
				if x >= 0 and x < GRID:
					img.set_pixel(x, y, TitleBackdrop.SPARKLE)
	# Écume, sable, puis le calçadão : les vagues noires et blanches de Copa.
	for x in GRID:
		img.set_pixel(x, SHORE, TitleBackdrop.FOAM if (x / 3) % 4 != 0 else Color(0.2, 0.38, 0.58))
		for y in range(SHORE + 1, STONES):
			var grain: bool = (x * 7 + y * 13) % 11 == 0
			img.set_pixel(x, y, TitleBackdrop.SAND.darkened(0.12) if grain else TitleBackdrop.SAND)
		for y in range(STONES, GRID):
			var wave: int = int(roundf(2.0 * sin(float(x) * TAU / 16.0)))
			var band: int = posmod(y - STONES + wave, 4)
			img.set_pixel(x, y, TitleBackdrop.STONE_DARK if band < 2 else TitleBackdrop.STONE_LIGHT)
	return img


# Morne en demi-ellipse, flanc droit éclairé par le soleil couchant.
static func _dome(img: Image, cx: float, half_w: float, height: float, lean: float) -> void:
	for x in range(int(cx - half_w) - 1, int(cx + half_w) + 2):
		if x < 0 or x >= GRID:
			continue
		var u: float = (float(x) - cx) / half_w
		if absf(u) > 1.0:
			continue
		var top: int = HORIZON - int(roundf(height * pow(1.0 - u * u, 0.62) + lean * u))
		for y in range(maxi(top, 0), HORIZON):
			var rim: bool = u > 0.15 and y - top < 2
			img.set_pixel(x, y, TitleBackdrop.MOUNTAIN_RIM if rim else TitleBackdrop.MOUNTAIN)
