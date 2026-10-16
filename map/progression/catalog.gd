extends RefCounted

static func configure(manager: Node) -> void:
	for id in ["warrior", "mage", "ranger"]:
		manager.classes[id] = load("res://progression/data/" + id + ".tres")
	manager.deities["sun_god"] = preload("res://progression/data/sun_god.tres")
	for id in ["learn_mage", "learn_ranger", "sun_ascension"]:
		manager.rituals[id] = load("res://progression/data/" + id + ".tres")

static func recipe(id: String) -> ClassRecipe:
	if id not in ["mage_recipe", "ranger_recipe"]:
		return null
	return load("res://progression/data/" + id + ".tres") as ClassRecipe
