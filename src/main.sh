#!/usr/bin/env bash

set -a

###
# Load private functions
###
source "$(dirname "$(readlink -f "$0")")/utils.sh" || exit

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
HOOK_DIR="$BASE_DIR/hooks" && {
	PFUNCNAME="hook_dir" println.cmd mkdir -p "$HOOK_DIR"
}

MOUNT_DIR="$BASE_DIR/mount" && {
	for _dir in system secondary_ramdisk initial_ramdisk; do
		PFUNCNAME="mount_dir" println.cmd mkdir -p "$MOUNT_DIR/$_dir" && chmod 755 "$MOUNT_DIR/$_dir"
		eval "${_dir^^}_MOUNT_DIR=\"$MOUNT_DIR/$_dir\""
	done
}

CACHE_DIR="$BASE_DIR/cache" && {
	PFUNCNAME="cache_dir" println.cmd mkdir -p "$CACHE_DIR" && chmod 755 "$CACHE_DIR"
}

OVERLAY_DIR="$BASE_DIR/overlay" && {
	export PFUNCNAME="overlay_dir"
	println.cmd mkdir -p "$OVERLAY_DIR"
	for odir in lower worker; do
		println.cmd mkdir -p "$OVERLAY_DIR/$odir" && chmod 755 "$OVERLAY_DIR/$odir"
	done
}

set +a

# CLAP
case "$1" in
	--setup-iso)
		shift
		setup.iso "$1"
	;;
	--clean-cache)
		clean.cache
	;;
	--clean-overlay)
		mount.unload
	;;
	--setup-image)
		mount.load
	;;
	--load-hooks)
		load.hooks
	;;
	--build-image)

	;;
	--build-iso)

esac
