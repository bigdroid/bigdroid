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

function wipedir() {
	#export PFUNCNAME="$FUNCNAME"
	local dir2wipe="$1"
	find "$dir2wipe" -mindepth 1 -maxdepth 1 -exec rm -r '{}' \;
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

function get.systemimg() {
	local IMG_BASE="$1"
	export SYSTEM_IMAGE="$(
		if test -e "$IMG_BASE/system.img"; then
			echo "$IMG_BASE/system.img"
		elif test -e "$IMG_BASE/system.sfs"; then
			echo "$IMG_BASE/system.sfs"
		else
			(exit 1)
			println "System image not found"
			exit 1
		fi
	)"
}

function mount.overlay() {
	export PFUNCNAME="$FUNCNAME"
	for odir in "lower" "worker"; do
		println.cmd wipedir "$OVERLAY_DIR/$odir"
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

	get.systemimg "$CACHE_DIR"

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
	function ramdisk.extract() {
		cd "$INITIAL_RAMDISK_MOUNT_DIR" || return
		zcat "$CACHE_DIR/initrd.img" | cpio -iud || return
		test -z "$NO_SECONDARY_RAMDISK" && {
			cd "$SECONDARY_RAMDISK_MOUNT_DIR" || return
			zcat "$CACHE_DIR/ramdisk.img" | cpio -iud || return
		}
	}
	export -f ramdisk.extract
	println.cmd ramdisk.extract
	unset -f ramdisk.extract
}

function setup.iso() {
	export PFUNCNAME="$FUNCNAME"
	local ISO="$1"
	# Cheanup cache dir
	mount.unload
	println.cmd wipedir "$CACHE_DIR"
	println.cmd 7z x -o"$CACHE_DIR" "$ISO"

	get.systemimg "$CACHE_DIR"
	if test "${SYSTEM_IMAGE##*/}" == "system.sfs"; then
		println.cmd 7z x -o"$CACHE_DIR" "$SYSTEM_IMAGE"
		println.cmd rm "$SYSTEM_IMAGE"
	fi
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

function build.iso() {
	export PFUNCNAME="$FUNCNAME"
	set -a
	ISO_DIR="$BASE_DIR/iso" && {
		println.cmd mkdir -p "$ISO_DIR"
		println.cmd wipedir "$ISO_DIR"
	}
	TEMP_SYSTEM_IMAGE_MOUNT="$ISO_DIR/.systemimg_mount"

	# Copy cached files into iso/
	println.cmd rsync -a "$CACHE_DIR/" "$ISO_DIR"

	# Detect whether if we need to extend original system image
	! mountpoint -q "$SYSTEM_MOUNT_DIR" && {
		mount.load
    }
	get.systemimg "$ISO_DIR"
	SYSTEM_MOUNT_DIR_SIZE="$(du -sbm "$SYSTEM_MOUNT_DIR" | awk '{print $1}')" || exit
	ORIG_SYSTEM_IMAGE_SIZE="$(du -sbm "$SYSTEM_IMAGE" | awk '{print $1}')" || exit

	test "$(( SYSTEM_MOUNT_DIR_SIZE + 100 ))" -gt "$ORIG_SYSTEM_IMAGE_SIZE" && {
		megs2add="$(( (SYSTEM_MOUNT_DIR_SIZE - ORIG_SYSTEM_IMAGE_SIZE) + 100 ))"
	}

	# Extend system image if necessary
	mountpoint -q "$TEMP_SYSTEM_IMAGE_MOUNT" && {
		println.cmd umount -fd "$TEMP_SYSTEM_IMAGE_MOUNT"
	}
	test -n "$megs2add" && {
		function extend.systemimg() {
			dd if=/dev/zero bs=1M count="$megs2add" >> "$SYSTEM_IMAGE" || return
			e2fsck -fy "$SYSTEM_IMAGE" || return
			resize2fs "$SYSTEM_IMAGE" || return
		}
		export -f extend.systemimg
		println.cmd extend.systemimg
		unset -f extend.systemimg
	}

	# Put new system image content
	println.cmd mkdir -p "$TEMP_SYSTEM_IMAGE_MOUNT"
	println.cmd mount -o loop "$SYSTEM_IMAGE" "$TEMP_SYSTEM_IMAGE_MOUNT"
	println.cmd wipedir "$TEMP_SYSTEM_IMAGE_MOUNT"
	println.cmd rsync -a "$SYSTEM_MOUNT_DIR/" "$TEMP_SYSTEM_IMAGE_MOUNT"
	println.cmd umount -fd "$TEMP_SYSTEM_IMAGE_MOUNT"
	println.cmd rm -rf "$TEMP_SYSTEM_IMAGE_MOUNT"
	test -z "$BUILD_IMG_ONLY" && {
		println.cmd mksquashfs "$SYSTEM_IMAGE" "${SYSTEM_IMAGE%/*}/system.sfs"
	}

	# Create new ramdisk images
	function ramdisk.create() {
		cd "$INITIAL_RAMDISK_MOUNT_DIR" || exit
		find . | cpio -o -H newc | gzip > "$ISO_DIR/initrd.img" || return
		test -z "$NO_SECONDARY_RAMDISK" && {
			cd "$SECONDARY_RAMDISK_MOUNT_DIR" || exit
			find . | cpio -o -H newc | gzip > "$ISO_DIR/ramdisk.img" || return
		}
	}
	export -f ramdisk.create
	println.cmd ramdisk.create
	unset -f ramdisk.create

	# Now lets finally create an ISO image
	test -z "$BUILD_IMG_ONLY" && {
		function iso.create() {
			export PFUNCNAME="$FUNCNAME"
			(
				OUTPUT_ISO="$BASE_DIR/${DISTRO_NAME}_${DISTRO_VERSION}.iso"
				cd "$ISO_DIR" || exit
				rm -rf '[BOOT]'
				genisoimage -vJURT -b isolinux/isolinux.bin -c isolinux/boot.cat \
				-no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot \
				-e boot/grub/efi.img -no-emul-boot -input-charset utf-8 \
				-V "$DISTRO_NAME" -o "$OUTPUT_ISO" .
			)
		}
		export -f iso.create
		println.cmd iso.create
	}
	
}

#######################
#######################
##                   ##
##      PUBLIC       ## 
##                   ##
#######################
#######################

