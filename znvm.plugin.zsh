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

_znvm_get_hook_search_filenames() {
	echo ${ZNVM_SEARCH_FILENAMES:-.znvmrc .nvmrc Dockerfile}
}

_znvm_get_installed_versions() {
	ls --color=never -l "$(_znvm_get_install_dir)"
}

_znvm_get_remote_versions() {
	curl -s "https://nodejs.org/dist/index.tab" | cut -f 1 | sort -V | head -n -1
}

_znvm_get_remote_version_for() {
	local EXPECTED_VERSION
	EXPECTED_VERSION=$(_znvm_get_normalized_version "$1")

	local REMOTE_VERSION
	REMOTE_VERSION=$(_znvm_get_remote_versions | awk '/^'"$EXPECTED_VERSION"'/ { a=$0 } END { print a }')

	echo "$REMOTE_VERSION"
}

_znvm_get_local_version_for() {
	local WANTED_VERSION
	WANTED_VERSION="$1"

	local ALIAS_VERSION
	ALIAS_VERSION=$(_znvm_get_alias_version "$WANTED_VERSION")

	local VERSION
	VERSION=$(_znvm_get_normalized_version "${ALIAS_VERSION:-$WANTED_VERSION}")

	_znvm_get_installed_versions | awk '/^d/ && $9 ~ /^'"$VERSION"'/ {print $9}' | sort -V | tail -1
}

_znvm_get_download_output_path() {
	local DOWNLOAD_VERSION
	DOWNLOAD_VERSION="$1"

	local TMP_DIR
	TMP_DIR="$(mktemp -d)"

	local OUTPUT_NAME
	OUTPUT_NAME="node-$DOWNLOAD_VERSION.tar.xz"

	local OUTPUT_PATH
	OUTPUT_PATH="$TMP_DIR/$OUTPUT_NAME"

	echo "$OUTPUT_PATH"
}

_znvm_download_version() {
	local DOWNLOAD_VERSION
	DOWNLOAD_VERSION="$1"

	local OUTPUT_PATH
	OUTPUT_PATH="$2"

	local ARCH
	ARCH=""

	local OS
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

	if ! curl "$REMOTE_URL" --progress-bar -o "$OUTPUT_PATH"
	then
		return 1
	fi
}

_znvm_extract() {

	local NODEJS_XZ_PATH
	NODEJS_XZ_PATH="$1"

	local DESTINATION_DIRECTORY
	DESTINATION_DIRECTORY="$2"

	mkdir -p "$DESTINATION_DIRECTORY"

	tar xJf "$NODEJS_XZ_PATH" --strip-components=1 -C "$DESTINATION_DIRECTORY"
}

_znvm_download() {
	local EXPECTED_VERSION
	EXPECTED_VERSION="$1"

	local DOWNLOAD_VERSION
	DOWNLOAD_VERSION=$(_znvm_get_remote_version_for "$EXPECTED_VERSION")

	local OUTPUT_PATH
	OUTPUT_PATH=$(_znvm_get_download_output_path "$DOWNLOAD_VERSION")

	if ! _znvm_download_version "$DOWNLOAD_VERSION" "$OUTPUT_PATH"
	then
		echo "Download failed" >&2
		local OUTPUT_DIR_PATH
		OUTPUT_DIR_PATH=$(dirname "$OUTPUT_PATH")
		rmdir "$OUTPUT_DIR_PATH"
		return 1
	fi

	local DESTINATION_DIRECTORY
	DESTINATION_DIRECTORY="$(_znvm_get_install_dir)/$DOWNLOAD_VERSION"

	_znvm_extract "$OUTPUT_PATH" "$DESTINATION_DIRECTORY"

	if [ -f "$OUTPUT_PATH" ]
	then
		rm "$OUTPUT_PATH"
	fi

	local OUTPUT_DIR_PATH
	OUTPUT_DIR_PATH=$(dirname "$OUTPUT_PATH")

	if [ -d "$OUTPUT_DIR_PATH" ]
	then
		rmdir "$OUTPUT_DIR_PATH"
	fi
}

