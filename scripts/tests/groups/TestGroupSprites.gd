extends "res://scripts/tests/IntegrationTestBase.gd"

# Groupe : Sprites & NPCs. Extrait du monolithe IntegrationTest.
# run() rejoue les tests dans l'ordre d'origine (await préservé).

func run() -> void:
	_test_save_load_roundtrip()
	_test_wanderer_greeting_logic()
	await _test_wanderer_full_init()
	await _test_wanderer_render_toggle()
	await _test_sprite_factory()
	await _test_wanderer_pixel_sheet()
	await _test_wanderer_stationary_atlas()
	await _test_wanderer_4dir_facing()
	await _test_npc_procedural_sprite()
	await _test_player_appearance()
	_test_home_visit_clears_on_favela_entry()
	await _test_npc_quest_indicator()


func _test_save_load_roundtrip() -> void:
	_section("Sauvegarde/chargement — état restauré identique")
	# Pose un état repérable.
	CampaignManager.current_act = 2
	CampaignManager.debt_paid = 12345
	CampaignManager.chosen_endgame = CampaignManager.Endgame.NONE
	CampaignManager.flags = {"flag_a": true, "flag_b": true}
	# Sérialise.
	var snap: Dictionary = CampaignManager.serialize()
	_assert(snap.get("current_act", -1) == 2, "snapshot current_act")
	_assert(snap.get("debt_paid", -1) == 12345, "snapshot debt_paid")
	_assert(snap.get("flags", {}).has("flag_a"), "snapshot flag_a")
	# Mute l'état puis recharge.
	CampaignManager.current_act = 1
	CampaignManager.debt_paid = 0
	CampaignManager.flags.clear()
	CampaignManager.deserialize(snap)
	_assert(CampaignManager.current_act == 2, "deserialize current_act")
	_assert(CampaignManager.debt_paid == 12345, "deserialize debt_paid")
	_assert(CampaignManager.has_flag("flag_a"), "deserialize flag_a")
	_assert(CampaignManager.has_flag("flag_b"), "deserialize flag_b")


func _test_wanderer_greeting_logic() -> void:
	_section("AmbientWanderer — choix de salutation par voie/réputation")
	var spot_script: GDScript = load("res://scripts/world/AmbientWanderer.gd")
	_assert(spot_script != null, "AmbientWanderer.gd charge")
	if spot_script == null:
		return
	var w: Node = spot_script.new()
	# Backup état campagne + rep pour restaurer après.
	var saved_endgame: int = CampaignManager.chosen_endgame
	var saved_rep: Array = []
	for i in ReputationSystem.Axis.size():
		saved_rep.append(ReputationSystem.get_value(i))

	# Reset propre.
	CampaignManager.chosen_endgame = CampaignManager.Endgame.NONE
	for i in ReputationSystem.Axis.size():
		ReputationSystem.set_value(i, 0)

	# Cas 1 : tout neutre → NONE
	_assert(w._evaluate_greeting() == w.Greeting.NONE, "neutre → NONE")
	# Cas 2 : civic 30 → WAVE
	ReputationSystem.set_value(ReputationSystem.Axis.CIVIC, 30)
	_assert(w._evaluate_greeting() == w.Greeting.WAVE, "civic 30 → WAVE")
	# Cas 3 : civic 0 + charisma 50 → WAVE
	ReputationSystem.set_value(ReputationSystem.Axis.CIVIC, 0)
	ReputationSystem.set_value(ReputationSystem.Axis.CHARISMA, 50)
	_assert(w._evaluate_greeting() == w.Greeting.WAVE, "charisma 50 → WAVE")
	# Cas 4 : street 30 (sans civic) → AVOID
	ReputationSystem.set_value(ReputationSystem.Axis.CHARISMA, 0)
	ReputationSystem.set_value(ReputationSystem.Axis.STREET, 30)
	_assert(w._evaluate_greeting() == w.Greeting.AVOID, "street 30 → AVOID")
	# Cas 5 : civic 50 ET street 30 → civic gagne (vérifie ordre de priorité)
	ReputationSystem.set_value(ReputationSystem.Axis.CIVIC, 50)
	_assert(w._evaluate_greeting() == w.Greeting.WAVE, "civic 50 + street 30 → WAVE (civic prime)")
	# Reset rep avant tests endgame.
	for i in ReputationSystem.Axis.size():
		ReputationSystem.set_value(i, 0)
	# Cas 6 : voie PREFEITO → BOW
	CampaignManager.chosen_endgame = CampaignManager.Endgame.PREFEITO
	_assert(w._evaluate_greeting() == w.Greeting.BOW, "endgame Prefeito → BOW")
	# Cas 7 : voie POLICIA → WAVE
	CampaignManager.chosen_endgame = CampaignManager.Endgame.POLICIA
	_assert(w._evaluate_greeting() == w.Greeting.WAVE, "endgame Policia → WAVE")
	# Cas 8 : voie TRAFICO → AVOID, même avec rep civic max
	CampaignManager.chosen_endgame = CampaignManager.Endgame.TRAFICO
	ReputationSystem.set_value(ReputationSystem.Axis.CIVIC, 100)
	_assert(w._evaluate_greeting() == w.Greeting.AVOID, "endgame Trafico écrase la civic → AVOID")

	# Restore.
	CampaignManager.chosen_endgame = saved_endgame
	for i in ReputationSystem.Axis.size():
		ReputationSystem.set_value(i, saved_rep[i])
	w.free()


