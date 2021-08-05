readonly _bigdroid_meta_name="Bigdroid.meta";
readonly _bigdroid_home="${HOME:-"${0%/*}"}/.bigdroid" && mkdir -p "$_bigdroid_home";
readonly _bigdroid_registrydir="$_bigdroid_home/registry" && mkdir -p "$_bigdroid_registrydir";
readonly _bigdroid_imagedir="$_bigdroid_home/image" && mkdir -p "$_bigdroid_imagedir";
readonly _bigdroid_isocommon_dir="$_bigdroid_home/iso_common";

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


function variables() {	
	
	###
	# Define variables and set them up
	###
	
	set -a;
	SRC_DIR="$(dirname "$(readlink -f "$0")")"
	BASE_DIR="$(readlink -f "${0%/*}")"
	PATH="$BASE_DIR/bin:$PATH"

	HOOKS_DIR="$BASE_DIR/hooks" && {
		PFUNCNAME="hook_dir" println.cmd mkdir -p "$HOOKS_DIR"
		chmod -f 777 "$HOOKS_DIR"
	}

	MOUNT_DIR="$BASE_DIR/mount" && {
		for _dir in system secondary_ramdisk initial_ramdisk install_ramdisk; do
			PFUNCNAME="mount_dir" println.cmd mkdir -p "$MOUNT_DIR/$_dir" && chmod 755 "$MOUNT_DIR/$_dir"
			eval "${_dir^^}_MOUNT_DIR=\"$MOUNT_DIR/$_dir\""
		done
	}

	ISO_DIR="$BASE_DIR/iso" && {
		PFUNCNAME="create::iso_dir" println.cmd mkdir -p "$ISO_DIR" && chmod 755 "$ISO_DIR"
	}

	BUILD_DIR="$BASE_DIR/build" && {
		PFUNCNAME="create::build_dir" println.cmd mkdir -p "$BUILD_DIR"
	}

	TMP_DIR="$BASE_DIR/tmp" && {
		PFUNCNAME="create::tmp_dir" println.cmd mkdir -p "$TMP_DIR"
	}

	OVERLAY_DIR="$BASE_DIR/overlay" && {
		export PFUNCNAME="overlay_dir"
		println.cmd mkdir -p "$OVERLAY_DIR"
		for odir in lower worker; do
			println.cmd mkdir -p "$OVERLAY_DIR/$odir" && chmod 755 "$OVERLAY_DIR/$odir"
		done
		unset PFUNCNAME
	}

	test ! -e "$ISO_DIR/ramdisk.img" && {
		NO_SECONDARY_RAMDISK=true
	}

	# Dependencie check
	REQUIRED_UTILS=(
		e2fsck
		mksquashfs
		genisoimage
		dd
		7z
		rsync
		find
		grep
	)
	for prog in "${REQUIRED_UTILS[@]}"; do
		! command -v "$prog" 1>/dev/null && {
			MISSING_UTILS+="$prog "
		}
	done
	test -n "$MISSING_UTILS" && {
		(exit 1)
		println "Please install the following programs before using: $MISSING_UTILS"
		exit 1
	}

	# Read distro config
	DISTRO_NAME="Bigdroid"
	DISTRO_VERSION="Cake"
	test -e "${DISTRO_CONFIG:="$HOOKS_DIR/distro.sh"}" && {
		source "$DISTRO_CONFIG" || exit
	}

	# Extra variables
	## Related with hook::
	export COMMON_HOOK_FILE_NAME="bd.hook.sh"
	export APPLIED_HOOKS_STAT_FILE="$TMP_DIR/.applied_hooks"
	export GENERATED_HOOKS_LIST_FILE="$TMP_DIR/.generated_hooks"

	set +a


}