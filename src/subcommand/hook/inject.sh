function hook::inject() {

	function inject::run_script() {
		local _script="$1";
		sudo -E bash -eEuT -o pipefail \
			-O expand_aliases -O expand_aliases \
				"$_script" || {
								local _r=$?;
								log::error "${_hook_dir##*/} exited with error code $_r" $_r || exit;
							}
		echo "${_script%/*}" >> "$_applied_hooks_statfile";		
	}

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
			# Load native gearlock functions
			use box::libgearlock;

			set -a
			source "$_hook_dir/bd.meta.sh" || log::error "Failed to load ${_hook_dir##*/} metadata" 1 || process::self::exit;
			set +a

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

set -a;
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
set +a;

# TODO: Create a stat holder file and a function to retrieve the status of running hook and/or wait for that hook to complete in a subprocess over another hook.
