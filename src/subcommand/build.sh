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
		source "$_bigdroid_meta_file";

		### Fetch for source image
		if test -z "$IMAGE"; then {
			log::error "IMAGE metadata is empty in $_bigdroid_meta_name" 1 || exit;
		} fi
		case "$IMAGE" in
			http*://*)
				local _local_image_path="$_bigdroid_imagedir/${IMAGE##*/}";
				if test ! -e "$_local_image_path"; then {
					# Download image
					log::info "Downloading remote image ${IMAGE##*/}";
					wget -c -O "$_local_image_path" "$IMAGE";
					# Verify checksum
					log::info "Verifying checksum of ${_local_image_path##*/}";
					local _local_image_checksum;
					_local_image_checksum="$(rstrip "$(sha256sum "$_local_image_path")" " *")";
					if test "$_local_image_checksum" != "$IMAGE_CHECKSUM"; then {
						log::error "Checksum mismatch, can not continue" 1 || exit;
					} fi
				} fi
			;;
			
			*)
				local _local_image_path="$IMAGE";
			;;
		esac
		
		### Umount tree
		mount::umountTree "$_arg_path";

		### Mount IMAGE
		case "${_local_image_path##*.}" in
			"iso")
				log::info "Mounting IMAGE in RO mode";
				log::cmd sudo mount -oro,loop "$_local_image_path" "$_src_dir";
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
		
		### Bring standard ISO components when required
		# ensure::isocommon;
		# local _item;
		# for _item in '.disk' 'boot' 'efi' 'isolinux' 'install.img' 'findme'; do {
		# 	if test ! -e "$_src_dir/$_item"; then {
		# 		log::cmd rsync -a "$_bigdroid_isocommon_dir/$_item" "$_src_dir/";
		# 	} fi
		# } done
		# unset _item;

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
			export SYSTEM_IMAGE;
		} else {
			log::error "No SYSTEM_IMAGE was found in src/" 1 || exit;
		} fi

		log::cmd sudo mount -oro,loop "$SYSTEM_IMAGE" "$SYSTEM_MOUNT_DIR";
		if test -e "$SYSTEM_MOUNT_DIR/system.img"; then {
			log::cmd sudo mount -oro,loop "$SYSTEM_MOUNT_DIR/system.img" "$SYSTEM_MOUNT_DIR";
		} fi
		mount::overlayFor "$SYSTEM_MOUNT_DIR";


		

		### Inject hooks
		# for _hook in "${HOOKS[@]}"; do {
			# Install hook if not presesnt
		subcommand::hook install "${HOOKS[@]}";
		# subcommand::hook inject "${HOOKS[@]}";

			# Inject hooks
			# TODO....
		# } done

	# )	
	# The later build process.....
	# TODO.....


}