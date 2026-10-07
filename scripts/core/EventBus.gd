extends Node

# Global signal bus. Systems never reference each other directly — they emit and listen here.
# Autoload name: EventBus.

signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)

signal quest_accepted(quest_id: String)
signal quest_updated(quest_id: String, objective_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

signal reputation_changed(axis_name: String, new_value: int)
signal money_changed(new_amount: int)
signal item_acquired(item_id: String, quantity: int)
signal item_consumed(item_id: String, quantity: int)

signal time_of_day_changed(phase: int)

signal interaction_available(interactable: Node)
signal interaction_lost(interactable: Node)
signal interaction_unavailable()

signal minigame_started(minigame_id: String)
signal minigame_ended(minigame_id: String, result: Dictionary)

signal corn_cart_state_changed(carrying: bool)
signal corn_stock_changed(remaining: int)
signal customer_served(npc_id: String)

signal chase_started(chaser_id: String)
signal chase_ended(chaser_id: String, escaped: bool)

# Chronos affichés au HUD (quêtes CHRONO, livraisons dynamiques…). `source`
# identifie l'émetteur ("quest:<id>", "mission:<cat>") pour le clear ciblé.
signal chrono_updated(source: String, label: String, seconds_left: float)
signal chrono_cleared(source: String)

# Bouton ⚽ (sable) → PlayerController lance le mini-jeu Altinha en additif.
signal altinha_requested()

signal debt_paid(amount: int, remaining: int)
signal act_changed(new_act: int)
signal endgame_chosen(path: int)
signal day_elapsed(new_day: int)
# L'épilogue est refermé (« continuer à explorer » ou crédits) : le monde post-desfile reprend.
signal epilogue_closed
signal notification_requested(text: String, color: Color)
