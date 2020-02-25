_znvm_add_to_path() {
	typeset -Ux PATH path
	path+="$1"
}

_znvm_remove_from_path() {
	typeset -Ux PATH path

	local index=${path[(i)$1]}
	path[$index]=()
}

_znvm_get_dir() {
	echo ${ZNVM_DIR:-$HOME/.znvm}
}

_znvm_get_install_dir() {
	local _ZNVM_DIR=$(_znvm_get_dir)
	echo $_ZNVM_DIR/versions
}

_znvm_get_installed_versions() {
	ls -l "$(_znvm_get_install_dir)"
}

_znvm_get_remote_versions() {
	curl -s "https://nodejs.org/dist/index.tab" | cut -f 1 | sort -V | head -n -1
}

_znvm_get_remote_version_for() {
	local EXPECTED_VERSION
	local REMOTE_VERSION

	EXPECTED_VERSION=$(_znvm_get_normalized_version "$1")
	REMOTE_VERSION=$(_znvm_get_remote_versions | grep "^$EXPECTED_VERSION" | tail -1)

	echo "$REMOTE_VERSION"
}

_znvm_get_local_version_for() {
	local VERSION
	local ALIAS_VERSION

	ALIAS_VERSION=$(_znvm_get_alias_version "$1")

	VERSION=$(_znvm_get_normalized_version "${ALIAS_VERSION:-$1}")

	_znvm_get_installed_versions | awk '/^d/ && $9 ~ '/^"$VERSION"/' {print $9}' | sort -V | tail -1
}

