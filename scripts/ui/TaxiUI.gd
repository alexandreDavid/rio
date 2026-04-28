extends CanvasLayer

# Overlay qui ouvre la liste des destinations taxi disponibles. La liste est
# construite dynamiquement à l'ouverture en fonction de DistrictManager.current().
# Sélection → DistrictManager.travel_to(id) (avec paiement de la course).

@onready var panel: Control = $Root
@onready var dest_layout: VBoxContainer = $Root/Panel/Margin/Layout/Destinations
@onready var status_label: Label = $Root/Panel/Margin/Layout/Status
@onready var close_button: Button = $Root/Panel/Margin/Layout/Footer/Close

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(close)
	# Si l'argent change pendant que l'UI est ouverte, on rafraîchit le statut.
	EventBus.money_changed.connect(_on_money_changed)

func open() -> void:
	visible = true
	_refresh()
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _refresh() -> void:
	if dest_layout == null:
		return
	# Reset les boutons.
	for child in dest_layout.get_children():
		child.queue_free()
	# Construire un bouton par destination dispo.
	for id in DistrictManager.available_destinations():
		var btn: Button = Button.new()
		var fare: int = DistrictManager.get_fare(id)
		var label: String = DistrictManager.get_label(id)
		if fare > 0:
			btn.text = "%s  ·  R$ %d" % [label, fare]
		else:
			btn.text = label
		btn.theme_type_variation = ""
		btn.pressed.connect(func(): _on_destination_pressed(id))
		dest_layout.add_child(btn)
	_update_status()

func _on_destination_pressed(district_id: String) -> void:
	if DistrictManager.travel_to(district_id):
		close()
	else:
		# Échec (probablement pas assez d'argent) : on signale.
		_update_status_insufficient(district_id)

func _on_money_changed(_amount: int) -> void:
	if visible:
		_update_status()

func _update_status() -> void:
	if status_label == null:
		return
	var inv: Inventory = null
	if GameManager.player:
		inv = GameManager.player.get_node_or_null("Inventory") as Inventory
	var money: int = inv.money if inv else 0
	status_label.text = "Tu as R$ %d en poche." % money
	status_label.modulate = Color(0.95, 0.92, 0.85, 1)

func _update_status_insufficient(district_id: String) -> void:
	if status_label == null:
		return
	var fare: int = DistrictManager.get_fare(district_id)
	status_label.text = "Pas assez pour la course (%d R$ requis)." % fare
	status_label.modulate = Color(0.95, 0.4, 0.4, 1)
