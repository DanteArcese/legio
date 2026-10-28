extends "res://tests/test_case.gd"
## The bank panel's search and sort.

const GameUi := preload("res://scripts/ui/game_ui.gd")


func test_search_filters_by_name_and_sort_orders_them() -> void:
	var slots := [{"item": "raw_tuna", "quantity": 3}, null, {"item": "bronze_bar", "quantity": 5}, {"item": "cooked_tuna", "quantity": 2}]
	check_eq(GameUi.bank_view(slots, "", false).size(), 3, "everything, minus empty slots")
	var tuna := GameUi.bank_view(slots, "  TUNA ", false).map(func(s): return s["item"])
	check_eq(tuna, ["raw_tuna", "cooked_tuna"], "search ignores case and spaces, keeps deposit order")
	var sorted := GameUi.bank_view(slots, "", true).map(func(s): return s["item"])
	check_eq(sorted, ["bronze_bar", "raw_tuna", "cooked_tuna"], "by name: Bronze bar, Raw tuna, Tuna")
