function clap() {
	# CLAP
	for arg in "${@}"; do
		case "$arg" in
			--setup-iso)
				shift
				setup.iso "$1"
			;;
			--clean-cache)
				println.cmd wipedir "$ISO_DIR"
			;;
			--unload-image)
				mount.unload
			;;
			--load-image)
				mount.load
			;;
			--auto-reply)
				export AUTO_REPLY=true
			;;
			--load-hooks)
				load.hooks
			;;
			--build-image)
				BUILD_IMG_ONLY=true
				build.iso
			;;
			--build-iso)
				build.iso
			;;
		esac
	done
}
