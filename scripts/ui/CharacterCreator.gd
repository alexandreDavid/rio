extends CanvasLayer

# Éditeur d'apparence du joueur — overlay plein écran mobile-first, ouvert
# depuis Phone › Ajustes › Aparência. Manipule des INDICES
# CharacterSpriteFactory (cf. ATTRIBUTES) ; « Confirmar » applique sur le
# joueur live + sauvegarde, « Cancelar » abandonne sans toucher l'état.
#
# Les lignes d'attribut sont construites en code (8 lignes quasi identiques —
# moins fragile qu'en .tscn) : libellé + ◀ + valeur + ▶. Touch targets ≥ 52 px.

@onready var preview: TextureRect = $Panel/Margin/Layout/Preview
@onready var rows_box: VBoxContainer = $Panel/Margin/Layout/Scroll/Rows
@onready var random_btn: Button = $Panel/Margin/Layout/Buttons/Random
@onready var confirm_btn: Button = $Panel/Margin/Layout/Buttons/Confirm
@onready var cancel_btn: Button = $Panel/Margin/Layout/Buttons/Cancel

# Indices en cours d'édition (copie de travail, non appliquée tant que pas
# confirmée).
var _indices: Dictionary = {}
# attr -> Label affichant la valeur courante.
var _value_labels: Dictionary = {}

func _ready() -> void:
	visible = false
	_build_rows()
	if random_btn:
		random_btn.pressed.connect(_on_random)
	if confirm_btn:
		confirm_btn.pressed.connect(_on_confirm)
	if cancel_btn:
		cancel_btn.pressed.connect(_on_cancel)

# Appelé par Phone (miroir de CreditsScreen.open).
func open() -> void:
	_indices = GameManager.effective_appearance()
	_refresh_all()
	visible = true
	get_tree().paused = true

func _close() -> void:
	visible = false
	get_tree().paused = false

func _build_rows() -> void:
	if rows_box == null:
		return
	for attr in CharacterSpriteFactory.ATTRIBUTES:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_lbl: Label = Label.new()
		name_lbl.text = String(CharacterSpriteFactory.ATTRIBUTE_LABELS.get(attr, attr))
		name_lbl.custom_minimum_size = Vector2(220, 0)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.85, 1))
		row.add_child(name_lbl)

		var prev: Button = Button.new()
		prev.text = "◀"
		prev.custom_minimum_size = Vector2(60, 52)
		prev.add_theme_font_size_override("font_size", 22)
		prev.pressed.connect(_cycle.bind(attr, -1))
		row.add_child(prev)

		var val: Label = Label.new()
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.custom_minimum_size = Vector2(180, 0)
		val.add_theme_font_size_override("font_size", 16)
		val.add_theme_color_override("font_color", Color(0.95, 0.85, 0.32, 1))
		row.add_child(val)
		_value_labels[attr] = val

		var nxt: Button = Button.new()
		nxt.text = "▶"
		nxt.custom_minimum_size = Vector2(60, 52)
		nxt.add_theme_font_size_override("font_size", 22)
		nxt.pressed.connect(_cycle.bind(attr, 1))
		row.add_child(nxt)

		rows_box.add_child(row)

func _cycle(attr: String, delta: int) -> void:
	var n: int = CharacterSpriteFactory.option_count(attr)
	var cur: int = int(_indices.get(attr, 0))
	_indices[attr] = (cur + delta + n) % n
	_refresh_attr(attr)
	_refresh_preview()

func _refresh_attr(attr: String) -> void:
	var lbl: Label = _value_labels.get(attr) as Label
	if lbl:
		lbl.text = CharacterSpriteFactory.value_label(attr, int(_indices.get(attr, 0)))

func _refresh_all() -> void:
	for attr in CharacterSpriteFactory.ATTRIBUTES:
		_refresh_attr(attr)
	_refresh_preview()

func _refresh_preview() -> void:
	if preview == null:
		return
	var config: Dictionary = CharacterSpriteFactory.config_from_indices(_indices)
	var sheet: ImageTexture = CharacterSpriteFactory.build_sheet(config)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sheet
	# Cellule DOWN / idle (ligne 0, colonne 0) — le perso de face, immobile.
	atlas.region = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	preview.texture = atlas

func _on_random() -> void:
	_indices = CharacterSpriteFactory.random_indices(Time.get_ticks_usec())
	_refresh_all()

func _on_confirm() -> void:
	GameManager.set_player_appearance(_indices)
	SaveSystem.save_game()
	_close()

func _on_cancel() -> void:
	_close()
