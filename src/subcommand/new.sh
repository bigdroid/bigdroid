function subcommand::new()
{
	local _arg_name _arg_codename;
	local _arg_version _arg_image;
	local _arg_homepage _arg_repository;
	local _arg_bugreport;
	use new.clap;

	## When no codename || template is specified
	: "${_arg_codename:="${_arg_path##*/}"}";
	_arg_codename="$(tr -d '[:space:]' <<<"${_arg_codename,,}")" # Make lowercase and trim whitespaces

	## When the dir already exists
	if test -e "$_arg_path"; then
		log::error "Destination \`$_arg_path\` already exists.\n\t  You may either remove that project dir or use a different path for setup." 1 || exit;
	fi


	## Finally setup
	if test -z "$_arg_image"; then {
		log::warn "No --image was specified, initializing in blind-mode";
	} else {
		local _image_checksum && {
			case "$_arg_image" in
				http*://*)
					local _image_local_path="$_bigdroid_imagedir/${_arg_image##*/}";
					if test ! -e "$_image_local_path"; then {
						log::info "Downloading remote image ${_arg_image##*/}";
						wget -c -O "$_image_local_path" "$_arg_image";
					} fi
					;;
				*)
					local _image_local_path="$_arg_image";
					;;
			esac
			log::info "Calculating checksum of ${_image_local_path##*/}";
			_image_checksum="$(rstrip "$(sha256sum "$_image_local_path")" " *")";
		}
	} fi
	log::info "Setting up project at \`$_arg_path\`"
	mkdir -p "$_arg_path" || log::error "Failed to initialize the project directory" 1 || exit;

	# println::info "Resetting CODENAME metadata to $_arg_codename on $_bashbox_meta_name"
	# sed -i "s|\bCODENAME=\".*\"|CODENAME=\"$_arg_codename\"|g" "$_arg_path/$_bashbox_meta_name" \
	# 	|| { rm -r "$_arg_path"; println::error "Failed to reset CODENAME metadata on $_bashbox_meta_name"; }

	log::info "Initializing git version control for your project"
	if command -v git 1>/dev/null; then
		git init "$_arg_path" 1>/dev/null || { 
			local _r=$?; rm -rf "$_arg_path";
			log::error "Failed to initialize git at \`$_arg_path\`" $_r || exit;
		}
		local _git_user_email _git_user_name;
		_git_user_email="$(git config --global user.email || echo 'example@email.com')";
		_git_user_name="$(git config --global user.name || echo 'randomguy')";
		# Create project
		cat << EOF > "$_arg_path/$_bigdroid_meta_name"
NAME="${_arg_name:-}"
CODENAME="${_arg_codename:-}"
AUTHORS=("${_git_user_name} <${_git_user_email}>")
VERSION="${_arg_version:-"0.1.0"}"
IMAGE="${_arg_image:-}::${_image_checksum:-}"
HOOKS=()
HOMEPAGE="${_arg_homepage:-}"
REPOSITORY="${_arg_repository:-}"
BUGREPORT="${_arg_bugreport:-}"
TAGS=()
EOF

		# Create .gitignore
		cat << 'EOF' >> "$_arg_path/.gitignore";
/target
/mount
/src
EOF

	# TODO: Add a standard README.md with instructions
	
	else
		rm -r "$_arg_path"
		log::error "git does not seem to be available, please install it" 1 || exit;
	fi
}
