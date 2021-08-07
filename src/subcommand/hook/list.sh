function hook::list() {
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
