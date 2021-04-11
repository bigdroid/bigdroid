#!/usr/bin/env bash

set -a

###
# Load private functions
###
SRC_DIR="$(dirname "$(readlink -f "$0")")"
source "$SRC_DIR/utils.sh" || exit

###
# Ensure we are ROOOOOOT
###
test "$(whoami)" != "root" && {
	(exit 1)
	PFUNCNAME="root_check" println "Please run as root user"
	exit 1
}

###
# Define variables and set them up
###
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

set +a

# CLAP
for arg in "${@}"; do
	case "$arg" in
		--setup-iso)
			shift
			setup.iso "$1"
		;;
		--clean-cache)
			println.cmd wipedir "$ISO_DIR"
		;;
		--unload-image)
			mount.unload
		;;
		--load-image)
			mount.load
		;;
		--auto-reply)
			export AUTO_REPLY=true
		;;
		--load-hooks)
			load.hooks
		;;
		--build-image)
			BUILD_IMG_ONLY=true
			build.iso
		;;
		--build-iso)
			build.iso
		;;
	esac
done