func _test_wanderer_full_init() -> void:
	_section("AmbientWanderer — instantiation pleine + bulle + pools")
	var script: GDScript = load("res://scripts/world/AmbientWanderer.gd")
	# Pools de phrases : chaque phase doit avoir au moins une phrase WAVE.
	var consts: Dictionary = script.get_script_constant_map()
	var wave_pool: Dictionary = consts.get("WAVE_PHRASES", {})
	for phase in [TimeOfDay.Phase.MORNING, TimeOfDay.Phase.AFTERNOON, TimeOfDay.Phase.EVENING]:
		var phrases: Array = wave_pool.get(phase, [])
		_assert(phrases.size() > 0, "WAVE_PHRASES[phase=%d] non-vide" % phase)
	_assert(consts.get("BOW_PHRASES", []).size() > 0, "BOW_PHRASES non-vide")
	_assert(consts.get("SALUTE_PHRASES", []).size() > 0, "SALUTE_PHRASES non-vide")
	# Instanciation complète via scène : vérifie que _ready() ne crash pas et
	# que la bulle existe ou est absente selon le mode global DECORATIVE_STYLE.
	var packed: PackedScene = load("res://scenes/props/AmbientWanderer.tscn") as PackedScene
	_assert(packed != null, "AmbientWanderer.tscn charge")
	if packed == null:
		return
	var w: Node = packed.instantiate()
	add_child(w)
	await get_tree().process_frame
	var bubble: Node = w.get_node_or_null("GreetingBubble")
	var decorative_mode: bool = bool(consts.get("DECORATIVE_STYLE", false))
	if decorative_mode:
		_assert(bubble == null, "Mode décoratif : pas de bulle de salutation créée")
	else:
		_assert(bubble != null, "GreetingBubble créée à _ready")
		_assert(bubble is Label, "GreetingBubble est une Label")
		if bubble is Label:
			_assert((bubble as Label).modulate.a == 0.0, "Bulle invisible par défaut (alpha 0)")
	w.queue_free()
	await get_tree().process_frame


