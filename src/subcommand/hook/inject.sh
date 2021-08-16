function hook::inject() {
	use bashbox::header;

	# function inject::run_script() {
	# 	local _script="$1";
	# 	local _orig_script && _orig_script=$(< "$_script");

	# 	echo "$_bashbox_bootstrap" > "$_script";
	# 	echo "${_orig_script}" >> "$_script";

	# 	# Exports
	# 	HOOK_DIR="${_script%/*}" \
	# 	SRC_DIR="$_src_dir"	\
	# 	MOUNT_DIR="$_mount_dir" \
	# 	TMP_DIR="$_tmp_dir" \
	# 	runas::root "$BASH" -eEuT "$_script" || {
	# 							local _r=$?;
	# 							echo "${_orig_script}" > "$_script";
	# 							log::error "${_hook_dir##*/} exited with error code $_r" $_r || process::self::exit;
	# 						}
	# 	echo "${_orig_script}" > "$_script";
	# 	echo "${_script%/*}" >> "$_applied_hooks_statfile";
	# 	# git -C "${_script%/*}" checkout "$_bigdroid_common_hook_file_name";
	# }

	local _sudo_wrapper="$_bigdroid_home/.sudoWrapper";
	local _hook_header="$_bigdroid_home/.hookHeader";
	export _sudo_wrapper _hook_header _arg_reply_yes; # Exports
	export _src_dir _mount_dir _tmp_dir; # Exports

	# Bootstrap
	local _bashbox_bootstrap;
	local _bd_hook_header_bootstrap;
	_bashbox_bootstrap=$(declare -f bb_bootstrap_header) && {
		_bashbox_bootstrap="${_bashbox_bootstrap#*{}";
		_bashbox_bootstrap="${_bashbox_bootstrap%\}}";
	}
	_bd_hook_header_bootstrap="$(
		echo '#!'"$(command -v env) bash";
		echo '___self_PID=$$;';
		_func=$(declare -f 'process::self::exit')
		echo "$_func";
		echo "$_bashbox_bootstrap";
		
	)"
	_bd_sudo_wrapper_bootstrap="$(
		echo "$_bd_hook_header_bootstrap";
		FUNC_LIST=(
			geco
			gclone
			wipedir
			mount::umountTree
			mount::overlayFor
			mount::overlay
			hook::parsemeta
			hook::fetch_path
			hook::wait_until_done
			log::info
			log::warn
			log::cmd
			log::rootcmd
		)

		for _func in "${FUNC_LIST[@]}"; do {
			_func_content=$(declare -f "$_func");
			echo "$_func_content; export -f $_func";
		} done

cat <<'EOF'
function bash_run() {
	function err() {
		_r=$?;
		sed -i '1d' "$_script";
		log::error "${HOOK_DIR##*/} exited with error code $_r" $_r || exit;
	}

	local _input="$1";
	"$BASH" -eEuT -o pipefail -O inherit_errexit "$_input" || err;
	sed -i '1d' "$_script";

}

# Export log::error
export -f log::error process::self::exit;

# Use gearlock stuff
use box::libgearlock;

for _script in "${@}"; do {

	set -a && source "${_script%/*}/bd.meta.sh" && set +a;
	# _orig_script=$(< "$_script");
	sed -i "1i trap 'exit 1' USR1 && ___self_PID=\$\$ && trap 'BB_ERR_MSG=\"UNCAUGHT EXCEPTION\" log::error \"\$BASH_COMMAND\" || process::self::exit' ERR;" "$_script";
	read;

	# Exports
	unset HOOK_DIR SRC_DIR MOUNT_DIR TMP_DIR;
	export HOOK_DIR="${_script%/*}";
	export SRC_DIR="$_src_dir";
	export MOUNT_DIR="$_mount_dir";
	export TMP_DIR="$_tmp_dir";

	log::info "Hooking ${HOOK_DIR##*/}";

	if test "$_arg_reply_yes" != "on" && test "${INTERACTIVE:-}" != "true"; then
		bash_run "$_script";
	else
		yes | bash_run "$_script";
	fi

	# echo "${_orig_script}" > "$_script";
	echo "${_script%/*}" >> "$_applied_hooks_statfile";

} done

EOF

	)";	
	
	# Create sudo wrapper
	echo "$_bd_sudo_wrapper_bootstrap" > "$_sudo_wrapper";
	echo "$_bd_hook_header_bootstrap" > "$_hook_header";

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
			source "$_hook_dir/bd.meta.sh" || log::error "Failed to load ${_hook_dir##*/} metadata" 1 || process::self::exit;

			# Satisfy dependencies
			for _dep in "${DEPENDENCIES[@]}"; do
				hook::install "$_dep";
			done

			
			# chmod +x "$_hook_dir/$_bigdroid_common_hook_file_name";

		)
		HOOK_SCRIPTS+=("$_hook_dir/$_bigdroid_common_hook_file_name");
	} done
	runas::root "$BASH" -eEuT "$_sudo_wrapper" "${HOOK_SCRIPTS[@]}" || process::self::exit;
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
