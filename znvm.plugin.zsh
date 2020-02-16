_znvm_add_to_path() {
	typeset -Ux PATH path
	path+="$1"
}

_znvm_remove_from_path() {
	typeset -Ux PATH path

	local index=${path[(i)$1]}
	path[$index]=()
}

_get_znvm_install_dir() {
	echo ${ZNVM_DIR:-$HOME/.znvm/versions}
}

_get_znvm_installed_versions() {
	ls -l "$(_get_znvm_install_dir)"
}

_get_znvm_remote_versions() {
	curl -s "https://nodejs.org/dist/index.tab" | cut -f 1 | sort -V | head -n -1
}

_get_znvm_remote_version_for() {
	local EXPECTED_VERSION
	local REMOTE_VERSION

	EXPECTED_VERSION=$(_get_znvm_normalized_version "$1")
	REMOTE_VERSION=$(_get_znvm_remote_versions | grep "^$EXPECTED_VERSION" | tail -1)

	echo "$REMOTE_VERSION"
}

_get_znvm_local_version_for() {
	local VERSION

	VERSION="$1"

	if [ "$VERSION" = "default" ];then
		_get_znvm_default_version && return 0
	fi

	VERSION=$(_get_znvm_normalized_version "$VERSION")

	_get_znvm_installed_versions | awk '/^d/ && $9 ~ '/^"$VERSION"/' {print $9}' | sort -V | tail -1
}

_get_znvm_download_output_path() {
	local DOWNLOAD_VERSION
	local TMP_DIR
	local OUTPUT_NAME
	local OUTPUT_PATH

	DOWNLOAD_VERSION="$1"
	TMP_DIR="$(mktemp -d)"
	OUTPUT_NAME="node-$DOWNLOAD_VERSION.tar.xz"
	OUTPUT_PATH="$TMP_DIR/$OUTPUT_NAME"

	echo "$OUTPUT_PATH"
}

_download_znvm_version() {
	local DOWNLOAD_VERSION
	local OUTPUT_PATH
	local ARCH
	local OS

	DOWNLOAD_VERSION="$1"
	OUTPUT_PATH="$2"
	ARCH=""
	OS=""

	case "$(uname -m)" in
		"x86_64")
			ARCH="x64"
			;;
		"armv7l")
			ARCH="armv7l"
			;;
	esac

	case "$(uname -s)" in
		"Linux")
			OS="linux"
			;;
		"Darwin")
			OS="osx"
			;;
	esac

	local REMOTE_URL

	REMOTE_URL="https://nodejs.org/dist/$DOWNLOAD_VERSION/node-$DOWNLOAD_VERSION-$OS-$ARCH.tar.xz"

	if ! curl "$REMOTE_URL" -# -o "$OUTPUT_PATH";then
		return 1
	fi
}

_extract_znvm() {
	local NODEJS_XZ_PATH
	local DESTINATION_DIRECTORY

	NODEJS_XZ_PATH="$1"
	DESTINATION_DIRECTORY="$2"

	mkdir -p "$DESTINATION_DIRECTORY"

	tar xJf "$NODEJS_XZ_PATH" --strip-components=1 -C "$DESTINATION_DIRECTORY"
}

