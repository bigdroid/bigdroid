readonly _bigdroid_meta_name="Bigdroid.meta";
readonly _bigdroid_home="${HOME:-"${0%/*}"}/.bigdroid" && mkdir -p "$_bigdroid_home";
readonly _bigdroid_registrydir="$_bigdroid_home/registry" && mkdir -p "$_bigdroid_registrydir";
readonly _bigdroid_imagedir="$_bigdroid_home/image" && mkdir -p "$_bigdroid_imagedir";
readonly _bigdroid_isocommon_dir="$_bigdroid_home/iso_common";
readonly _bigdroid_common_hook_file_name="bd.hook.sh";

readonly _build_dir_name="build";
readonly _hooks_dir_name="hooks";
readonly _src_dir_name="src";
readonly _mount_dir_name="mount";
readonly _overlay_dir_name="overlay";
readonly _tmp_dir_name="tmp";
readonly _target_dir_name="target";
readonly _release_dir_name="release";
readonly _debug_dir_name="debug";

readonly SUBCOMMANDS_DESC=(
	""
	"Create a new bashbox project"
	"Directly run a bashbox project"
	"Compile a bashbox project"
	"Cleanup target/ directories"
	"Install a bashbox project from repo"
	"Install bashbox into PATH"
);

# Exports
_var_exports=(
	_bigdroid_registrydir
	_bigdroid_common_hook_file_name
)
for _var in "${_var_exports[@]}"; do {
	export "$_var";
} done


function ttttt______variables() {	

	# Dependencie check
	local REQUIRED_UTILS;
	REQUIRED_UTILS=(
		curl
		rsync
		cpio
		coreutils
		"e2fsprogs|e2fsck"
		findutils
		gnugrep
		wget
		file
		mksquashfs
		genisoimage
		p7zip
	)

	for prog in "${REQUIRED_UTILS[@]}"; do
		if ! command -v "$prog" 1>/dev/null; then {
			MISSING_UTILS+=("$prog");
		} fi
	done

	if test -v "MISSING_UTILS"; then {
		println "Please install the following programs before using: $MISSING_UTILS"
		exit 1
	} fi

}
