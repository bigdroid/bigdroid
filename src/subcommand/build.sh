function subcommand::build()
{

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
	(

		# Load the project metadata
		source "$_bigdroid_meta_file";

		# Fetch for source image
		if test -z "$IMAGE"; then {
			log::error "IMAGE metadata is empty in $_bigdroid_meta_name" 1 || exit;
		} fi
		case "$IMAGE" in
			http*://*)
				local _image_local_path="$_bigdroid_imagedir/${IMAGE##*/}";
				if test ! -e "$_image_local_path"; then {
					# Download image
					log::info "Downloading remote image ${IMAGE##*/}";
					wget -c -O "$_image_local_path" "$IMAGE";
					# Verify checksum
					log::info "Verifying checksum of ${_image_local_path##*/}";
					local _local_image_checksum;
					_local_image_checksum="$(rstrip "$(sha256sum "$_image_local_path")" " *")";
					if test "$_local_image_checksum" != "$IMAGE_CHECKSUM"; then {
						log::error "Checksum mismatch, can not continue" 1 || exit;
					} fi
				} fi
			;;
			
			*)
				local _image_local_path="$IMAGE";
			;;
		esac
		

		# Resolve hooks
		for _hook in "${HOOKS[@]}"; do {
			# Install hook if not presesnt
			subcommand::hook install "$_hook";

			# Inject hooks
			# TODO....
		} done

	)	
	# The later build process.....
	# TODO.....


}