_znvm_install() {
	if [ $# -ne 1 ]
	then
		echo "Version is mandantory" >&2
		return 1
	fi

	_znvm_download "$1"

	if [ -z "$(_znvm_get_alias_version default)" ]
	then
		echo "set $DOWNLOAD_VERSION as default" >&2
		_znvm_set_alias_version "default" "$DOWNLOAD_VERSION"
	fi
}

_znvm_get_version() {
	typeset -Ux PATH path

	local INSTALL_DIR
	INSTALL_DIR="$(_znvm_get_install_dir)"

	local MATCH
	MATCH=$path[(r)$INSTALL_DIR*]

	if [ ! -z "$MATCH" ]
	then
		echo $MATCH
		return 0
	fi

	return 1
}

_znvm_get_version_from_path() {
	# /home/foo/.znvm/versions/v1.2.3/bin
	local VERSION_PATH
	VERSION_PATH="$1"

	# remove the install path
	VERSION_PATH="${VERSION_PATH##$(_znvm_get_install_dir)}"
	# remove leading /
	VERSION_PATH="${VERSION_PATH#/}"
	# remove every subdirectories of the version string (v1.2.3/bin)
	echo ${VERSION_PATH%%/*}
}

_znvm_get_normalized_version() {
	local VERSION
	VERSION="$1"

	local EXPECTED_VERSION
	EXPECTED_VERSION="$VERSION"

	if [ -n "${EXPECTED_VERSION##v*}" ]
	then
		EXPECTED_VERSION="v$EXPECTED_VERSION"
	fi

	echo "$EXPECTED_VERSION"
}

_znvm_get_path_for_version() {
	local VERSION
	VERSION="$1"

	local LOCAL_VERSION
	LOCAL_VERSION="$(_znvm_get_local_version_for "$VERSION")"

	echo "$(_znvm_get_install_dir)/$LOCAL_VERSION/bin"
}

_znvm_get_alias_version() {
	local ALIAS_VERSION
	ALIAS_VERSION="$1"

	local VERSION
	VERSION=$(_znvm_get_installed_versions | awk '$9 == "'"$ALIAS_VERSION"'" { print $11 }')

	if [ -z "$VERSION" ]
	then
		return 1
	fi

	echo "$VERSION"
	return 0
}

_znvm_set_alias_version() {
	local ALIAS_NAME
	ALIAS_NAME="$1"

	local VERSION
	VERSION="$2"

	local LOCAL_VERSION
	LOCAL_VERSION=$(_znvm_get_local_version_for "$VERSION")

	if [ -z "$LOCAL_VERSION" ]
	then
		echo "No local version found" >&2
		return 1
	fi

	local INSTALL_DIR
	INSTALL_DIR="$(_znvm_get_install_dir)"

	if [ -L "$INSTALL_DIR/$ALIAS_NAME" ]
	then
		rm -f "$INSTALL_DIR/$ALIAS_NAME"
	fi

	ln -s "$LOCAL_VERSION" "$INSTALL_DIR/$ALIAS_NAME"
}

_znvm_find_closest_upper_version() {
	local VERSION
	VERSION="$1"

	local EXISTING_VERSIONS
	EXISTING_VERSIONS="${2:-$(znvm ls | awk '{ if (NF == 3) { print $3 } else { print $1 } }' | sort -V | uniq)}"

	local FOUND_VERSION
	FOUND_VERSION=$(echo $EXISTING_VERSIONS | awk '/^v?'"$VERSION"'/ { a=$1 } END { print a }')

	if [ -n "$FOUND_VERSION" ]
	then
		echo $FOUND_VERSION
		return 0
	fi

	local CUT_VERSION
	CUT_VERSION=${VERSION%.*}

	if [ "$CUT_VERSION" = "$VERSION" ]
	then
		return 1
	fi

	_znvm_find_closest_upper_version "$CUT_VERSION" "$EXISTING_VERSIONS"
}

_znvm_use_version() {
	local WANTED_VERSION
	WANTED_VERSION="$1"

	local ALIAS_VERSION
	ALIAS_VERSION=$(_znvm_get_alias_version "$WANTED_VERSION")

	local RESOLVED_VERSION
	RESOLVED_VERSION="${ALIAS_VERSION:-$WANTED_VERSION}"

	# prefix the version with a "v"
	if [ -n "${RESOLVED_VERSION##v*}" ]
	then
		RESOLVED_VERSION="v$RESOLVED_VERSION"
	fi

	local CLOSEST_VERSION
	CLOSEST_VERSION=$(_znvm_find_closest_upper_version "${RESOLVED_VERSION}")

	if [ -n "$CLOSEST_VERSION" ]
	then
		if [ "$RESOLVED_VERSION" != "$CLOSEST_VERSION" ]
		then
			echo "Warning: Using version $CLOSEST_VERSION for $WANTED_VERSION" >&2
		fi
	fi

	local VERSION
	VERSION=${CLOSEST_VERSION:-$RESOLVED_VERSION}

	local NODEJS_PATH
	NODEJS_PATH=$(_znvm_get_path_for_version "$VERSION")

	if [ ! -d "$NODEJS_PATH" ]
	then
		echo "$VERSION not found" >&2
		return 1
	fi

	local CURRENT_PATH
	CURRENT_PATH=$(_znvm_get_version)

	if [ "$CURRENT_PATH" = "$NODEJS_PATH" ]
	then
		return 0
	fi

	if [ -n "$CURRENT_PATH" ]
	then
		_znvm_remove_from_path "$CURRENT_PATH"
	fi

	if [ -d "$NODEJS_PATH" ]
	then
		_znvm_add_to_path "$NODEJS_PATH"
	fi

	return 0
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
	echo "$1 current - get the activated version"
	echo "$1 hookwdchange - read automatically .nvmrc when changing directory"
}

_znvm_get_version_from_dockerfile() {
	local FILE_PATH
	FILE_PATH="$1"
	awk '/FROM node:/' $FILE_PATH | cut -d ':' -f 2 | cut -d '.' -f 1 | head -n 1
}

_znvm_get_version_from_rcfile() {
	local FILE_PATH
	FILE_PATH="$1"
	cat $FILE_PATH
}

_znvm_load_conf_of() {
	local FILE_DIR
	FILE_DIR="$1"

	if [ "$FILE_DIR" = "/" ] || [ -z "$FILE_DIR" ]
	then
		return 1
	fi

	local FILE_NAMES
	FILE_NAMES="$2"

	local FILE_NAME
	local FILE_PATH
	for FILE_NAME in ${(s( ))FILE_NAMES}
	do
		FILE_PATH="$FILE_DIR/$FILE_NAME"

		# check file exists, is regular file and is readable:
		if [ -f "$FILE_PATH" ] && [ -r "$FILE_PATH" ]
		then
			local NODE_VERSION;
			NODE_VERSION=""
			if [ "$FILE_NAME" = "Dockerfile" ]
			then
				NODE_VERSION="$(_znvm_get_version_from_dockerfile $FILE_PATH)"
			# if FILE_NAME = *nvmrc, the expression will remove the nvmrc part
			# from the FILE_NAME
			elif [ "${FILE_NAME%%nvmrc}" != "$FILE_NAME" ]
			then
				NODE_VERSION="$(_znvm_get_version_from_rcfile $FILE_PATH)"
			fi

			if [ -n "$NODE_VERSION" ]
			then
				znvm use "$NODE_VERSION"
				return 0
			fi
		fi
	done

	_znvm_load_conf_of "$FILE_DIR:h" "$FILE_NAMES"
}

_znvm_load_conf() {
	if _znvm_load_conf_of "$PWD" "$(_znvm_get_hook_search_filenames)"
	then
		return 0
	fi

	return 1
}

_read_nvm_rc_on_pw_change() {
	autoload -U add-zsh-hook

	add-zsh-hook chpwd _znvm_load_conf
}

znvm() {
	if [ $# -lt 1 ]
	then
		_znvm_get_help "$0" >&2
		return 1
	fi

	local COMMAND
	COMMAND="$1"
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
			if [ $# -lt 1 ]
			then
				echo "Version is mandantory" >&2
				return 1
			fi
			_znvm_get_local_version_for "$1"
			;;
		'run')
			local version_path
			version_path="$(_znvm_get_path_for_version)/node"
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
		'current')
			local current_version
			current_version="$(_znvm_get_version)"
			if [ $? -ne 0 ]
			then
				return 1
			fi
			_znvm_get_version_from_path "$current_version"
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
