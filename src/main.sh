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
HOOK_DIR="$BASE_DIR/hook" && {
	PFUNCNAME="hook_dir" println.cmd mkdir -p "$HOOK_DIR"
	chmod -f 777 "$HOOK_DIR"
}

MOUNT_DIR="$BASE_DIR/mount" && {
	for _dir in system secondary_ramdisk initial_ramdisk install_ramdisk; do
		PFUNCNAME="mount_dir" println.cmd mkdir -p "$MOUNT_DIR/$_dir" && chmod 755 "$MOUNT_DIR/$_dir"
		eval "${_dir^^}_MOUNT_DIR=\"$MOUNT_DIR/$_dir\""
	done
}

ISO_DIR="$BASE_DIR/cache" && {
	PFUNCNAME="cache_dir" println.cmd mkdir -p "$ISO_DIR" && chmod 755 "$ISO_DIR"
}

BUILD_DIR="$BASE_DIR/build" && {
	PFUNCNAME="create::build_tmp" println.cmd mkdir -p "$BUILD_DIR"
	PFUNCNAME="wipedir::tmp" println.cmd wipedir "$BUILD_DIR"
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

# Read distro config
test -e "${DISTRO_CONFIG=:"$HOOK_DIR/distro.sh"}" && {
	source "$DISTRO_CONFIG" || exit
}

: "${DISTRO_NAME:="Bigdroid"}"
: "${DISTRO_VERSION:="Cake"}"

set +a

# CLAP
case "$1" in
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