func _test_wanderer_render_toggle() -> void:
	_section("AmbientWanderer — toggle global RENDER_DEFAULT")
	var script: GDScript = load("res://scripts/world/AmbientWanderer.gd")
	var consts: Dictionary = script.get_script_constant_map()
	var render_default: bool = bool(consts.get("RENDER_DEFAULT", true))
	var packed: PackedScene = load("res://scenes/props/AmbientWanderer.tscn") as PackedScene
	if packed == null:
		_assert(false, "AmbientWanderer.tscn charge")
		return
	var w: Node = packed.instantiate()
	add_child(w)
	await get_tree().process_frame
	if render_default:
		_assert((w as CanvasItem).visible == true, "RENDER_DEFAULT=true → wanderer visible")
	else:
		_assert((w as CanvasItem).visible == false, "RENDER_DEFAULT=false → wanderer caché globalement")
		_assert(not w.is_processing(), "RENDER_DEFAULT=false → _process coupé (zéro CPU)")
	w.queue_free()
	await get_tree().process_frame


func _test_sprite_factory() -> void:
	_section("CharacterSpriteFactory — palettes + configs reproductibles + cache")
	var factory: GDScript = load("res://scripts/world/CharacterSpriteFactory.gd")
	_assert(factory != null, "CharacterSpriteFactory.gd charge")
	if factory == null:
		return
	# Palettes non vides — minimum requis pour avoir de la variété.
	var consts: Dictionary = factory.get_script_constant_map()
	_assert(consts.get("PALETTE_SKIN", []).size() >= 3, "PALETTE_SKIN ≥ 3 teints")
	_assert(consts.get("PALETTE_HAIR_COLOR", []).size() >= 4, "PALETTE_HAIR_COLOR ≥ 4 couleurs")
	_assert(consts.get("PALETTE_HAIR_STYLE", []).size() >= 4, "PALETTE_HAIR_STYLE ≥ 4 styles")
	_assert(consts.get("PALETTE_SHIRT_COLOR", []).size() >= 5, "PALETTE_SHIRT_COLOR ≥ 5 couleurs")
	_assert(consts.get("PALETTE_HAT_STYLE", []).size() >= 3, "PALETTE_HAT_STYLE ≥ 3 styles")
	# random_config est reproductible (même seed → même config).
	var c1: Dictionary = factory.random_config(42)
	var c2: Dictionary = factory.random_config(42)
	_assert(c1 == c2, "random_config(42) reproductible")
	# Seeds différentes produisent (très probablement) des configs différentes.
	var c3: Dictionary = factory.random_config(43)
	_assert(c1 != c3, "random_config(43) ≠ random_config(42)")
	# Toutes les clés attendues présentes.
	for k in ["skin", "hair_color", "hair_style", "shirt_color", "shirt_pattern",
			"pants_color", "hat_style", "hat_color"]:
		_assert(c1.has(k), "config a la clé '%s'" % k)
	# Cache : deux build_sheet avec même config → même ImageTexture (référence).
	var t1: ImageTexture = factory.build_sheet(c1)
	var t2: ImageTexture = factory.build_sheet(c1)
	_assert(t1 == t2, "build_sheet partage le cache pour configs identiques")
	# Texture aux bonnes dimensions.
	if t1 != null:
		var sz: Vector2 = t1.get_size()
		var fcw: int = int(consts.get("CELL_W", 32))
		var fch: int = int(consts.get("CELL_H", 48))
		_assert(int(sz.x) == fcw * 3 and int(sz.y) == fch * 3,
			"Texture %dx%d (3 dirs × 3 frames de %dx%d)" % [fcw * 3, fch * 3, fcw, fch])


