#!/usr/bin/env bash

#######################
#######################
##                   ##
##      PRIVATE      ## 
##                   ##
#######################
#######################

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
	for odir in "lower" "worker"; do
		PFUNCNAME="$FUNCNAME::wipedir" println.cmd wipedir "$OVERLAY_DIR/$odir"
	done
	PFUNCNAME="$FUNCNAME::invoke" println.cmd mount -t overlay overlay \
		-olowerdir="$SYSTEM_MOUNT_DIR",upperdir="$OVERLAY_DIR/lower",workdir="$OVERLAY_DIR/worker" "$SYSTEM_MOUNT_DIR"
}

function mount.unload() {
	while read -r _mountpoint; do
		PFUNCNAME="$FUNCNAME" println.cmd umount -fd "$_mountpoint"
	done < <(mount | grep "$MOUNT_DIR" | awk '{print $3}' | sort -r)
}

function mount.load() {
	get.systemimg "$ISO_DIR"
	mount.unload
	
	# System image
	println.cmd mount -o loop "$SYSTEM_IMAGE" "$SYSTEM_MOUNT_DIR"
	test -e "$SYSTEM_MOUNT_DIR/system.img" && {
		PFUNCNAME="$FUNCNAME::loop_sysimg" println.cmd mount -o loop "$SYSTEM_MOUNT_DIR/system.img" "$SYSTEM_MOUNT_DIR"
	}
	mount.overlay

	# Ramdisk images
	PFUNCNAME="$FUNCNAME::wipedir" println.cmd wipedir "$INITIAL_RAMDISK_MOUNT_DIR" "$SECONDARY_RAMDISK_MOUNT_DIR" "$INSTALL_RAMDISK_MOUNT_DIR"
	function ramdisk.extract() {
		function main() {
			local dir="$1"
			local img="$2"
			test -e "$img" && {
				cd "$dir" || return
				zcat "$img" | cpio -iud || return
			}
			:
		}
		
		main "$INITIAL_RAMDISK_MOUNT_DIR" "$ISO_DIR/initrd.img" || return
		main "$INSTALL_RAMDISK_MOUNT_DIR" "$ISO_DIR/install.img" || return
		test -z "$NO_SECONDARY_RAMDISK" && {
			main "$SECONDARY_RAMDISK_MOUNT_DIR" "$ISO_DIR/ramdisk.img" || return
		}
	}
	export -f ramdisk.extract
	PFUNCNAME="$FUNCNAME::extract_ramdisk" println.cmd ramdisk.extract
	unset -f ramdisk.extract
}

function setup.iso() {
	local ISO="$1"
	# Cheanup cache dir
	mount.unload
	PFUNCNAME="$FUNCNAME::wipedir" println.cmd wipedir "$ISO_DIR"
	PFUNCNAME="$FUNCNAME::extract_iso" println.cmd 7z x -o"$ISO_DIR" "$ISO"

	get.systemimg "$ISO_DIR"
	if test "${SYSTEM_IMAGE##*/}" == "system.sfs"; then
		PFUNCNAME="$FUNCNAME::extract_sfs" println.cmd 7z x -o"$ISO_DIR" "$SYSTEM_IMAGE"
		PFUNCNAME="$FUNCNAME::remove_sfs" println.cmd rm "$SYSTEM_IMAGE"
	fi
}

function load.hooks() {
	! mountpoint -q "$SYSTEM_MOUNT_DIR" && {
		(exit 1)
		println "You need to load-image first"
		exit 1
	}
	export PFUNCNAME="$FUNCNAME"
	source "$SRC_DIR/libgearlock.sh" || exit
	println "Attaching hooks"
	if test -e "${HOOKS_LIST_FILE:="$HOOKS_DIR/hooks_list.sh"}"; then
		mapfile -t hooks < <(awk 'NF' < "$HOOKS_LIST_FILE" | sed '/#.*/d' \
							| awk -v hook_dir="$HOOKS_DIR" \
							'{print hook_dir "/"$0"/bigdroid.hook.sh"}')
	else
		readarray -d '' hooks < <(find "$HOOKS_DIR" -type f -name 'bigdroid.hook.sh' -print0)
	fi
	for hook in "${hooks[@]}"; do
		export HOOK_BASE="${hook%/*}"
		println "Hooking ${HOOK_BASE##*/}"
		chmod +x "$hook" || exit
		if test -z "$AUTO_REPLY" || grep -q 'bigdroid.hook.noautoreply' "$hook"; then
			bash -e "$hook" || exit
		else
			yes | bash -e "$hook" || exit
		fi
		unset HOOK_BASE
	done 
	unset PFUNCNAME
}

