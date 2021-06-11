#######################
#######################
##                   ##
##      PRIVATE      ##
##                   ##
#######################
#######################

function build.iso() {
	set -a

	# Cleanup build dir
	PFUNCNAME="wipedir::tmp" println.cmd wipedir "$BUILD_DIR"

	# Copy extra iso files
	# mapfile -t items < <(awk 'NF' <<<"$EXTRA_ISO_FILES")
	for item in "${EXTRA_ISO_FILES[@]}"; do
		rsync -a "$ISO_DIR/$item" "$BUILD_DIR" || return
	done
	
	# Bring standard ISO components when required
	for item in '.disk' 'boot' 'efi' 'isolinux' 'install.img' 'findme' 'windows'; do
		test ! -e "$BUILD_DIR/$item" && {
			rsync -a "$SRC_DIR/iso_common/$item" "$BUILD_DIR" || return
		}
	done
	
	# Remove ghome dir if empty
	test -n "$(find "$SYSTEM_MOUNT_DIR/ghome" -maxdepth 0 -empty)" && \
		PFUNCNAME="${FUNCNAME[0]}::ghome::wipedir" println.cmd rm -r "$SYSTEM_MOUNT_DIR/ghome"

	# Copy cached files into iso/
	PFUNCNAME="${FUNCNAME[0]}::cache_iso" println.cmd rsync -a "$ISO_DIR/" "$BUILD_DIR"
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
		PFUNCNAME="${FUNCNAME[0]}::unmount_tmp_mp" println.cmd umount -fd "$TEMP_SYSTEM_IMAGE_MOUNT"
	}
	test -n "$megs2add" && {
		function extend.systemimg() {
			dd if=/dev/zero bs=1M count="$megs2add" >> "$SYSTEM_IMAGE" || return
			e2fsck -fy "$SYSTEM_IMAGE"
			resize2fs "$SYSTEM_IMAGE"
		}
		export -f extend.systemimg
		PFUNCNAME="${FUNCNAME[0]}::extend.systemimg" println.cmd extend.systemimg
		unset -f extend.systemimg
	}

	# Put new system image content
	export PFUNCNAME="${FUNCNAME[0]}::create_new_system"
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
		PFUNCNAME="${FUNCNAME[0]}::reduce_system_size" println.cmd resize2fs "$SYSTEM_IMAGE" "$sysimg_newSize"
		e2fsck -fy "$SYSTEM_IMAGE" >/dev/null 2>&1
	}
	unset PFUNCNAME

	# Create suqashed system image
	test -z "$BUILD_IMG_ONLY" && {
		PFUNCNAME="${FUNCNAME[0]}::create_sfs" println.cmd mksquashfs "$SYSTEM_IMAGE" "${SYSTEM_IMAGE%/*}/system.sfs"
		PFUNCNAME="${FUNCNAME[0]}::remove_sysimg" println.cmd rm "$SYSTEM_IMAGE"
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
	PFUNCNAME="${FUNCNAME[0]}::create_ramdisk" println.cmd ramdisk.create
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
		PFUNCNAME="${FUNCNAME[0]}::create_iso" println.cmd iso.create
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

function setup.iso() {
	local ISO="$1"
	# Cheanup cache dir
	mount.unload
	PFUNCNAME="${FUNCNAME[0]}::wipedir" println.cmd wipedir "$ISO_DIR"
	PFUNCNAME="${FUNCNAME[0]}::extract_iso" println.cmd 7z x -o"$ISO_DIR" "$ISO"

	get.systemimg "$ISO_DIR"
	if test "${SYSTEM_IMAGE##*/}" == "system.sfs"; then
		PFUNCNAME="${FUNCNAME[0]}::extract_sfs" println.cmd 7z x -o"$ISO_DIR" "$SYSTEM_IMAGE"
		PFUNCNAME="${FUNCNAME[0]}::remove_sfs" println.cmd rm "$SYSTEM_IMAGE"
	fi
}

