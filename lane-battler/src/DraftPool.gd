class_name DraftPool
extends RefCounted

var pool: Array = []   # array of UnitData
var recycle_pile: Array = []

func build_pool(roster_a: Array, roster_b: Array) -> void:
	pool.clear()
	recycle_pile.clear()
	# Add all archetypes from both rosters (multiple copies allowed)
	for archetype in roster_a:
		pool.append(archetype)
	for archetype in roster_b:
		pool.append(archetype)
	# Add 2 vanilla copies of each weapon type per GDD v3.0
	# (vanilla units = generic Sword, Axe, Lance with no keyword)
	_add_vanilla_units()
	pool.shuffle()

func _add_vanilla_units() -> void:
	var vanilla_units = [
		preload("res://data/units/t1_basic_striker.tres"),
		preload("res://data/units/t1_basic_tactician.tres"),
		preload("res://data/units/t1_basic_bulwark.tres"),
	]

	for unit in vanilla_units:
		pool.append(unit)
		pool.append(unit)

func draw_three() -> Array:
	var drawn = []
	for i in range(3):
		if pool.is_empty():
			_reshuffle_recycle()
		if not pool.is_empty():
			drawn.append(pool.pop_back())
	return drawn

func recycle(units: Array) -> void:
	recycle_pile.append_array(units)

func _reshuffle_recycle() -> void:
	pool.append_array(recycle_pile)
	recycle_pile.clear()
	pool.shuffle()