function build.iso() {
	set -a

	# Cleanup build dir
	PFUNCNAME="wipedir::tmp" println.cmd wipedir "$BUILD_DIR"
	
	# Bring standard ISO components when required
	for item in '.disk' 'boot' 'efi' 'isolinux' 'install.img' 'findme'; do
		test ! -e "$BUILD_DIR/$item" && {
			rsync -a "$SRC_DIR/iso_common/$item" "$BUILD_DIR" || return
		}
	done
	
	# Remove ghome dir if empty
	test -n "$(find "$SYSTEM_MOUNT_DIR/ghome" -maxdepth 0 -empty)" && \
		PFUNCNAME="$FUNCNAME::ghome::wipedir" println.cmd rm -r "$SYSTEM_MOUNT_DIR/ghome"

	# Copy cached files into iso/
	PFUNCNAME="$FUNCNAME::cache_iso" println.cmd rsync -a "$ISO_DIR/" "$BUILD_DIR"
	TEMP_SYSTEM_IMAGE_MOUNT="$TMP_DIR/build_system_mount"

	# Extend system image if necessary
	! mountpoint -q "$SYSTEM_MOUNT_DIR" && {
		mount.load
    }
	get.systemimg "$BUILD_DIR"
	SYSTEM_MOUNT_DIR_SIZE="$(du -sbm "$SYSTEM_MOUNT_DIR" | awk '{print $1}')" || exit
	ORIG_SYSTEM_IMAGE_SIZE="$(du -sbm "$SYSTEM_IMAGE" | awk '{print $1}')" || exit

	test "$(( SYSTEM_MOUNT_DIR_SIZE + 100 ))" -gt "$ORIG_SYSTEM_IMAGE_SIZE" && {
		megs2add="$(( (SYSTEM_MOUNT_DIR_SIZE - ORIG_SYSTEM_IMAGE_SIZE) + 100 ))"
	}

	mountpoint -q "$TEMP_SYSTEM_IMAGE_MOUNT" && {
		PFUNCNAME="$FUNCNAME::unmount_tmp_mp" println.cmd umount -fd "$TEMP_SYSTEM_IMAGE_MOUNT"
	}
	test -n "$megs2add" && {
		function extend.systemimg() {
			dd if=/dev/zero bs=1M count="$megs2add" >> "$SYSTEM_IMAGE" || return
			e2fsck -fy "$SYSTEM_IMAGE" || return
			resize2fs "$SYSTEM_IMAGE" || return
		}
		export -f extend.systemimg
		PFUNCNAME="$FUNCNAME::extend.systemimg" println.cmd extend.systemimg
		unset -f extend.systemimg
	}

	# Put new system image content
	export PFUNCNAME="$FUNCNAME::create_new_system"
	println.cmd mkdir -p "$TEMP_SYSTEM_IMAGE_MOUNT"
	println.cmd mount -o loop "$SYSTEM_IMAGE" "$TEMP_SYSTEM_IMAGE_MOUNT"
	println.cmd wipedir "$TEMP_SYSTEM_IMAGE_MOUNT"
	println.cmd rsync -a "$SYSTEM_MOUNT_DIR/" "$TEMP_SYSTEM_IMAGE_MOUNT"
	# Determine if we need to reduce system image size
	sysimg_freeSpace="$(df -h --output=avail "$TEMP_SYSTEM_IMAGE_MOUNT" | tail -n1 | xargs)"
	test "${sysimg_freeSpace/M/}" -gt 100 && {
		sysimg_reduceSize=true
	}
	println.cmd umount -fd "$TEMP_SYSTEM_IMAGE_MOUNT"
	e2fsck -fy "$SYSTEM_IMAGE" >/dev/null 2>&1
	println.cmd rm -rf "$TEMP_SYSTEM_IMAGE_MOUNT"
	test -n "$sysimg_reduceSize" && {
		sysimg_newSize="$(( (ORIG_SYSTEM_IMAGE_SIZE - ${sysimg_freeSpace/M/}) + 100 ))M"
		PFUNCNAME="$FUNCNAME::reduce_system_size" println.cmd resize2fs "$SYSTEM_IMAGE" "$sysimg_newSize"
		e2fsck -fy "$SYSTEM_IMAGE" >/dev/null 2>&1
	}
	unset PFUNCNAME

	# Create suqashed system image
	test -z "$BUILD_IMG_ONLY" && {
		PFUNCNAME="$FUNCNAME::create_sfs" println.cmd mksquashfs "$SYSTEM_IMAGE" "${SYSTEM_IMAGE%/*}/system.sfs"
		PFUNCNAME="$FUNCNAME::remove_sysimg" println.cmd rm "$SYSTEM_IMAGE"
	}

	# Create new ramdisk images
	function ramdisk.create() {
		function main() {
			local dir="$1"
			local img="$2"
			cd "$dir" || return
			find . | cpio -o -H newc | gzip > "$img" || return
			:
		}
		main "$INITIAL_RAMDISK_MOUNT_DIR" "$BUILD_DIR/initrd.img" || return
		main "$INSTALL_RAMDISK_MOUNT_DIR" "$BUILD_DIR/install.img" || return
		test -z "$NO_SECONDARY_RAMDISK" && {
			main "$SECONDARY_RAMDISK_MOUNT_DIR" "$BUILD_DIR/ramdisk.img" || return
		}
	}
	export -f ramdisk.create
	PFUNCNAME="$FUNCNAME::create_ramdisk" println.cmd ramdisk.create
	unset -f ramdisk.create

	# Now lets finally create an ISO image
	test -z "$BUILD_IMG_ONLY" && {
		function iso.create() {
			(
				OUTPUT_ISO="$BASE_DIR/${DISTRO_NAME}_${DISTRO_VERSION}.iso"
				cd "$BUILD_DIR" || return
				rm -rf '[BOOT]' "$OUTPUT_ISO" || return
				find "$BUILD_DIR" -type f -name 'TRANS.TBL' -delete || return
				genisoimage -vJURT -b isolinux/isolinux.bin -c isolinux/boot.cat \
				-no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot \
				-e boot/grub/efi.img -no-emul-boot -input-charset utf-8 \
				-V "$DISTRO_NAME" -o "$OUTPUT_ISO" . || return
			)
		}
		export -f iso.create
		PFUNCNAME="$FUNCNAME::create_iso" println.cmd iso.create
	}
	:
	
}

#######################
#######################
##                   ##
##      PUBLIC       ## 
##                   ##
#######################
#######################

function gclone(){
	echo -e "============= ${GREEN}Progress${RC} = ${ORANGE}Speed${RC} ========================================"
	rsync -ah --info=progress2 "$@"
}

function println() {
	local RETC="$?"
	: "${PFUNCNAME:="$FUNCNAME"}"
	echo -e "$(date "+%F %T [$(test "$RETC" != 0 && echo "ERROR::$RETC" || echo 'INFO')]") (${0##*/}::$PFUNCNAME): $@"
}

function wipedir() {
	local dir2wipe
	for dir2wipe in "$@"; do
		find "$dir2wipe" -mindepth 1 -maxdepth 1 -exec rm -r '{}' \;
	done
}

function println.cmd() {
	local result args
	args=$(printf '%q ' "$@")
	local string="$@"
	println "Running ${string::69}..."
	result="$(bash -c "$args" 2>&1)"
	local RETC="$?"
	if test "$RETC" != 0; then
		(exit "$RETC")
		println "$result"
		exit "$RETC"
	fi
}
