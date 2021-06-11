#!/usr/bin/env bash

use utils;
use clap;

function main() {
	set -a

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

	clap "$@"
}

main "$@"
