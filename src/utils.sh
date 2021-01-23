#!/usr/bin/env bash

#######################
#######################
##                   ##
##      PRIVATE      ## 
##                   ##
#######################
#######################

function println() {
	local RETC="$?"
	: "${PFUNCNAME:="$FUNCNAME"}"
	echo -e "$(date "+%F %T [$(test "$RETC" != 0 && echo "ERROR::$RETC" || echo 'INFO')]") (${0##*/}::$PFUNCNAME): $@"
}

function println.cmd() {
	local result args
	args=$(printf '%q ' "$@")
	println "Running $1"
	result="$(bash -c "$args" 2>&1)"
	local RETC="$?"
	if test "$RETC" != 0; then
		(exit "$RETC")
		println "$result"
		exit "$RETC"
	fi
}

function clean.cache() {
	export PFUNCNAME="$FUNCNAME"
	println.cmd find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -exec rm -r '{}' \;
}

function mount.overlay() {
	export PFUNCNAME="$FUNCNAME"
	for odir in "lower" "worker"; do
		println.cmd find "$OVERLAY_DIR/$odir" -mindepth 1 -maxdepth 1 -exec rm -r '{}' \;
	done
	println.cmd mount -t overlay overlay \
		-olowerdir="$SYSTEM_MOUNT_DIR",upperdir="$OVERLAY_DIR/lower",workdir="$OVERLAY_DIR/worker" "$SYSTEM_MOUNT_DIR"
}

function mount.unload() {
	export PFUNCNAME="$FUNCNAME"
	while read -r _mountpoint; do
		println.cmd umount -fd "$_mountpoint"
	done < <(mount | grep "$MOUNT_DIR" | awk '{print $3}' | sort -r)
}

function mount.load() {
	export PFUNCNAME="$FUNCNAME"
	export SYSTEM_IMAGE="$(
		if test -e "$CACHE_DIR/system.img"; then
			echo "$CACHE_DIR/system.img"
		elif test -e "$CACHE_DIR/system.sfs"; then
			echo "$CACHE_DIR/system.sfs"
		fi
	)"

	# System image
	mount.unload
	println.cmd mount -o loop "$SYSTEM_IMAGE" "$SYSTEM_MOUNT_DIR"
	test -e "$SYSTEM_MOUNT_DIR/system.img" && {
		println.cmd mount -o loop "$SYSTEM_MOUNT_DIR/system.img" "$SYSTEM_MOUNT_DIR"
	}
	mount.overlay

	# Ramdisk images
	println.cmd find "$INITIAL_RAMDISK_MOUNT_DIR" "$SECONDARY_RAMDISK_MOUNT_DIR" \
		-mindepth 1 -maxdepth 1 -exec rm -r '{}' \;
	function extract.ramdisk() {
		cd "$INITIAL_RAMDISK_MOUNT_DIR" || return
		zcat "$CACHE_DIR/initrd.img" | cpio -iud || return
		cd "$SECONDARY_RAMDISK_MOUNT_DIR" || return
		zcat "$CACHE_DIR/ramdisk.img" | cpio -iud || return
	}
	export -f extract.ramdisk
	println.cmd extract.ramdisk
	unset -f extract.ramdisk
}

function setup.iso() {
	export PFUNCNAME="$FUNCNAME"
	local ISO="$1"
	# Cheanup cache dir
	mount.unload
	clean.cache
	println.cmd 7z x -o"$CACHE_DIR" "$ISO"
}

function load.hooks() {
	export PFUNCNAME="$FUNCNAME"
	println "Loading hooks"
	while read -r -d '' hook; do
		export HOOK_BASE="${hook%/*}"
		println "Hooking ${HOOK_BASE##*/}"
		chmod +x "$hook" || exit
		"$hook" || exit
		unset HOOK_BASE
	done < <(find "$HOOK_DIR" -type f -name 'bigdroid.hook.sh' -print0)
}


#######################
#######################
##                   ##
##      PUBLIC       ## 
##                   ##
#######################
#######################

