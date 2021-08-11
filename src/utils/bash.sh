function extract::bashFuncToFile() {
	local _func _func_content;
	local _output_file="$1" && shift;

	for _func in "${@}"; do {
		_func_content=$(declare -f "$_func");
		echo "$_func_content" >> "$_output_file";
		echo "export -f $_func" >> "$_output_file";
	} done
}