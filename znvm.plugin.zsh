_znvm_add_to_path() {
	typeset -Ux PATH path
	path+="$1"
}

_znvm_remove_from_path() {
	typeset -Ux PATH path

	local index=${path[(i)$1]}
	path[$index]=()
}

_znvm_get_install_dir() {
	echo ${ZNVM_DIR:-$HOME/.znvm}/versions
}

_znvm_get_installed_versions() {
	ls --color=never -l "$(_znvm_get_install_dir)"
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
}

_znvm_install() {
	_znvm_download "$1"

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

_znvm_find_closest_upper_version() {
	local VERSION
	local CUT_VERSION
	local FOUND_VERSION

	VERSION="$1"

	FOUND_VERSION=$(znvm ls | awk '{ if (NF > 1) { print $3 } else { print $1 } }' | sort -V | uniq | grep "^v\?$VERSION" | tail -1)

	if [ -n "$FOUND_VERSION" ]
	then
		echo $FOUND_VERSION
		return 0
	fi

	CUT_VERSION=${VERSION%.*}

	if [ "$CUT_VERSION" = "$VERSION" ]
	then
		return 1
	fi

	_znvm_find_closest_upper_version "$CUT_VERSION"
}

_znvm_use_version() {
	local VERSION
	local ALIAS_VERSION
	local CLOSEST_VERSION
	local NODEJS_PATH

	ALIAS_VERSION=$(_znvm_get_alias_version "$1")
	CLOSEST_VERSION=$(_znvm_find_closest_upper_version "${ALIAS_VERSION:-$1}")
	if [ ! -z "$CLOSEST_VERSION" ]
	then
		local isclosest
		isclosest=0

		if [ ! -z "$ALIAS_VERSION" ] && ! echo "$CLOSEST_VERSION" | grep -q "^v\?$ALIAS_VERSION"
		then
			isclosest=1
		fi

		if [ $isclosest -eq 1 ] || [ -z "$ALIAS_VERSION" ] && ! echo "$CLOSEST_VERSION" | grep -q "^v\?$1"
		then
			echo "Warning: Using version $CLOSEST_VERSION for $1" >&2
		fi
	fi

	VERSION=${CLOSEST_VERSION:-$1}


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
	echo "Usage:"
	echo "$1 ls - list installed versions"
	echo "$1 deactivate - remove nodejs from path"
	echo "$1 activate - add default nodejs to path"
	echo "$1 use VERSION - change active nodejs to VERSION"
	echo "$1 install VERSION - download and install nodejs VERSION"
	echo "$1 which VERSION - print which version matches to VERSION"
	echo "$1 alias NAME VERSION - create VERSION alias to NAME"
	echo "$1 hookwdchange - read automatically .nvmrc when changing directory"
}

_znvm_get_version_from_dockerfile() {
	local FILE_PATH
	FILE_PATH="$1"
	grep 'FROM node:' $FILE_PATH | cut -d ':' -f 2 | cut -d '.' -f 1 | head -n 1
}

_znvm_get_version_from_rcfile() {
	FILE_PATH="$1"
	cat $FILE_PATH
}

_znvm_load_conf_of() {
	local FILE_DIR
	local FILE_NAME
	local FILE_PATH
	local FILE_NAMES
	FILE_DIR="$1"

	if [ "$FILE_DIR" = "/" ] || [ -z "$FILE_DIR" ]
	then
		return 1
	fi

	FILE_NAMES="$2"

	for FILE_NAME in ${(s( ))FILE_NAMES};do
		FILE_PATH="$FILE_DIR/$FILE_NAME"

		# check file exists, is regular file and is readable:
		if [ -f "$FILE_PATH" ] && [ -r "$FILE_PATH" ]; then
			local NODE_VERSION;
			if [ "$FILE_NAME" = "Dockerfile" ];then
				NODE_VERSION="$(_znvm_get_version_from_dockerfile $FILE_PATH)"
			else
				NODE_VERSION="$(_znvm_get_version_from_rcfile $FILE_PATH)"
			fi

			if [ ! -z "$NODE_VERSION" ]; then
				znvm use "$NODE_VERSION"
				return 0
			fi
		fi
	done

	_znvm_load_conf_of "$FILE_DIR:h" "$FILE_SUFFIXES"
}

_znvm_load_conf() {
	if _znvm_load_conf_of "$PWD" ".znvmrc .nvmrc Dockerfile"
	then
		return 0
	fi
}

_read_nvm_rc_on_pw_change() {
	autoload -U add-zsh-hook

	add-zsh-hook chpwd _znvm_load_conf
}

znvm() {
	if [ $# -lt 1 ];then
		_znvm_get_help "$0" >&2
		return 1
	fi

	local COMMAND="$1"
	shift

	case "$COMMAND" in
		'use')
			_znvm_use_version "$1"
			;;
		'install')
			_znvm_install "$1"
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
			_znvm_get_help "$0" >&2
			return 1
			;;
	esac
}
