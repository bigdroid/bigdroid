function hook::inject() {

	function inject::run_script() {
		local _script="$1";
		bash -eEuT -o pipefail \
			-O expand_aliases -O expand_aliases \
				"$_script" || {
								local _r=$?;
								log::error "${_hook_dir##*/} exited with error code $_r" $_r || exit;
							}
	}

	local _hook;
	for _hook in "${@}"; do {
		internal::escapeRunArgs "$_hook";

		local _hook_dir;
		IFS='|' read -r _ _ _ _ _hook_dir <<<"$(hook::parsemeta "$_hook")";
		
		# Ignore hook if necessary
		if test -e "$_hook_dir/bd.ignore.sh"; then {
			continue;
		} fi

		# Read metadata
		(
			# Load native gearlock functions
			use box::libgearlock;

			set -a
			source "$_hook_dir/bd.meta.sh" || log::error "Failed to load ${_hook_dir##*/} metadata" 1 || exit;
			set +a

			# Satisfy dependencies
			for _dep in "${DEPENDENCIES[@]}"; do
				hook::install "$_dep";
			done
			
			log::info "Hooking ${_hook_dir##*/}";
			chmod +x "$_hook_dir/bd.hook.sh";

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
##      PRIVATE      ##
##                   ##
#######################
#######################

# function load.hooks() {
# # TODO: Better error message



	# function hook::parse_option() {
	# 	local input="$1"
	# 	local range="${2:-1}"
	# 	local values
	# 	values=($(sed 's|,| |g' <<<"$input"))

	# 	local lines
	# 	for value in "${values[@]}"; do
	# 		lines+="$(echo -e "\n${value}")"
	# 	done

	# 	# If the specified range is larger than input string
	# 	# Then we just return the 1st line.
	# 	if test "$(wc -l <<<"$lines")" -lt "$range"; then
	# 		head -n1 <<<"$lines"
	# 	else
	# 		sed -n "${range}p" <<<"$lines"
	# 	fi
	# }

#######################
#######################
##                   ##
##      PUBLIC       ##
##                   ##
#######################
#######################

function hook::fetch_path() {
	local HOOK_NAME="$1"
	test -z "$GENERATED_HOOKS_LIST_FILE" \
		&& RETC=1 println "\$GENERATED_HOOKS_LIST_FILE variable is not defined" && exit 1

	local HOOK_DIR
	HOOK_DIR="$(grep -I "/.*/$HOOK_NAME/$COMMON_HOOK_FILE_NAME" "$GENERATED_HOOKS_LIST_FILE")"

	if test -z "$HOOK_DIR"; then
		RETC=1 println "Failed to fetch HOOK_DIR"
		exit 1
	else
		echo "${HOOK_DIR%/*}"
	fi

}

function hook::wait_until_done() {
	local HOOK_NAME
	test ! -e "$APPLIED_HOOKS_STAT_FILE" && return 1
	until grep -qI "^${HOOK_NAME}\b" "$APPLIED_HOOKS_STAT_FILE"; do
		sleep 0.2
	done
}

# TODO: Create a stat holder file and a function to retrieve the status of running hook and/or wait for that hook to complete in a subprocess over another hook.