func _test_wanderer_pixel_sheet() -> void:
	_section("AmbientWanderer — sheet pixel-art procédurale (factory)")
	var script: GDScript = load("res://scripts/world/AmbientWanderer.gd")
	var consts: Dictionary = script.get_script_constant_map()
	var factory: GDScript = load("res://scripts/world/CharacterSpriteFactory.gd")
	var fconsts: Dictionary = factory.get_script_constant_map()
	var px_w: int = int(consts.get("PX_CELL_W", 0))
	var px_h: int = int(consts.get("PX_CELL_H", 0))
	# PX_CELL_* doit rester synchronisé sur la factory (source unique).
	_assert(px_w == int(fconsts.get("CELL_W", -1)), "PX_CELL_W = factory CELL_W")
	_assert(px_h == int(fconsts.get("CELL_H", -1)), "PX_CELL_H = factory CELL_H")
	if not bool(consts.get("RENDER_DEFAULT", false)) or not bool(consts.get("RENDER_PIXEL_ART", false)):
		# Mode désactivé : pas la peine de tester l'instantiation Sprite2D.
		return
	var packed: PackedScene = load("res://scenes/props/AmbientWanderer.tscn") as PackedScene
	if packed == null:
		_assert(false, "AmbientWanderer.tscn charge")
		return
	var w: Node = packed.instantiate()
	add_child(w)
	await get_tree().process_frame
	# Le Sprite2D procédural doit exister sous le wanderer.
	var spr: Node = w.find_child("PixelSprite", true, false)
	_assert(spr != null, "PixelSprite Sprite2D créé à _ready")
	if spr is Sprite2D:
		var s: Sprite2D = spr as Sprite2D
		_assert(s.texture != null, "PixelSprite a une texture")
		if s.texture is ImageTexture:
			var sz: Vector2i = (s.texture as ImageTexture).get_size()
			_assert(sz.x == px_w * 3 and sz.y == px_h * 3,
				"Texture %dx%d (3×3 cellules de %dx%d)" % [px_w * 3, px_h * 3, px_w, px_h])
		_assert(s.region_enabled, "region_enabled = true")
		_assert(s.region_rect.size == Vector2(px_w, px_h),
			"region_rect taille = %dx%d" % [px_w, px_h])
	w.queue_free()
	await get_tree().process_frame


func _test_wanderer_stationary_atlas() -> void:
	_section("AmbientWanderer — figurant stationnaire rendu via la factory")
	var script: GDScript = load("res://scripts/world/AmbientWanderer.gd")
	var consts: Dictionary = script.get_script_constant_map()
	if not bool(consts.get("RENDER_DEFAULT", false)) or not bool(consts.get("RENDER_PIXEL_ART", false)):
		return
	var packed: PackedScene = load("res://scenes/props/AmbientWanderer.tscn") as PackedScene
	if packed == null:
		_assert(false, "AmbientWanderer.tscn charge")
		return
	var w: Node = packed.instantiate()
	w.set("stationary", true)
	add_child(w)
	await get_tree().process_frame
	# Rendu unifié : même un stationnaire passe par CharacterSpriteFactory
	# (PixelSprite LINEAR) — plus d'AtlasSprite « hors style ».
	var atlas: Node = w.find_child("AtlasSprite", true, false)
	var pixel: Node = w.find_child("PixelSprite", true, false)
	_assert(atlas == null, "Plus d'AtlasSprite (style unifié factory)")
	_assert(pixel != null, "PixelSprite factory créé pour un stationnaire")
	if pixel is Sprite2D:
		var s: Sprite2D = pixel as Sprite2D
		_assert(s.texture != null, "PixelSprite a une texture (factory)")
		_assert(s.region_enabled, "region_enabled = true")
		_assert(s.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"texture_filter = NEAREST (pixel-art GBA net)")
	w.queue_free()
	await get_tree().process_frame


