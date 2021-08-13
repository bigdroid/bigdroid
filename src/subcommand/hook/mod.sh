function subcommand::hook() {
	use parsemeta;
	use install;
	use inject;
	use remove;
	use list;
	
	local _bigdroid_hooks_root _github_api_root;
	# readonly _github_api_root="https://api.github.com";
	readonly _bigdroid_hooks_root="bigdroid-hooks";

	local _arg_force=off;
	local _arg_dev=off;
	local _arg_sync=off;
	# local _arg_syncmeta=off;

	# Parse additional arguments in a fast wae
	local _arg_eval;
	for _arg_eval in "force" "dev" "sync"; do {
		case "$@" in
			*--${_arg_eval}*)
				eval "_arg_${_arg_eval}=on";
			;;
		esac
	} done
	unset _arg_eval;

	function is_short_hash() {
		local _input="$1";
		if string::matches "$_input" '[+-]?([0-9]*[.])[0-9]+'; then {
			return 1; # Is a standard git version tag
		} else {
			return 0; # Is a short git hash
		} fi
	}

	local _argv="$1" && shift;
	case "$_argv" in
		install | remove | inject | list)
			hook::$_argv "$@";
		;;
		*)
			println::error "Unknown subcommand $_argv"
		;;
	esac
}
