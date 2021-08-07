function hook::parsemeta() {
	local _input="$1";
	local _hook_dir;
	local _repo_source _repo_url _tag_name;
	local _repo_user _repo_name;
	# local _branch_name;
	
	## Parse hook metadata and declare stuff
	IFS='|' read -r _repo_source _branch_name _tag_name <<<"${_input//::/|}";
	# || log::error "Lacking proper hook information for $_hook" 1 || exit; # It might fail

	if string::matches "$_repo_source" "[a-zA-Z0-9_]"; then { # Short repo name for registered hooks
		_repo_url="https://github.com/${_bigdroid_hooks_root}/${_repo_source}";
		_hook_dir="$_bigdroid_registrydir/${_repo_source//\//_}";
	} elif string::matches "$_repo_source" 'file://.*'; then { # Local file path
		_hook_dir="$_repo_source";
		if test ! -e "$_hook_dir"; then {
			log::error "$_hook_dir does not exist" 1 || exit;
		} fi
		_arg_force=off; # Ignore --force arg
		_repo_url=;
	} elif string::matches "$_repo_source" '.*://.*'; then { # Custom git url
		_repo_url="$_repo_source";
		read -r -d '\n' _repo_user _repo_name < <(
			_user="${_repo_source%/*}" && _user="${_user##*/}";
			echo -e "${_user}\n${_repo_source##*/}";
		);
		_hook_dir="$_bigdroid_registrydir/${_repo_user}_${_repo_name}";
	} fi

	# Return value
	echo "${_repo_source}|${_branch_name}|${_tag_name}|${_repo_url}|${_hook_dir}";
}