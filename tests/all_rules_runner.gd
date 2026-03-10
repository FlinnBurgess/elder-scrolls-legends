extends SceneTree

const RegressionCatalog = preload("res://tests/regression_catalog.gd")


func _initialize() -> void:
	var failures: Array = []
	var project_root := ProjectSettings.globalize_path("res://")
	var executable_path := OS.get_executable_path()
	for suite in RegressionCatalog.core_suites():
		var output: Array = []
		var arguments := PackedStringArray(["--headless", "--path", project_root, "--script", str(suite.get("script", ""))])
		var exit_code := OS.execute(executable_path, arguments, output, true)
		var joined_output := "\n".join(output)
		print("[%s] exit=%d" % [str(suite.get("id", "")), exit_code])
		if not joined_output.is_empty():
			print(joined_output)
		if exit_code != 0:
			failures.append("%s failed with exit code %d." % [str(suite.get("label", suite.get("id", "suite"))), exit_code])
			continue
		var success_token := str(suite.get("success_token", ""))
		if not success_token.is_empty() and success_token not in joined_output:
			failures.append("%s did not emit success token `%s`." % [str(suite.get("label", suite.get("id", "suite"))), success_token])
	if failures.is_empty():
		print("ALL_RULES_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)