function subcommand::hook() {
	use std::string::trim;
	use std::string::matches;

	local _arg_force=off;
	local _arg_dev=off;
	local _arg_syncmeta=off;

	# Parse additional arguments in a fast wae
	local _arg_eval;
	for _arg_eval in "force" "syncmeta"; do {
		case "$@" in
			*${_arg_eval}*)
				eval "_arg_${_arg_eval}=on";
			;;
		esac
	} done
	unset _arg_eval;
	
	local _bigdroid_hooks_root _github_api_root;
	readonly _github_api_root="https://api.github.com";
	readonly _bigdroid_hooks_root="bigdroid-hooks";

	# Sync repometa file
	sync_repometa;


	# Now fetch the project
	local _hook _hook_dir;
	local _path _url _install_path;
	local _repo_source _repo_url _tag_name;
	local _repo_user _repo_name;
	# local _branch_name;

	for _hook in "${@}"; do {	

		# TODO: Think something about repositories with same name

		# Ignore switch args
		if [[ "$_hook" =~ ^-- ]]; then {
			continue;
		} fi

		read -r -d '\n' _repo_source _branch_name _tag_name < <(echo -e "${_hook//::/\\n}") \
		|| log::error "Lacking proper hook information for $_hook" 1 || exit; # It might fail

		if string::matches "$_repo_source" "${_bigdroid_hooks_root}/[a-zA-Z0-9_]"; then { # Short repo name for registered hooks
			_repo_url="https://github.com/${_repo_source}";
			_hook_dir="$_bigdroid_registrydir/${_repo_source//\//_}";
		} elif string::matches "$_repo_source" 'http.*://.*'; then { # Custom git url
			_repo_url="$_repo_source";
			read -r -d '\n' _repo_user _repo_name < <(
				_user="${_repo_source%/*}" && _user="${_user##*/}";
				echo -e "${_user}\n${_repo_source##*/}";
			);
			_hook_dir="$_bigdroid_registrydir/${_repo_user}_${_repo_name}";
		} elif string::matches "$_repo_source" 'file://.*'; then { # Local file path
			_hook_dir="$_repo_source";
			if test ! -e "$_hook_dir"; then {
				log::error "$_hook_dir does not exist" 1 || exit;
			} fi
			_arg_force=off; # Ignore --force arg
			_repo_url=;
		} fi
		
		# Process --force arg
		if test -e "$_hook_dir" && test "$_arg_force" == "on"; then {
			rm -rf "$_hook_dir";
		} fi

		# Clone hook repository if necessary
		if test ! -e "$_hook_dir/.git"; then {
			rm -rf "$_hook_dir";
			mkdir -p "$_hook_dir";
			git clone --recurse-submodules --branch "$_branch_name" "$_repo_source" "$_hook_dir";
		} fi

		# Verify branch and tag
		if test "$_arg_dev" == "off"; then {
			if test "$(git -C "$_hook_dir" branch --show-current)" != "$_branch_name"; then {
				git -C "$_hook_dir" checkout "$_branch_name";
			} fi

			if test "$(git -c "$_hook_dir" rev-parse --short HEAD)" != "$_tag_name"; then {
				git -C "$_hook_dir" checkout "$_tag_name";
			} fi
		} fi

	} done
}
