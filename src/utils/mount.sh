function mount.overlay() {
	for odir in "lower" "worker"; do
		PFUNCNAME="${FUNCNAME[0]}::wipedir" println.cmd wipedir "$OVERLAY_DIR/$odir"
	done
	PFUNCNAME="${FUNCNAME[0]}::invoke" println.cmd mount -t overlay overlay \
		-olowerdir="$SYSTEM_MOUNT_DIR",upperdir="$OVERLAY_DIR/lower",workdir="$OVERLAY_DIR/worker" "$SYSTEM_MOUNT_DIR"
}

function mount.unload() {
	while read -r _mountpoint; do
		PFUNCNAME="${FUNCNAME[0]}" println.cmd umount -fd "$_mountpoint"
	done < <(mount | grep "$MOUNT_DIR" | awk '{print $3}' | sort -r)
}

function mount.load() {
	get.systemimg "$ISO_DIR"
	mount.unload
	
	# System image
	PFUNCNAME="${FUNCNAME[0]}::loop_sysimg" println.cmd mount -o loop "$SYSTEM_IMAGE" "$SYSTEM_MOUNT_DIR"
	test -e "$SYSTEM_MOUNT_DIR/system.img" && {
		PFUNCNAME="${FUNCNAME[0]}::loop_sysimg" println.cmd mount -o loop "$SYSTEM_MOUNT_DIR/system.img" "$SYSTEM_MOUNT_DIR"
	}
	mount.overlay

	# Ramdisk images
	PFUNCNAME="${FUNCNAME[0]}::wipedir" println.cmd wipedir "$INITIAL_RAMDISK_MOUNT_DIR" "$SECONDARY_RAMDISK_MOUNT_DIR" "$INSTALL_RAMDISK_MOUNT_DIR"
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
	PFUNCNAME="${FUNCNAME[0]}::extract_ramdisk" println.cmd ramdisk.extract
	unset -f ramdisk.extract
}