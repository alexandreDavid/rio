class_name QuestObjective
extends Resource

# Kind mécanique : comment l'objectif se complète.
# MANUEL  : posé par le contenu (dialogue on_choose, script) — comportement historique.
# MINIJEU : auto-complété quand `minigame_id` se termine avec qualifies/won.
# CHRONO  : doit être complété dans `time_limit_sec` après l'acceptation, sinon la quête échoue.
# FUITE   : auto-complété quand le joueur sème une course-poursuite (chase_ended escaped).
enum Kind { MANUEL = 0, MINIJEU = 1, CHRONO = 2, FUITE = 3 }

@export var id: String = ""
@export var description: String = ""
@export var optional: bool = false
@export var kind: int = Kind.MANUEL
@export var minigame_id: String = ""     # MINIJEU : id EventBus du mini-jeu à réussir
@export var time_limit_sec: float = 0.0  # CHRONO : délai en secondes après l'acceptation
@export var chaser_id: String = ""       # FUITE : ne compte que ce poursuivant ("" = tous)
