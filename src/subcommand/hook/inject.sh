function hook::inject() {
	local _hook;
	for _hook in "${@}"; do {
		internal::escapeRunArgs "$_hook";

		local _hook_dir;
		IFS='|' read -r _ _ _ _ _hook_dir <<<"$(hook::parsemeta "$_hook")";
		

	} done
}
