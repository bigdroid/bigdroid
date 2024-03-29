#######################
#######################
##                   ##
##      PRIVATE      ##
##                   ##
#######################
#######################

function ensure::isocommon() {
	if test ! -e "$_bigdroid_isocommon_dir/.git"; then {
		wipedir "$_bigdroid_isocommon_dir";
		log::info "Fetching isocommon repository";
		log::cmd git clone https://github.com/supremegamers/awin-installer-dev "$_bigdroid_isocommon_dir";
	} fi
}

function ramdisk::extract() {
	local _ramdisk_image="$1";
	local _extract_dir="$2";
	local _image_type;
	_image_type="$(file "$_ramdisk_image")";

	(
		wipedir "$_extract_dir";
		mkdir -p "$_extract_dir" && cd "$_extract_dir";
		log::info "Extracting ${_ramdisk_image##*/}";
		if [[ "$_image_type" =~ .*cpio.* ]]; then {
			runas::root "$BASH" -c '(cpio -iud; cpio -iud || true)' < "$_ramdisk_image" > /dev/null 2>&1;
		} elif [[ "$_image_type" =~ .*gzip.* ]]; then {
			zcat "$_ramdisk_image" | runas::root "$BASH" -c '(cpio -iud; cpio -iud || true)' > /dev/null 2>&1;
		} else {
			log::error "Unknown image format: ${_ramdisk_image##*/}" 1 || exit;
		} fi
	)
}

function ramdisk::create() {
	local _input_dir="$1";
	local _output_image="$2";
	(
		cd "$_input_dir";
	 	{ runas::root "$BASH" -c "find . | cpio --owner=0:0 -o -H newc | gzip" > "$_output_image"; } > /dev/null 2>&1;
	)	
}

#######################
#######################
##                   ##
##      PUBLIC       ##
##                   ##
#######################
#######################

function geco() {
	echo -e "$@";
}

function gclone(){
	# echo -e "============= ${GREEN}Progress${RC} = ${ORANGE}Speed${RC} ========================================"
	echo -e "============= Progress = Speed ========================================"

	rsync -ah --info=progress2 "$@"
}

function wipedir() {
	local dir2wipe
	for dir2wipe in "$@"; do
		if [ -e "$dir2wipe" ]; then
			log::rootcmd find "$dir2wipe" -mindepth 1 -maxdepth 1 -exec rm -r '{}' \;
		fi
	done
}

function mount::umountTree() {
	local _tree="$1";
	local _mountpoint;
	local _mountdump;
	_mountdump="$(mount | grep "$_tree" || true)";
	if test -n "$_mountdump"; then {
		while read -r _mountpoint; do
			log::rootcmd umount -fd "$_mountpoint";
		done < <(mount | grep "$_tree" | awk -F ' on ' '{print $2}' | awk '{print $1}' | tac)
	} fi
}

function mountloop::wrapper() {
	local _losetup_node && _losetup_node="$(runas::root losetup -f)";
	local _check;
	local _found_node;
	local _write_mode="${1:-ro}" && shift;
	for _check in /dev /dev/block; do {
		if test -e "$_check/${_losetup_node##*/}"; then {
			_found_node="$_check/${_losetup_node##*/}";
			break;
		} fi
	} done
	if test -e "${_found_node:-}"; then {
		runas::root mount -oloop="$_found_node",$_write_mode "$@";
	} else {
		log::error "Failed to allocate any loopdev" || exit 1;
	} fi
}

function mount::overlayFor() {
	local _for="$1";
	local _overlay_dir_node="$_overlay_dir/${_for##*/}";

	wipedir "$_overlay_dir_node";
	mkdir -p "$_overlay_dir_node" "$_overlay_dir_node/lower" "$_overlay_dir_node/worker";
	log::rootcmd mount -t overlay overlay -olowerdir="$_for",upperdir="$_overlay_dir_node/lower",workdir="$_overlay_dir_node/worker" "$_for";
}

function mount::overlay() {
	local _upper="$1";
	local _lower="$2";
	local _overlay_dir_node="$_overlay_dir/${_upper##*/}";
	wipedir "$_overlay_dir_node";
	mkdir -p "$_overlay_dir_node/worker";
	log::rootcmd mount -t overlay overlay -olowerdir="$_lower",upperdir="$_upper",workdir="$_overlay_dir_node/worker" "$_lower";
}
