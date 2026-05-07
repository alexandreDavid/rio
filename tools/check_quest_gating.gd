extends SceneTree

# Vérification one-shot : charge tous les .tres de quête, valide la cohérence
# du gating (MAIN/SIDE + prerequisite_quest_ids résolvent vers des IDs existants).

func _init() -> void:
	var dir := DirAccess.open("res://resources/quests/")
	var quests: Dictionary = {}
	var errors: Array[String] = []

	for fname in dir.get_files():
		if not fname.ends_with(".tres"):
			continue
		var path := "res://resources/quests/" + fname
		var res = load(path)
		if not res is Quest:
			errors.append("%s : pas une Quest" % path)
			continue
		var q: Quest = res
		if q.id.is_empty():
			errors.append("%s : id vide" % path)
			continue
		if quests.has(q.id):
			errors.append("Doublon d'id %s" % q.id)
		quests[q.id] = q

	for id in quests:
		var q: Quest = quests[id]
		for prereq in q.prerequisite_quest_ids:
			if not quests.has(prereq):
				errors.append("%s : prereq inconnu '%s'" % [id, prereq])

	var main_count := 0
	var side_count := 0
	for id in quests:
		if (quests[id] as Quest).quest_type == Quest.QuestType.MAIN:
			main_count += 1
		else:
			side_count += 1
	print("MAIN = %d, SIDE = %d, total = %d" % [main_count, side_count, quests.size()])
	for e in errors:
		printerr("  ! ", e)
	if errors.is_empty():
		print("OK — gating cohérent.")
		quit(0)
	else:
		quit(1)