_download_znvm() {
	if [ $# -ne 1 ];then
		echo "Version is mandantory" >&2
		return 1
	fi

	local EXPECTED_VERSION
	local OUTPUT_PATH
	local DOWNLOAD_VERSION

	EXPECTED_VERSION="$1"
	DOWNLOAD_VERSION=$(_get_znvm_remote_version_for "$EXPECTED_VERSION")
	OUTPUT_PATH=$(_get_znvm_download_output_path "$DOWNLOAD_VERSION")

	if ! _download_znvm_version "$DOWNLOAD_VERSION" "$OUTPUT_PATH";then
		echo "Download failed" >&2
		local OUTPUT_DIR_PATH
		OUTPUT_DIR_PATH=$(dirname "$OUTPUT_PATH")
		rmdir "$OUTPUT_DIR_PATH"
		return 1
	fi

	local DESTINATION_DIRECTORY

	DESTINATION_DIRECTORY="$(_get_znvm_install_dir)/$DOWNLOAD_VERSION"

	_extract_znvm "$OUTPUT_PATH" "$DESTINATION_DIRECTORY"

	if [ -f "$OUTPUT_PATH" ];then
		rm "$OUTPUT_PATH"
	fi

	local OUTPUT_DIR_PATH
	OUTPUT_DIR_PATH=$(dirname "$OUTPUT_PATH")

	if [ -d "$OUTPUT_DIR_PATH" ];then
		rmdir "$OUTPUT_DIR_PATH"
	fi
}

_get_znvm_version() {
	local INSTALL_DIR
	typeset -Ux PATH path

	INSTALL_DIR="$(_get_znvm_install_dir)"
	MATCH=$path[(r)$INSTALL_DIR*]

	if [ ! -z "$MATCH" ];then
		echo $MATCH
		return 0
	fi
}

_get_znvm_normalized_version() {
	local VERSION
	local EXPECTED_VERSION

	VERSION="$1"
	EXPECTED_VERSION="$VERSION"

	if [ ! -z "${EXPECTED_VERSION##v*}" ];then
		EXPECTED_VERSION="v$EXPECTED_VERSION"
	fi

	echo "$EXPECTED_VERSION"
}

_get_znvm_path_for_version() {
	local VERSION
	local LOCAL_VERSION

	VERSION="$1"
	LOCAL_VERSION="$(_get_znvm_local_version_for "$VERSION")"

	echo "$(_get_znvm_install_dir)/$LOCAL_VERSION/bin"
}

_get_znvm_alias_version() {
	local VERSION
	local ALIAS_VERSION="$1"
	VERSION=$(_get_znvm_installed_versions | awk '$9 == "'"$ALIAS_VERSION"'" { print $11 }')

	if [ -z "$VERSION" ];then
		echo "No default version found" >&2
		return 1
	fi

	echo "$VERSION"
	return 0
}

_get_znvm_default_version() {
	_get_znvm_alias_version "default"
}

_set_znvm_alias_version() {
	local VERSION
	local LOCAL_VERSION
	local ALIAS_NAME

	ALIAS_NAME="$1"
	VERSION="$2"
	LOCAL_VERSION=$(_get_znvm_local_version_for "$VERSION")

	if [ -z "$LOCAL_VERSION" ];then
		echo "No local version found" >&2
		return 1
	fi

	local INSTALL_DIR

	INSTALL_DIR="$(_get_znvm_install_dir)"

	if [ -L "$INSTALL_DIR/$ALIAS_NAME" ];then
		rm -f "$INSTALL_DIR/$ALIAS_NAME"
	fi

	ln -s "$LOCAL_VERSION" "$INSTALL_DIR/$ALIAS_NAME"
}

_set_znvm_default_version() {
	_set_znvm_alias_version "default" "$2"
}

_use_znvm_version() {
	local VERSION
	local CURRENT_PATH
	local NODEJS_PATH

	VERSION="$1"
	CURRENT_PATH=$(_get_znvm_version)
	NODEJS_PATH=$(_get_znvm_path_for_version "$VERSION")

	if [ ! -z "$CURRENT_PATH" ];then
		_znvm_remove_from_path "$CURRENT_PATH"
	fi

	if [ -d "$NODEJS_PATH" ];then
		_znvm_add_to_path "$NODEJS_PATH"
	fi
}

_use_znvm_default_version() {
	local VERSION

	VERSION=$(_get_znvm_default_version)

	if [ -z "$VERSION" ];then
		echo "No default version found" >&2
		return 1
	fi

	_use_znvm_version "$VERSION"
}

_get_znvm_help() {
	echo "Usage:" >&2
	echo "$1 ls - list installed versions" >&2
	echo "$1 deactivate - remove nodejs from path" >&2
	echo "$1 activate - add default nodejs to path" >&2
	echo "$1 use VERSION - change active nodejs to VERSION" >&2
	echo "$1 install VERSION - download and install nodejs VERSION" >&2
	echo "$1 which VERSION - print which version matches to VERSION" >&2
	echo "$1 alias NAME VERSION - create VERSION alias to NAME" >&2
	echo "$1 hookpwchange - read automatically .nvmrc when changing directory" >&2
}


_load_znvm_conf() {
	# check file exists, is regular file and is readable:
	if [ -f .nvmrc ] && [ -r .nvmrc ]; then
		local NODE_VERSION="$(cat .nvmrc)"
		znvm use "$NODE_VERSION"
	fi
}

_read_nvm_rc_on_pw_change() {
	autoload -U add-zsh-hook

	add-zsh-hook chpwd _load_znvm_conf
}

znvm() {
	if [ $# -lt 1 ];then
		_get_znvm_help "$0"
		return 1
	fi

	local COMMAND="$1"
	shift

	case "$COMMAND" in
		'use')
			_use_znvm_version "$1"
			;;
		'install')
			_download_znvm "$1"
			;;
		'ls')
			_get_znvm_installed_versions | awk 'NF >= 9 {print $9" "$10" "$11}'
			;;
		'which')
			_get_znvm_local_version_for "$1"
			;;
		'run')
			local version_path="$(_get_znvm_path_for_version)/node"
			$version_path $@
			;;
		'alias')
			_set_znvm_alias_version "$1" "$2"
			;;
		'deactivate')
			_znvm_remove_from_path "$(_get_znvm_version)"
			;;
		'activate')
			_use_znvm_default_version
			;;
		'hookpwchange')
			_read_nvm_rc_on_pw_change
			;;
		'help'|'h')
			_get_znvm_help "$0"
			;;
		*)
			_get_znvm_help "$0"
			return 1
			;;
	esac
}
