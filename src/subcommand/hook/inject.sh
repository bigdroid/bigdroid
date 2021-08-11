function hook::inject() {

	function inject::run_script() {
		local _script="$1";
		# Exports
		HOOK_DIR="${_script%/*}" \
		SRC_DIR="$_src_dir"	\
		MOUNT_DIR="$_mount_dir" \
		TMP_DIR="$_tmp_dir" \
		runas::root -c "source $_bigdroid_sudo_function_file; $_script" || {
								local _r=$?;
								log::error "${_hook_dir##*/} exited with error code $_r" $_r || process::self::exit;
							}
		echo "${_script%/*}" >> "$_applied_hooks_statfile";		
	}

	extract::bashFuncToFile "$_bigdroid_sudo_function_file" "geco" "gclone" "wipedir" "mount::umountTree" "mount::overlayFor" "mount::overlay";
	extract::bashFuncToFile "$_bigdroid_sudo_function_file" "hook::parsemeta" "hook::fetch_path" "hook::wait_until_done";

	local _hook;
	for _hook in "${@}"; do {
		
		if [[ "$_hook" =~ ^-- ]]; then {
			continue;
		} fi

		local _hook_dir;
		IFS='|' read -r _ _ _ _ _hook_dir <<<"$(hook::parsemeta "$_hook")";
		
		# Ignore hook if necessary
		if test -e "$_hook_dir/bd.ignore.sh"; then {
			continue;
		} fi

		# Read metadata
		(
			# Load native gearlock functions and the project metadata
			use box::libgearlock;
			source "$_hook_dir/bd.meta.sh" || log::error "Failed to load ${_hook_dir##*/} metadata" 1 || process::self::exit;

			# Satisfy dependencies
			for _dep in "${DEPENDENCIES[@]}"; do
				hook::install "$_dep";
			done
			
			log::info "Hooking ${_hook_dir##*/}";
			chmod +x "$_hook_dir/$_bigdroid_common_hook_file_name";

			if test "$_arg_reply_yes" != "on" && test "${INTERACTIVE:-}" != "true"; then
				inject::run_script "$_hook_dir/$_bigdroid_common_hook_file_name";
			else
				yes | inject::run_script "$_hook_dir/$_bigdroid_common_hook_file_name";
			fi
		)
		
	} done
}

#######################
#######################
##                   ##
##      PUBLIC       ##
##                   ##
#######################
#######################

function hook::fetch_path() {
	local _hook="$1";
	local _hook_dir;
	IFS='|' read -r _ _ _ _ _hook_dir <<<"$(hook::parsemeta "$_hook")";

	echo "$_hook_dir"; # Return value
}

function hook::wait_until_done() {

	local _hook="$1";
	local _hook_dir;
	IFS='|' read -r _ _ _ _ _hook_dir <<<"$(hook::parsemeta "${_hook}")";
	until grep -qI "^${_hook_dir}$" "$_applied_hooks_statfile"; do {
		sleep 0.2;
	} done

}


# TODO: Create a stat holder file and a function to retrieve the status of running hook and/or wait for that hook to complete in a subprocess over another hook.
