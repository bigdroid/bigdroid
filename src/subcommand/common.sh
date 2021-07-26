function common::fetch_image() {
	local _input="$1";
	local _input_local_path="$2";
	if test ! -e "$_input_local_path"; then {
		case "$_input" in
			http*://*)
				println::info "Downloading remote image ${_input##*/}";
				wget -c -O "$_input_local_path" "$_input";
				;;
		esac
	} fi
}