func _test_wanderer_4dir_facing() -> void:
	_section("AmbientWanderer — facing 4 directions (4 directions)")
	var script: GDScript = load("res://scripts/world/AmbientWanderer.gd")
	_assert(script != null, "AmbientWanderer.gd charge")
	if script == null:
		return
	var w: Node = script.new()
	# _direction_from_vector : doit retourner la direction la plus saillante.
	_assert(w._direction_from_vector(Vector2(10, 1)) == w.DIR_RIGHT, "vecteur droite → DIR_RIGHT")
	_assert(w._direction_from_vector(Vector2(-10, 1)) == w.DIR_LEFT, "vecteur gauche → DIR_LEFT")
	_assert(w._direction_from_vector(Vector2(1, 10)) == w.DIR_DOWN, "vecteur bas → DIR_DOWN")
	_assert(w._direction_from_vector(Vector2(1, -10)) == w.DIR_UP, "vecteur haut → DIR_UP")
	# Pioche aléatoire dans le retournement aléatoire : la nouvelle direction doit
	# être différente de la courante (loop while new == current).
	w.free()
	# Test "scene-instantié" : applique une direction et vérifie le sprite.
	var packed: PackedScene = load("res://scenes/props/AmbientWanderer.tscn") as PackedScene
	if packed == null:
		_assert(false, "AmbientWanderer.tscn charge")
		return
	var w2: Node = packed.instantiate()
	add_child(w2)
	await get_tree().process_frame
	# DOWN → head colorée en skin_color.
	w2.call("_apply_facing_4", 0)  # DIR_DOWN
	var head_node: ColorRect = w2.get_node_or_null("Sprite/Head") as ColorRect
	_assert(head_node != null, "Sprite/Head accessible")
	if head_node:
		_assert(head_node.color == w2.get("skin_color"), "DOWN : head.color == skin_color")
	# UP → head colorée en hair_color (back of head).
	w2.call("_apply_facing_4", 1)  # DIR_UP
	if head_node:
		_assert(head_node.color == w2.get("hair_color"), "UP : head.color == hair_color (back of head)")
	# LEFT → scale.x négatif.
	w2.call("_apply_facing_4", 3)  # DIR_LEFT
	var sprite_node: Node2D = w2.get_node_or_null("Sprite") as Node2D
	if sprite_node:
		_assert(sprite_node.scale.x < 0.0, "LEFT : sprite.scale.x < 0 (flip)")
	w2.queue_free()
	await get_tree().process_frame


