extends RefCounted
## Base class for tests. Test scripts extend this and define methods named
## test_*; the runner calls each one and collects failures from check().

var failures: PackedStringArray = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message := "") -> void:
	check(actual == expected, "%s: expected %s, got %s" % [message, expected, actual])


func check_near(actual: Variant, expected: Variant, message := "") -> void:
	check(actual.is_equal_approx(expected), "%s: expected %s, got %s" % [message, expected, actual])