_znvm_get_download_output_path() {
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

_znvm_download_version() {
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

_znvm_extract() {
	local NODEJS_XZ_PATH
	local DESTINATION_DIRECTORY

	NODEJS_XZ_PATH="$1"
	DESTINATION_DIRECTORY="$2"

	mkdir -p "$DESTINATION_DIRECTORY"

	tar xJf "$NODEJS_XZ_PATH" --strip-components=1 -C "$DESTINATION_DIRECTORY"
}

_znvm_download() {
	if [ $# -ne 1 ];then
		echo "Version is mandantory" >&2
		return 1
	fi

	local EXPECTED_VERSION
	local OUTPUT_PATH
	local DOWNLOAD_VERSION

	EXPECTED_VERSION="$1"
	DOWNLOAD_VERSION=$(_znvm_get_remote_version_for "$EXPECTED_VERSION")
	OUTPUT_PATH=$(_znvm_get_download_output_path "$DOWNLOAD_VERSION")

	if ! _znvm_download_version "$DOWNLOAD_VERSION" "$OUTPUT_PATH";then
		echo "Download failed" >&2
		local OUTPUT_DIR_PATH
		OUTPUT_DIR_PATH=$(dirname "$OUTPUT_PATH")
		rmdir "$OUTPUT_DIR_PATH"
		return 1
	fi

	local DESTINATION_DIRECTORY

	DESTINATION_DIRECTORY="$(_znvm_get_install_dir)/$DOWNLOAD_VERSION"

	_znvm_extract "$OUTPUT_PATH" "$DESTINATION_DIRECTORY"

	if [ -f "$OUTPUT_PATH" ];then
		rm "$OUTPUT_PATH"
	fi

	local OUTPUT_DIR_PATH
	OUTPUT_DIR_PATH=$(dirname "$OUTPUT_PATH")

	if [ -d "$OUTPUT_DIR_PATH" ];then
		rmdir "$OUTPUT_DIR_PATH"
	fi

	if [ -z "$(_znvm_get_alias_version default)" ];then
		echo "set $DOWNLOAD_VERSION as default" >&2
		_znvm_set_alias_version "default" "$DOWNLOAD_VERSION"
	fi
}

_znvm_get_version() {
	local INSTALL_DIR
	typeset -Ux PATH path

	INSTALL_DIR="$(_znvm_get_install_dir)"
	MATCH=$path[(r)$INSTALL_DIR*]

	if [ ! -z "$MATCH" ];then
		echo $MATCH
		return 0
	fi
}

_znvm_get_normalized_version() {
	local VERSION
	local EXPECTED_VERSION

	VERSION="$1"
	EXPECTED_VERSION="$VERSION"

	if [ ! -z "${EXPECTED_VERSION##v*}" ];then
		EXPECTED_VERSION="v$EXPECTED_VERSION"
	fi

	echo "$EXPECTED_VERSION"
}

_znvm_get_path_for_version() {
	local VERSION
	local LOCAL_VERSION

	VERSION="$1"
	LOCAL_VERSION="$(_znvm_get_local_version_for "$VERSION")"

	echo "$(_znvm_get_install_dir)/$LOCAL_VERSION/bin"
}

_znvm_get_alias_version() {
	local VERSION
	local ALIAS_VERSION="$1"
	VERSION=$(_znvm_get_installed_versions | awk '$9 == "'"$ALIAS_VERSION"'" { print $11 }')

	if [ -z "$VERSION" ];then
		return 1
	fi

	echo "$VERSION"
	return 0
}

_znvm_set_alias_version() {
	local VERSION
	local LOCAL_VERSION
	local ALIAS_NAME

	ALIAS_NAME="$1"
	VERSION="$2"
	LOCAL_VERSION=$(_znvm_get_local_version_for "$VERSION")

	if [ -z "$LOCAL_VERSION" ];then
		echo "No local version found" >&2
		return 1
	fi

	local INSTALL_DIR

	INSTALL_DIR="$(_znvm_get_install_dir)"

	if [ -L "$INSTALL_DIR/$ALIAS_NAME" ];then
		rm -f "$INSTALL_DIR/$ALIAS_NAME"
	fi

	ln -s "$LOCAL_VERSION" "$INSTALL_DIR/$ALIAS_NAME"
}

_znvm_use_version() {
	local VERSION
	local NODEJS_PATH

	VERSION=$(_znvm_get_alias_version "$1")
	VERSION=${VERSION:-$1}

	NODEJS_PATH=$(_znvm_get_path_for_version "$VERSION")

	if [ ! -d "$NODEJS_PATH" ];then
		echo "$VERSION not found" >&2
		return 1
	fi

	local CURRENT_PATH
	CURRENT_PATH=$(_znvm_get_version)

	if [ ! -z "$CURRENT_PATH" ];then
		_znvm_remove_from_path "$CURRENT_PATH"
	fi

	if [ -d "$NODEJS_PATH" ];then
		_znvm_add_to_path "$NODEJS_PATH"
	fi
}

_znvm_get_help() {
	echo "Usage:" >&2
	echo "$1 ls - list installed versions" >&2
	echo "$1 deactivate - remove nodejs from path" >&2
	echo "$1 activate - add default nodejs to path" >&2
	echo "$1 use VERSION - change active nodejs to VERSION" >&2
	echo "$1 install VERSION - download and install nodejs VERSION" >&2
	echo "$1 which VERSION - print which version matches to VERSION" >&2
	echo "$1 alias NAME VERSION - create VERSION alias to NAME" >&2
	echo "$1 hookwdchange - read automatically .nvmrc when changing directory" >&2
}


_znvm_load_conf_of() {
	local FILE_DIR
	local FILE_SUFFIX
	local FILE_PATH

	FILE_DIR="$1"

	if [ "$FILE_DIR" = "/" ] || [ -z "$FILE_DIR" ]
	then
		return 1
	fi

	FILE_SUFFIX="${2}"

	FILE_PATH="$FILE_DIR/$FILE_SUFFIX"

	# check file exists, is regular file and is readable:
	if [ -f "$FILE_PATH" ] && [ -r "$FILE_PATH" ]; then
		local NODE_VERSION="$(cat $FILE_PATH)"
		znvm use "$NODE_VERSION"
		return 0
	fi

	_znvm_load_conf_of "$FILE_DIR:h" "$FILE_SUFFIX"
}

_znvm_load_conf() {
	if _znvm_load_conf_of "$PWD" ".znvmrc"
	then
		return 0
	fi

	_znvm_load_conf_of "$PWD" ".nvmrc"
}

_read_nvm_rc_on_pw_change() {
	autoload -U add-zsh-hook

	add-zsh-hook chpwd _znvm_load_conf
}

znvm() {
	if [ $# -lt 1 ];then
		_znvm_get_help "$0"
		return 1
	fi

	local COMMAND="$1"
	shift

	case "$COMMAND" in
		'use')
			_znvm_use_version "$1"
			;;
		'install')
			_znvm_download "$1"
			;;
		'ls')
			_znvm_get_installed_versions | awk 'NF >= 9 {print $9" "$10" "$11}'
			;;
		'which')
			_znvm_get_local_version_for "$1"
			;;
		'run')
			local version_path="$(_znvm_get_path_for_version)/node"
			$version_path $@
			;;
		'alias')
			_znvm_set_alias_version "$1" "$2"
			;;
		'deactivate')
			_znvm_remove_from_path "$(_znvm_get_version)"
			;;
		'activate')
			_znvm_use_version "default"
			;;
		'hookwdchange')
			_read_nvm_rc_on_pw_change
			;;
		'help'|'h')
			_znvm_get_help "$0"
			;;
		*)
			_znvm_get_help "$0"
			return 1
			;;
	esac
}
