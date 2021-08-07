function hook::install() {
	
	local _hook;
	for _hook in "${@}"; do {	

		internal::escapeRunArgs "$_hook";

		local _repo_source _branch_name _tag_name _repo_url _hook_dir
		IFS='|' read -r _repo_source _branch_name _tag_name _repo_url _hook_dir <<<"$(hook::parsemeta "$_hook")";
		
		# Set defaults for _branch_name and _tag_name if empty
		: "${_branch_name:="main"}";
		: "${_tag_name:="HEAD"}";

		# Process --force arg and remove command
		if test "$_arg_force" == "on"; then {
			rm -rf "$_hook_dir";
		} fi

		# Clone hook repository if necessary
		if test ! -e "$_hook_dir/.git"; then {
			rm -rf "$_hook_dir";
			mkdir -p "$_hook_dir";
			git clone --recurse-submodules --branch "$_branch_name" --single-branch "$_repo_url" "$_hook_dir";
		} elif test "$_arg_dev" == "off"; then { # Check for required_branch existence
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
			# if is_short_hash "$_tag_name"; then {
				local _local_hash _required_hash;
				_local_hash="$(git -C "$_hook_dir" rev-parse HEAD)";
				_required_hash="$(git -C "$_hook_dir" rev-parse "$_tag_name" 2>&1)" || true;
				if test "$_local_hash" != "$_required_hash"; then {
					checkout_commit "$_hook_dir" "$_tag_name";
				} fi
			# } else { # When is friendly tag name
			# 	local _fetched_tag_name;
			# 	_fetched_tag_name="$(git -C "$_hook_dir" name-rev --tags --name-only "$(git rev-parse HEAD)" 2>&1)";
			# 	if string::matches "$_fetched_tag_name" "Skipping\."; then { # Some sort of error checking
			# 		checkout_commit "$_hook_dir" "$_tag_name";
			# 	} elif test "$_fetched_tag_name" != "$_tag_name"; then {
			# 		checkout_commit "$_hook_dir" "$_tag_name";
			# 	} fi
			# } fi
		} fi


	# Perform inject operation
	if test "$_argv" == "inject"; then {
		:	
	} fi

	} done
}
