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
	local expected_version
	expected_version=$(_znvm_get_normalized_version "$1")

	local remote_version
	remote_version=$(_znvm_get_remote_versions | awk '/^'"$expected_version"'/ { a=$0 } END { print a }')

	echo "$remote_version"
}

_znvm_get_local_version_for() {
	local wanted_version
	wanted_version="$1"

	local alias_version
	alias_version=$(_znvm_get_alias_version "$wanted_version")

	local version
	version=$(_znvm_get_normalized_version "${alias_version:-$wanted_version}")

	_znvm_get_installed_versions | awk '/^d/ && $9 ~ /^'"$version"'/ {print $9}' | sort -V | tail -1
}

_znmv_get_download_dir() {
	mktemp -d
}

_znvm_get_download_output_path() {
	local download_version
	download_version="$1"

	local tmp_dir
	tmp_dir="$(_znmv_get_download_dir)"

	local output_name
	output_name="node-$download_version.tar.xz"

	local output_path
	output_path="$tmp_dir/$output_name"

	echo "$output_path"
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

	local install_dir
	install_dir="$(_znvm_get_install_dir)"

	local match
	match=$path[(r)$install_dir*]

	if [ ! -z "$match" ]
	then
		echo $match
		return 0
	fi

	return 1
}

_znvm_get_version_from_path() {
	# /home/foo/.znvm/versions/v1.2.3/bin
	local version_path
	version_path="$1"

	# remove the install path
	version_path="${version_path##$(_znvm_get_install_dir)}"
	# remove leading /
	version_path="${version_path#/}"
	# remove every subdirectories of the version string (v1.2.3/bin)
	echo "${version_path%%/*}"
}

_znvm_get_normalized_version() {
	local version
	version="$1"

	local expected_version
	expected_version="$version"

	if [ -n "${expected_version##v*}" ]
	then
		expected_version="v$expected_version"
	fi

	echo "$expected_version"
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
	local wanted_version
	wanted_version="$1"

	local alias_version
	alias_version=$(_znvm_get_alias_version "$wanted_version")

	local resolved_version
	resolved_version="${alias_version:-$wanted_version}"

	# prefix the version with a "v"
	if [ -n "${resolved_version##v*}" ]
	then
		resolved_version="v$resolved_version"
	fi

	local closest_version
	closest_version=$(_znvm_find_closest_upper_version "${resolved_version}")

	local closest_version_warning=0
	if [ -n "$closest_version" ]
	then
		if [ "$resolved_version" != "$closest_version" ]
		then
			closest_version_warning=1
		fi
	fi

	local version
	version=${closest_version:-$resolved_version}

	local nodejs_path
	nodejs_path=$(_znvm_get_path_for_version "$version")

	if [ ! -d "$nodejs_path" ]
	then
		echo "$version not found" >&2
		return 1
	fi

	local current_path
	current_path=$(_znvm_get_version)

	if [ "$current_path" = "$nodejs_path" ]
	then
		return 0
	fi

	if [ -n "$current_path" ]
	then
		_znvm_remove_from_path "$current_path"
	fi

	if [ $closest_version_warning -eq 1 ]
	then
		echo "Warning: Using version $closest_version for $WANTED_VERSION" >&2
	fi
	if [ -d "$nodejs_path" ]
	then
		_znvm_add_to_path "$nodejs_path"
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
	if _znvm_load_conf_of "$PWD" ".znvmrc .nvmrc Dockerfile"
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