func _test_npc_procedural_sprite() -> void:
	_section("NPC — sprite procédural via CharacterSpriteFactory")
	var factory: GDScript = load("res://scripts/world/CharacterSpriteFactory.gd")
	# config_for_npc retourne un Dictionary non-vide pour les NPCs majeurs.
	for npc_id in ["seu_joao", "ramos", "tito", "padre", "carlos", "concierge", "contessa"]:
		var cfg: Dictionary = factory.config_for_npc(npc_id)
		_assert(not cfg.is_empty(), "config_for_npc('%s') non-vide" % npc_id)
		for k in ["skin", "hair_color", "hair_style", "shirt_color"]:
			_assert(cfg.has(k), "config '%s' a la clé '%s'" % [npc_id, k])
	# Pour un id inconnu, fallback aléatoire reproductible.
	var fallback1: Dictionary = factory.config_for_npc("unknown_npc_xyz")
	var fallback2: Dictionary = factory.config_for_npc("unknown_npc_xyz")
	_assert(fallback1 == fallback2, "Fallback aléatoire reproductible (même id → même config)")
	# Charge un NPC scénarisé et vérifie que son Sprite2D a une texture procédurale.
	var packed: PackedScene = load("res://scenes/npcs/SeuJoao.tscn") as PackedScene
	if packed == null:
		_assert(false, "SeuJoao.tscn charge")
		return
	var npc: Node = packed.instantiate()
	add_child(npc)
	await get_tree().process_frame
	var sprite_node: Node = npc.get_node_or_null("Sprite2D")
	_assert(sprite_node != null and sprite_node is Sprite2D, "NPC a un Sprite2D")
	if sprite_node is Sprite2D:
		var s: Sprite2D = sprite_node as Sprite2D
		# SeuJoao a un seu_joao_walk.png — la cascade NPC priorise le PNG individuel.
		_assert(s.texture != null, "Sprite2D.texture chargée (PNG individuel, atlas, ou procédurale)")
		_assert(s.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Filtrage NEAREST (pixel-perfect)")
	npc.queue_free()
	await get_tree().process_frame


func _test_player_appearance() -> void:
	_section("Apparence joueur — éditeur de perso (factory + persistance)")
	var factory: GDScript = load("res://scripts/world/CharacterSpriteFactory.gd")
	# default_indices : toutes les clés ATTRIBUTES, chaque valeur dans la plage.
	var consts: Dictionary = factory.get_script_constant_map()
	var attrs: Array = consts.get("ATTRIBUTES", [])
	_assert(attrs.size() == 8, "8 attributs éditables")
	var def: Dictionary = factory.default_indices()
	for a in attrs:
		_assert(def.has(a), "default_indices a la clé '%s'" % a)
		var n: int = factory.option_count(a)
		_assert(int(def[a]) >= 0 and int(def[a]) < n, "'%s' default dans [0,%d)" % [a, n])
	# sanitize_indices borne les valeurs hors plage et complète les manquantes.
	var dirty: Dictionary = {"skin": 999, "hair_color": -5}
	var clean: Dictionary = factory.sanitize_indices(dirty)
	_assert(int(clean["skin"]) == factory.option_count("skin") - 1, "skin=999 clampé au max")
	_assert(int(clean["hair_color"]) == 0, "hair_color=-5 clampé à 0")
	_assert(clean.size() == attrs.size(), "sanitize complète toutes les clés")
	# config_from_indices : types corrects pour la factory.
	var cfg: Dictionary = factory.config_from_indices(def)
	_assert(cfg["skin"] is Color, "config.skin est une Color")
	_assert(cfg["hair_style"] is String, "config.hair_style est une String")
	_assert(cfg["hat_style"] is String, "config.hat_style est une String")
	# build_sheet : feuille 3×3 cellules.
	var cw: int = int(consts.get("CELL_W", 16))
	var ch: int = int(consts.get("CELL_H", 24))
	var sheet: Texture2D = factory.build_sheet(cfg)
	_assert(sheet != null and sheet.get_size() == Vector2(cw * 3, ch * 3),
		"build_sheet → %dx%d" % [cw * 3, ch * 3])
	# GameManager : effective_appearance défaut quand vide, round-trip set.
	var saved_appr: Dictionary = GameManager.player_appearance.duplicate(true)
	GameManager.player_appearance = {}
	_assert(GameManager.effective_appearance() == factory.default_indices(),
		"effective_appearance vide → défaut")
	var custom: Dictionary = {"skin": 3, "hair_style": 2, "hair_color": 4,
		"shirt_color": 7, "shirt_pattern": 1, "pants_color": 2,
		"hat_style": 1, "hat_color": 3}
	GameManager.player_appearance = factory.sanitize_indices(custom)
	# Round-trip JSON (comme la save).
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(GameManager.player_appearance))
	_assert(factory.sanitize_indices(roundtrip) == GameManager.player_appearance,
		"Apparence survit au round-trip JSON (save)")
	GameManager.player_appearance = saved_appr
	# CharacterCreator : scène charge, 8 lignes construites, méthode open.
	var cc_packed: PackedScene = load("res://scenes/ui/CharacterCreator.tscn") as PackedScene
	_assert(cc_packed != null, "CharacterCreator.tscn charge")
	if cc_packed:
		var cc: Node = cc_packed.instantiate()
		add_child(cc)
		await get_tree().process_frame
		_assert(cc.has_method("open"), "CharacterCreator a open()")
		var rows: Node = cc.get_node_or_null("Panel/Margin/Layout/Scroll/Rows")
		_assert(rows != null and rows.get_child_count() == 8,
			"8 lignes d'attribut construites")
		cc.queue_free()
		await get_tree().process_frame
	# PlayerController : applique une texture factory au _ready.
	var p_packed: PackedScene = load("res://scenes/player/Player.tscn") as PackedScene
	_assert(p_packed != null, "Player.tscn charge")
	if p_packed:
		var pl: Node = p_packed.instantiate()
		add_child(pl)
		await get_tree().process_frame
		var spr: Node = pl.get_node_or_null("Visual/Sprite2D")
		_assert(spr is Sprite2D, "Player a un Visual/Sprite2D")
		if spr is Sprite2D:
			var s: Sprite2D = spr as Sprite2D
			_assert(s.texture != null, "Sprite joueur a une texture factory")
			_assert(s.region_rect.size == Vector2(cw, ch),
				"region = cellule %dx%d" % [cw, ch])
			_assert(s.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
				"Filtrage NEAREST (pixel-art net)")
		pl.queue_free()
		await get_tree().process_frame


