function subcommand::build()
{
	use buildExt;
	use box::utils::logExt;

	print_help()
	{
		println::helpgen ${_self_name^^}-${_subcommand_argv^^} \
			--short-desc "\
${SUBCOMMANDS_DESC[3]}\
" \
	\
			--usage "\
${_self_name} ${_subcommand_argv} [OPTIONAL-OPTIONS] <path>\
" \
	\
			--options-desc "\
--release<^>Build in release mode
--debug<^>Build in debug mode(default)
--run<^>Auto-run the executable after build
--<^>Pass arguments to your compiled program
-h, --help<^>Prints this help information\
" \
	\
			--examples "\
### The basic way:
# Buld the project in your current directory hierarchy in release-mode
${YELLOW}${_self_name} ${_subcommand_argv} --release${RC}

### Build project from a specified directory:
${YELLOW}${_self_name} ${_subcommand_argv} --release /home/me/awesome_project${RC}

### Pass arguments to the compiled executable and auto-run it after build
${YELLOW}${_self_name} ${_subcommand_argv} --release --release -- arg1 arg2 \"string arg\" and-so-on${RC}
"

	}
	use build.clap;
	# (

		### Load the project metadata
		unset NAME CODENAME VERSION AUTHORS IMAGE HOOKS REPOSITORY HOMEPAGE BUGREPORT TAGS;
		source "$_bigdroid_meta_file";
		### Fetch for source image
		if ! test -v IMAGE || test -z "${IMAGE:-}"; then {
			log::error "IMAGE metadata is empty in $_bigdroid_meta_name" 1 || exit;
		} else {
			local _image_source _image_checksum;
			IFS='|' read -r _image_source _image_checksum <<<"${IMAGE//::/|}";
		} fi

		case "$_image_source" in
			http*://*)
				local _local_image_path="$_bigdroid_imagedir/${_image_source##*/}";
				if test ! -e "$_local_image_path"; then {
					# Download image
					log::info "Downloading remote image ${_image_source##*/}";
					wget -c -O "$_local_image_path" "$_image_source";
					# Verify checksum
					log::info "Verifying checksum of ${_local_image_path##*/}";
					local _local_image_checksum;
					_local_image_checksum="$(rstrip "$(sha256sum "$_local_image_path")" " *")";
					if test "$_local_image_checksum" != "$_image_checksum"; then {
						log::error "Checksum mismatch, can not continue" 1 || exit;
					} fi
				} fi
			;;
			
			*)
				local _local_image_path="$_image_source";
			;;
		esac
		
		### Umount tree
		mount::umountTree "$_arg_path";

		### Mount IMAGE
		case "${_local_image_path##*.}" in
			"iso")
				log::info "Mounting IMAGE in RO mode";
				log::rootcmd mount -oro,loop "$_local_image_path" "$_src_dir";
			;;

			*)
				log::warn "${_local_image_path##*/} is a uncommon file-type, trying to extract with 7z";
				log::cmd 7z -aos -o"$_src_dir" "$_local_image_path";
			;;
		esac
		mount::overlayFor "$_src_dir";
		
		#### START SOME VARIABLE EXPORTS

		### Check NO_SECONDARY_RAMDISK
		if test -e "$_src_dir/ramdisk.img"; then {
			export SECONDARY_RAMDISK=true; # EXPORTS
			export SECONDARY_RAMDISK_MOUNT_DIR="$_mount_dir/secondary_ramdisk"; # EXPORTS
		} else {
			export SECONDARY_RAMDISK=false; # EXPORTS
			rm -rf "$SECONDARY_RAMDISK_MOUNT_DIR";
		} fi
		

		#### END SOME VARIABLE EXPORTS
		
		## Bring standard ISO components when required
		ensure::isocommon;
		local _item;
		for _item in '.disk' 'boot' 'efi' 'isolinux' 'install.img' 'findme'; do {
			if test ! -e "$_src_dir/$_item"; then {
				log::cmd rsync -a "$_bigdroid_isocommon_dir/$_item" "$_src_dir/";
			} fi
		} done
		unset _item;

		#### Mount system image
		SYSTEM_IMAGE="$(
			for _img in "system.img" "system.sfs"; do {
				if test -e "$_src_dir/$_img"; then {
					echo "$_src_dir/$_img";
					break;
				} fi
			} done
		)"
		
		if test -n "$SYSTEM_IMAGE"; then {
			export SYSTEM_IMAGE; # EXPORTS
		} else {
			log::error "No SYSTEM_IMAGE was found in src/" 1 || process::self::exit;
		} fi

		log::rootcmd mount -oro,loop "$SYSTEM_IMAGE" "$SYSTEM_MOUNT_DIR";
		if test -e "$SYSTEM_MOUNT_DIR/system.img"; then {
			log::rootcmd mount -oro,loop "$SYSTEM_MOUNT_DIR/system.img" "$SYSTEM_MOUNT_DIR";
		} fi
		mount::overlayFor "$SYSTEM_MOUNT_DIR";
		
		#### Extract ramdisk images
		ramdisk::extract "$_src_dir/initrd.img" "$INITIAL_RAMDISK_MOUNT_DIR";
		ramdisk::extract "$_src_dir/ramdisk.img" "$SECONDARY_RAMDISK_MOUNT_DIR"
		ramdisk::extract "$_src_dir/install.img" "$INSTALL_RAMDISK_MOUNT_DIR";

		### Inject hooks
		# for _hook in "${HOOKS[@]}"; do {
			# Install hook if not presesnt
		subcommand::hook install "${_subcommand_hook_args[@]}" "${HOOKS[@]}";
		subcommand::hook inject "${_subcommand_hook_args[@]}" "${HOOKS[@]}";

			# Inject hooks
			# TODO....
		# } done

	# )	
	

	# Check if hooks only
	if test "$_arg_hooks_only" == "on"; then {
		log::info "Terminating the process without building ISO, only loaded hooks";
		process::self::exit;
	} fi


	# The later build process.....
	# TODO.....
	
	# Remove ghome dir if empty
	if test -n "$(find "$SYSTEM_MOUNT_DIR/ghome" -maxdepth 0 -empty)"; then {
		log::rootcmd rm -r "$SYSTEM_MOUNT_DIR/ghome";
	} fi

	# # Copy cached files into iso/
	# PFUNCNAME="${FUNCNAME[0]}::cache_iso" println.cmd rsync -a "$ISO_DIR/" "$BUILD_DIR"
	# TEMP_SYSTEM_IMAGE_MOUNT="$TMP_DIR/build_system_mount"

	# ! mountpoint -q "$SYSTEM_MOUNT_DIR" && {
	# 	mount.load
    # }

	### Extend system image if necessary
	local _system_mount_dir_size _orig_system_image_size _megs2add;
	local _sysimg_freeSpace _sysimg_reduceSize;
	local TEMP_SYSTEM_IMAGE_MOUNT="$_mount_dir/system_tmp_mount";

	### Fetch system.img out of system.sfs if necessary
	# TODO: See if we can cache system.img for improved performance
	if test "${SYSTEM_IMAGE##*/}" == "system.sfs"; then {
		log::rootcmd 7z x -o"$_src_dir" "$SYSTEM_IMAGE" 'system.img';
		log::rootcmd rm "$SYSTEM_IMAGE"; # Remove system.sfs
		SYSTEM_IMAGE="$_src_dir/system.img";
	} fi

	_system_mount_dir_size="$(runas::root -c 'du -sbm "$SYSTEM_MOUNT_DIR"' | awk '{print $1}')";
	_orig_system_image_size="$(du -sbm "$SYSTEM_IMAGE" | awk '{print $1}')";

	if test "$(( _system_mount_dir_size + 100 ))" -gt "$_orig_system_image_size"; then {
		_megs2add="$(( (_system_mount_dir_size - _orig_system_image_size) + 100 ))"
	} fi

	# if mountpoint -q "$TEMP_SYSTEM_IMAGE_MOUNT"; then {
	# 	log::rootcmd umount -fd "$TEMP_SYSTEM_IMAGE_MOUNT"
	# } fi

	if test -v "_megs2add"; then {
		log::rootcmd dd if=/dev/zero bs=1M count="$_megs2add" >> "$SYSTEM_IMAGE";
		log::rootcmd e2fsck -fy "$SYSTEM_IMAGE";
		log::rootcmd resize2fs "$SYSTEM_IMAGE";
	} fi

	# Put new system image content
	# export PFUNCNAME="${FUNCNAME[0]}::create_new_system"
	mkdir -p "$TEMP_SYSTEM_IMAGE_MOUNT";
	log::rootcmd mount -orw,loop "$SYSTEM_IMAGE" "$TEMP_SYSTEM_IMAGE_MOUNT"
	# println.cmd wipedir "$TEMP_SYSTEM_IMAGE_MOUNT"
	log::rootcmd rsync -a --delete "$SYSTEM_MOUNT_DIR/" "$TEMP_SYSTEM_IMAGE_MOUNT"
	# Determine if we need to reduce system image size
	_sysimg_freeSpace="$(runas::root 'df -h --output=avail "$TEMP_SYSTEM_IMAGE_MOUNT"' | tail -n1 | xargs)"
	if test "${_sysimg_freeSpace/M/}" -gt 100; then {
		_sysimg_reduceSize=true;
	} fi

	log::rootcmd umount -fd "$TEMP_SYSTEM_IMAGE_MOUNT";
	log::rootcmd e2fsck -fy "$SYSTEM_IMAGE" >/dev/null 2>&1
	log::rootcmd rm -rf "$TEMP_SYSTEM_IMAGE_MOUNT"
	if test -v "_sysimg_reduceSize"; then {
		local sysimg_newSize;
		sysimg_newSize="$(( (_orig_system_image_size - ${_sysimg_freeSpace/M/}) + 100 ))M"
		log::rootcmd resize2fs "$SYSTEM_IMAGE" "$sysimg_newSize";
		log::rootcmd e2fsck -fy "$SYSTEM_IMAGE" >/dev/null 2>&1
	} fi
	

	# Create suqashed system image
	if test "$_arg_image_only" == "off"; then {
		log::rootcmd chmod 644 "$SYSTEM_IMAGE";
		log::rootcmd mksquashfs "$SYSTEM_IMAGE" "$_src_dir/system.sfs";
		log::rootcmd rm "$SYSTEM_IMAGE"; # Remove system.img
	} fi

	# Create new ramdisk images
	ramdisk::create "$INITIAL_RAMDISK_MOUNT_DIR" "$_src_dir/initrd.img";
	ramdisk::create "$INSTALL_RAMDISK_MOUNT_DIR" "$_src_dir/install.img";
	if test "$SECONDARY_RAMDISK" == true; then {
		ramdisk::create "$SECONDARY_RAMDISK_MOUNT_DIR" "$_src_dir/ramdisk.img";
	} fi

	# Now lets finally create an ISO image
	if test "$_arg_image_only" == "off"; then {

		(
			OUTPUT_ISO="$_target_workdir/${CODENAME}_${VERSION}.iso";
			cd "$_src_dir";
			log::rootcmd rm -rf '[BOOT]';
			log::rootcmd find . -type f -name 'TRANS.TBL' -delete;
			genisoimage -vJURT -b isolinux/isolinux.bin -c isolinux/boot.cat \
			-no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot \
			-e boot/grub/efi.img -no-emul-boot -input-charset utf-8 \
			-V "$CODENAME" -o "$OUTPUT_ISO" .;
		)

	} fi
	
}
