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



function load.hooks() {
# TODO: Better error message



	function hook::parse_option() {
		local input="$1"
		local range="${2:-1}"
		local values
		values=($(sed 's|,| |g' <<<"$input"))

		local lines
		for value in "${values[@]}"; do
			lines+="$(echo -e "\n${value}")"
		done

		# If the specified range is larger than input string
		# Then we just return the 1st line.
		if test "$(wc -l <<<"$lines")" -lt "$range"; then
			head -n1 <<<"$lines"
		else
			sed -n "${range}p" <<<"$lines"
		fi
	}

	function hook::install() {
		(
			HOOK_NAME="$1"
			HOOK_PATH="$(hook::fetch_path "$HOOK_NAME")"
			export HOOK_BASE="$HOOK_PATH"

			# Ignore hook if necessary
			if test -e "$HOOK_PATH/bd.ignore.sh"; then
				exit 0
			fi

			# Read metadata
			set -a
			source "$HOOK_PATH/bd.meta.sh" ||	{
													r=$?
													RETC=$r println "Failed to load $HOOK_NAME metadata"
													exit $r
												}
			set +a
			# Satisfy dependencies
			for dep in "${DEPENDS[@]}"; do
				! grep -qI "^${dep}\b" "$APPLIED_HOOKS_STAT_FILE" && {
					hook::install "$dep" || exit
				}
			done
			
			println "Hooking ${HOOK_NAME}"
			chmod +x "$HOOK_PATH/$COMMON_HOOK_FILE_NAME" || exit

			if test -z "$AUTO_REPLY" \
				|| test "$(hook::parse_option "$INTERACTIVE" 1)" == yes; then
				bash -e "$HOOK_PATH/$COMMON_HOOK_FILE_NAME" || exit
			else
				yes | bash -e "$HOOK_PATH/$COMMON_HOOK_FILE_NAME" || exit
			fi

			# Log the installed hook on success
			echo "$CODENAME" >> "$APPLIED_HOOKS_STAT_FILE"
			unset HOOK_BASE
		)
	}


	### Starting point of the function
	##################################

	# A lazy way to assume if we have mountpoints loaded up
	! mountpoint -q "$SYSTEM_MOUNT_DIR" && {
		(exit 1)
		println "You need to load-image first"
		exit 1
	}

	# Cleanup previously created statfile if exists
	for _file in "$APPLIED_HOOKS_STAT_FILE" "$GENERATED_HOOKS_LIST_FILE"; do
		test -e "$_file" && {
			rm "$_file" || exit
		}
	done
	touch "$APPLIED_HOOKS_STAT_FILE" || exit

	# Load native gearlock functions
	source "$SRC_DIR/libgearlock.sh" || exit

	println "Attaching hooks"

	# Get the list of hooks
	if test -e "${HOOKS_LIST_FILE:="$HOOKS_DIR/hooks_list.sh"}"; then
		mapfile -t hooks < <(awk 'NF' < "$HOOKS_LIST_FILE" | sed '/#.*/d' \
							| awk -v hook_dir="$HOOKS_DIR" -v file_name="$COMMON_HOOK_FILE_NAME" \
							'{print hook_dir "/"$0"/file_name"}')
	else
		readarray -d '' hooks < <(find "$HOOKS_DIR" -type f -name "$COMMON_HOOK_FILE_NAME" -print0)
	fi

	# Generate the hooks list
	for hook in "${hooks[@]}"; do
		echo "$hook" >> "$GENERATED_HOOKS_LIST_FILE" || exit
	done

	# Process the hooks
	for hook in "${hooks[@]}"; do

		hook="${hook%/*}"
		hook="${hook##*/}"

		! grep -qI "^${hook}\b" "$APPLIED_HOOKS_STAT_FILE" && {
			hook::install "${hook}" || { 
					r=$?
					RETC=$r println "The last hook invoking exited unexpectedly"
					exit $r
				}
		}

		unset hook

	done

	unset PFUNCNAME
	unset APPLIED_HOOKS_STAT_FILE
}

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

function gclone(){
	echo -e "============= ${GREEN}Progress${RC} = ${ORANGE}Speed${RC} ========================================"
	rsync -ah --info=progress2 "$@"
}

function println() {
	local RETC
	local PFUNCNAME
	: "${RETC:="$?"}"
	: "${PFUNCNAME:="${FUNCNAME[0]}"}"
	export PFUNCNAME # Expose the function name to other intances
	echo -e "$(date "+%F %T [$(test "$RETC" != 0 && echo "ERROR::$RETC" || echo 'INFO')]") (${0##*/}::$PFUNCNAME): $@"
}

function wipedir() {
	local dir2wipe
	for dir2wipe in "$@"; do
		if [ -e "$dir2wipe" ]; then
			find "$dir2wipe" -mindepth 1 -maxdepth 1 -exec rm -r '{}' \;
		fi
	done
}

function println.cmd() {
	local result args
	args=$(printf '%q ' "$@")
	local string="$@"
	println "Running ${string:0:$((69 - ${#PFUNCNAME}))}..."
	result="$(bash -c "$args" 2>&1)"
	local RETC="$?"
	if test "$RETC" != 0; then
		(exit "$RETC")
		println "$result"
		exit "$RETC"
	fi
}

function hook::fetch_path() {
	local HOOK_NAME="$1"
	test -z "$GENERATED_HOOKS_LIST_FILE" \
		&& RETC=1 println "\$GENERATED_HOOKS_LIST_FILE variable is not defined" && exit 1

	local HOOK_DIR
	HOOK_DIR="$(grep -I "/.*/$HOOK_NAME/$COMMON_HOOK_FILE_NAME" "$GENERATED_HOOKS_LIST_FILE")"

	if test -z "$HOOK_DIR"; then
		RETC=1 println "Failed to fetch HOOK_DIR"
		exit 1
	else
		echo "${HOOK_DIR%/*}"
	fi

}

function hook::wait_until_done() {
	local HOOK_NAME
	test ! -e "$APPLIED_HOOKS_STAT_FILE" && return 1
	until grep -qI "^${HOOK_NAME}\b" "$APPLIED_HOOKS_STAT_FILE"; do
		sleep 0.2
	done
}

# TODO: Create a stat holder file and a function to retrieve the status of running hook and/or wait for that hook to complete in a subprocess over another hook.