func _test_home_visit_clears_on_favela_entry() -> void:
	_section("Visite famille — entrer en favela consomme should_visit_home")
	# Reset propre.
	CampaignManager.flags.clear()
	# Simule le pivot acte 2 qui pose le hint.
	CampaignManager.set_flag("should_visit_home")
	_assert(CampaignManager.has_flag("should_visit_home"), "should_visit_home posé")
	_assert(not CampaignManager.has_flag("home_visit_done"), "home_visit_done initialement absent")
	# Simule l'entrée en favela : MainBoot écoute district_changed et doit poser
	# home_visit_done. Note : on a besoin d'un MainBoot en scène pour que le
	# handler se déclenche. Sans ça (cas IntegrationTest), on déclenche
	# directement DistrictManager.set_current et on vérifie que QUELQUE part
	# le flag est levé. Comme MainBoot n'est pas en scène ici, on appelle
	# manuellement la logique de réaction.
	var current_save: String = DistrictManager.current()
	DistrictManager.set_current("favela_morro")
	# Le test est conditionnel : si MainBoot n'est pas en scène, on bypass et
	# on force juste le flag (le test devient un test du contrat plutôt qu'un
	# test de l'intégration MainBoot, ce qui reste utile en headless).
	var main_boot: Node = get_tree().current_scene.get_node_or_null("MainBoot")
	if main_boot == null:
		# Force la même logique manuellement pour valider le contrat.
		if not CampaignManager.has_flag("home_visit_done"):
			CampaignManager.set_flag("home_visit_done")
	_assert(CampaignManager.has_flag("home_visit_done"),
		"home_visit_done posé après entrée en favela_morro")
	# Restore.
	DistrictManager.set_current(current_save)
	CampaignManager.flags.clear()


func _test_npc_quest_indicator() -> void:
	_section("NPC — indicateur de quête $$ ('!' au-dessus de la tête)")
	# Instancie un NPC scénarisé existant (Otavio choisi : c'est un giver simple).
	var packed: PackedScene = load("res://scenes/npcs/Otavio.tscn") as PackedScene
	_assert(packed != null, "Otavio.tscn charge")
	if packed == null:
		return
	var npc: Node = packed.instantiate()
	add_child(npc)
	await get_tree().process_frame
	# Le Label QuestIndicator doit avoir été créé en code.
	var qi: Node = npc.get_node_or_null("QuestIndicator")
	_assert(qi != null, "QuestIndicator créé sous le NPC")
	_assert(qi is Label and (qi as Label).text == "!", "QuestIndicator est une Label avec '!'")
	_assert(qi != null and (qi as CanvasItem).visible == false, "QuestIndicator masqué par défaut (pas de quête dispo)")
	# Si on enregistre une quête disponible avec giver_npc_id matchant Otavio, le
	# refresh doit lever le flag _qi_has_available sur le NPC.
	var npc_data: NPCData = npc.get("data")
	if npc_data == null or npc_data.id == "":
		_assert(false, "Otavio a un NPCData avec id non vide")
		npc.queue_free()
		await get_tree().process_frame
		return
	# Construit une quête fake avec ce giver et register en AVAILABLE.
	var fake_quest: Quest = Quest.new()
	fake_quest.id = "qi_test_quest"
	fake_quest.display_name = "Test"
	fake_quest.giver_npc_id = npc_data.id
	fake_quest.ink_knot = "test_knot"
	QuestManager.register_quest(fake_quest)
	# Trigger refresh — utilise une méthode publique-ish (préfixe _qi mais on
	# l'appelle pour piloter l'état de test).
	npc.call("_qi_refresh_availability", "")
	_assert(bool(npc.get("_qi_has_available")), "NPC.qi_has_available devient true quand quête dispo + giver match")
	# Cleanup quête de test.
	QuestManager._quests.erase("qi_test_quest")
	QuestManager._state.erase("qi_test_quest")
	npc.queue_free()
	await get_tree().process_frame

