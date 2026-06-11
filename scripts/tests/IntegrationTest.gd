extends "res://scripts/tests/IntegrationTestBase.gd"

# Runner des tests d'intégration. Lance chaque groupe dans l'ordre,
# agrège les compteurs, résume et quitte. Découpé depuis l'ancien
# monolithe (2574 l.). Lancé par scenes/tests/IntegrationTest.tscn.

const _GROUPS: Array[Script] = [
	preload("res://scripts/tests/groups/TestGroupLoad.gd"),
	preload("res://scripts/tests/groups/TestGroupWorld.gd"),
	preload("res://scripts/tests/groups/TestGroupNarrative.gd"),
	preload("res://scripts/tests/groups/TestGroupSprites.gd"),
	preload("res://scripts/tests/groups/TestGroupDistricts.gd"),
]

func _ready() -> void:
	await get_tree().process_frame
	print("")
	print("================ INTEGRATION TESTS ================")
	for gs in _GROUPS:
		var g = gs.new()
		add_child(g)
		await g.run()
		_passed += g._passed
		_failed += g._failed
		_failures.append_array(g._failures)
		g.queue_free()
	_summary()
	get_tree().quit(0 if _failed == 0 else 1)
