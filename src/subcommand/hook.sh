function subcommand::hook() {
	
	function is_short_hash() {
		local _input="$1";
		if string::matches "$_input" '[+-]?([0-9]*[.])[0-9]+'; then {
			return 1; # Is a standard git version tag
		} else {
			return 0; # Is a short git hash
		} fi
	}

	function internal::main() {
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
		

			## Parse hook metadata and declare stuff
			read -r -d '\n' _repo_source _branch_name _tag_name < <(echo -e "${_hook//::/\\n}") || true;
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

			## Process remove command
			if test "$_argv" == "remove"; then {
				rm -rf "$_hook_dir"
				continue; # Exit the loop
			} fi
			
			# Process --force arg and remove command
			if test "$_arg_force" == "on"; then {
				rm -rf "$_hook_dir";
			} fi

			# Clone hook repository if necessary
			if test ! -e "$_hook_dir/.git"; then {
				rm -rf "$_hook_dir";
				mkdir -p "$_hook_dir";
				git clone --recurse-submodules --branch "$_branch_name" --single-branch "$_repo_url" "$_hook_dir";
			} elif test "$_arg_dev" == "off"; then {
				if ! git -C "$_hook_dir" branch -a | grep -m1 -E "(.*/)?\b${_branch_name}\b$" >/dev/null 2>&1; then { # Verify if we have the required branch
					log::warn "${_branch_name} does not locally exist for ${_repo_source}, trying to fetch it";
					git -C "$_hook_dir" remote set-branches --add origin "$_branch_name";
					git -C "$_hook_dir" fetch;
					# git -C "$_hook_dir" checkout "$_branch_name" # Necessary? Guess not
				} fi
			} fi

			# Verify branch and tag
			if test "$_arg_dev" == "off"; then {

				## I learned that it is pointless to match branch as commit hashes are not related with these.
				# local _fetched_branch_name;
				# _fetched_branch_name="$(git -C "$_hook_dir" branch --show-current)";
				# if test "$_fetched_branch_name" != "$_branch_name"; then {
				# 	git -C "$_hook_dir" checkout "$_branch_name";
				# } fi

				function checkout_commit() {
					local _dir="$1";
					local _hash="$2";

					if ! git -C "$_dir" -c advice.detachedHead=false checkout "$_hash"; then {
						log::warn "Failed to checkout $_hash on ${_dir##*/} over ${_branch_name} branch, do you want to retry with auto full fetch? [Y/n] \c";
						local _user_keypress && read -n1 -r _user_keypress && echo;
						if test "${_user_keypress,,}" == "y"; then {
							git -C "$_dir" fetch --all;
							git -C "$_dir" -c advice.detachedHead=false checkout "$_hash" || {
								log::error "Failed to checkout $_hash even after a full fetch, probably invalid hash" 1 || exit;
							}
						} else {
							log::error "Okay then you may resolve the issue manually and rerun the build" 1 || exit;
						} fi
					} fi
				}
				
				# When is a short/long hash
				if is_short_hash "$_tag_name"; then {
					if test "$(git -C "$_hook_dir" rev-parse HEAD)" != "$(git -C "$_hook_dir" rev-parse "$_tag_name")"; then {
						checkout_commit "$_hook_dir" "$_tag_name";
					} fi
				} else { # When is friendly tag name
					local _fetched_tag_name;
					_fetched_tag_name="$(git -C "$_hook_dir" name-rev --tags --name-only "$(git rev-parse HEAD)" 2>&1)";
					if string::matches "$_fetched_tag_name" "Skipping\."; then { # Some sort of error checking
						checkout_commit "$_hook_dir" "$_tag_name";
					} elif test "$_fetched_tag_name" != "$_tag_name"; then {
						checkout_commit "$_hook_dir" "$_tag_name";
					} fi
				} fi
			} fi

		} done
	}

	function internal::list() {
		local _hook;
		local _hook_dirname;
		# local _hook_branchname;
		local _hook_tagname;
		for _hook in "$_bigdroid_registrydir/"*; do {
			_hook_dirname="${_hook##*/}";
			# _hook_branchname="$(git -C "$_hook" branch --show-current)";
			_hook_tagname="$(git -C "$_hook" rev-parse --short HEAD)";

			echo "${_hook_dirname}::${_hook_tagname}";
		} done
	}

	local _argv="$1" && shift;
	case "$_argv" in
		install | remove)
			internal::main "$@";
		;;
		list)
			internal::list "$@";
		;;
		*)
			println::error "Unknown subcommand $_argv"
		;;
	esac
}
