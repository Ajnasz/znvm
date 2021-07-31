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

_znvm_get_download_dir() {
	mktemp -d
}

_znvm_get_download_output_path() {
	local download_version
	download_version="$1"

	local tmp_dir
	tmp_dir="$(_znvm_get_download_dir)"

	local output_name
	output_name="node-$download_version.tar.xz"

	local output_path
	output_path="$tmp_dir/$output_name"

	echo "$output_path"
}

_znvm_download_version() {
	local download_version
	download_version="$1"

	local output_path
	output_path="$2"

	local arch
	arch=""

	local os
	os=""

	case "$(uname -m)" in
		"x86_64")
			arch="x64"
			;;
		"armv7l")
			arch="armv7l"
			;;
	esac

	case "$(uname -s)" in
		"Linux")
			os="linux"
			;;
		"Darwin")
			os="osx"
			;;
	esac

	local remote_url
	remote_url="https://nodejs.org/dist/$download_version/node-$download_version-$os-$arch.tar.xz"

	if ! curl "$remote_url" --progress-bar -o "$output_path"
	then
		return 1
	fi
}

_znvm_extract() {

	local nodejs_xz_path
	nodejs_xz_path="$1"

	local destination_directory
	destination_directory="$2"

	mkdir -p "$destination_directory"

	tar xJf "$nodejs_xz_path" --strip-components=1 -C "$destination_directory"
}

_znvm_download() {
	local expected_version
	expected_version="$1"

	local download_version
	download_version=$(_znvm_get_remote_version_for "$expected_version")

	local output_path
	output_path=$(_znvm_get_download_output_path "$download_version")

	if ! _znvm_download_version "$download_version" "$output_path"
	then
		echo "Download failed" >&2
		local output_dir_path
		output_dir_path=$(dirname "$output_path")
		rmdir "$output_dir_path"
		return 1
	fi

	local destination_directory
	destination_directory="$(_znvm_get_install_dir)/$download_version"

	_znvm_extract "$output_path" "$destination_directory"

	if [ -f "$output_path" ]
	then
		rm "$output_path"
	fi

	local output_dir_path
	output_dir_path=$(dirname "$output_path")

	if [ -d "$output_dir_path" ]
	then
		rmdir "$output_dir_path"
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
	local Version
	version="$1"

	local local_version
	local_version="$(_znvm_get_local_version_for "$version")"

	echo "$(_znvm_get_install_dir)/$local_version/bin"
}

_znvm_get_alias_version() {
	local alias_version
	alias_version="$1"

	local version
	version=$(_znvm_get_installed_versions | awk '$9 == "'"$alias_version"'" { print $11 }')

	if [ -z "$version" ]
	then
		return 0
	fi

	echo "$version"
	return 0
}

_znvm_set_alias_version() {
	local alias_name
	alias_name="$1"

	local version
	version="$2"

	local local_version
	local_version=$(_znvm_get_local_version_for "$version")

	if [ -z "$local_version" ]
	then
		echo "No local version found" >&2
		return 1
	fi

	local install_dir
	install_dir="$(_znvm_get_install_dir)"

	if [ -L "$install_dir/$alias_name" ]
	then
		rm -f "$install_dir/$alias_name"
	fi

	ln -s "$local_version" "$install_dir/$alias_name"
}

_znvm_find_closest_upper_version() {
	local version
	version="$1"

	local existing_versions
	existing_versions="${2:-$(znvm ls | awk '{ if (NF == 3) { print $3 } else { print $1 } }' | sort -V | uniq)}"

	local found_version
	found_version=$(echo $existing_versions | awk '/^v?'"$version"'/ { a=$1 } END { print a }')

	if [ -n "$found_version" ]
	then
		echo -n $found_version
		return 0
	fi

	local cut_version
	cut_version=${version%.*}

	if [ "$cut_version" = "$version" ]
	then
		return 1
	fi

	_znvm_find_closest_upper_version "$cut_version" "$existing_versions"
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
		echo "using version $closest_version for $wanted_version" >&2
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
	echo "$1 use [VERSION] - change active nodejs to VERSION. If VERSION omitted, load version from \$ZNVM_SEARCH_FILENAMES"
	echo "$1 install VERSION - download and install nodejs VERSION"
	echo "$1 which VERSION - print which version matches to VERSION"
	echo "$1 alias NAME VERSION - create VERSION alias to NAME"
	echo "$1 current - get the activated version"
	echo "$1 hookwdchange - read automatically .nvmrc when changing directory"
}

_znvm_get_version_from_dockerfile() {
	local file_path
	file_path="$1"
	awk '/FROM node:/' $file_path | cut -d ':' -f 2 | cut -d '.' -f 1 | head -n 1
}

_znvm_get_version_from_rcfile() {
	local file_path
	file_path="$1"
	cat $file_path
}

_znvm_load_conf_of() {
	local file_dir
	file_dir="$1"

	if [ "$file_dir" = "/" ] || [ -z "$file_dir" ]
	then
		return 1
	fi

	local file_names
	file_names="$2"

	local file_name
	local file_path
	for file_name in ${(s( ))FILE_NAMES}
	do
		file_path="$file_dir/$file_name"

		# check file exists, is regular file and is readable:
		if [ -f "$file_path" ] && [ -r "$FILE_PATH" ]
		then
			local node_version;
			node_version=""
			if [ "$file_name" = "Dockerfile" ]
			then
				node_version="$(_znvm_get_version_from_dockerfile $file_path)"
			# if FILE_NAME = *nvmrc, the expression will remove the nvmrc part
			# from the FILE_NAME
			elif [ "${file_name%%nvmrc}" != "$file_name" ]
			then
				node_version="$(_znvm_get_version_from_rcfile $file_path)"
			fi

			if [ -n "$node_version" ]
			then
				znvm use "$node_version"
				return 0
			fi
		fi
	done

	_znvm_load_conf_of "$file_dir:h" "$file_names"
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

	local command
	command="$1"
	shift

	case "$command" in
		'use')
			echo "$#" >&2
			if [ $# -eq 1 ]
			then
				_znvm_use_version "$1"
				return $?
			elif [ $# -eq 0 ]
			then
				_znvm_load_conf
				return $?
			else
				_znvm_get_help "$0" >&2
				return 1
			fi
			;;
		'install')
			_znvm_install "$1"
			return $?
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
			return $?
			;;
		'run')
			local version_path
			version_path="$(_znvm_get_path_for_version)/node"
			$version_path $@
			;;
		'alias')
			_znvm_set_alias_version "$1" "$2"
			return $?
			;;
		'deactivate')
			_znvm_remove_from_path "$(_znvm_get_version)"
			;;
		'activate')
			_znvm_use_version "default"
			return $?
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
