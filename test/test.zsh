#!/bin/zsh

assert_ok() {
  local FUNCTION=$1
  shift

  $($FUNCTION $@) || die '"'"$FUNCTION $@"'" should have succeeded, but failed'
}

assert_not_ok() {
  local FUNCTION=$1
  shift

  $($FUNCTION $@) && die '"'"$FUNCTION $@"'" should have failed, but succeeded'
}

die () {
	echo "$@"
	exit 1
}

export ZNVM_DIR="/tmp/znvm_test"
. $(dirname $0)/../znvm.plugin.zsh

_znvm_get_installed_versions() {
	echo "
lrwxrwxrwx 1 ajnasz ajnasz    8 febr  17  2020 default -> v12.16.0
drwxrwxr-x 6 ajnasz ajnasz 4096 febr  16  2020 v10.19.0
drwxrwxr-x 6 ajnasz ajnasz 4096 febr  16  2020 v12.16.0
lrwxrwxrwx 1 ajnasz ajnasz    8 nov   17  2020 v12.18.0 -> v12.16.0
drwxrwxr-x 6 ajnasz ajnasz 4096 máj    8  2020 v14.2.0
drwxrwxr-x 6 ajnasz ajnasz 4096 júl    2 13:43 v8.17.0
	"
}

_znvm_get_download_dir() {
	echo "/tmp/znvm/foo/bar"
}

install_dir=$(_znvm_get_install_dir)
[ "$install_dir" = "$ZNVM_DIR/versions" ] || die "_znvm_get_install_dir should attach /versions to the ZNVM_DIR variable, got $install_dir"

install_dir=$(_znvm_get_normalized_version "10.1.1")
[ "$install_dir" = "v10.1.1" ] || die "_znvm_get_normalized_version should add v prefix to version, got $install_dir"
install_dir=$(_znvm_get_normalized_version "v10.1.1")
[ "$install_dir" = "v10.1.1" ] || die "_znvm_get_normalized_version should not change, got $install_dir"

version_from_path=$(_znvm_get_version_from_path "$ZNVM_DIR/versions/v1.10.1/bin")
[ "$version_from_path" = "v1.10.1" ] || die "_znvm_get_version_from_path version is bad, $version_from_path"


local_version=$(_znvm_get_local_version_for "v10")
[ "$local_version" = "v10.19.0" ] || die "_znvm_get_local_version_for fail, got $local_version"

local_version=$(_znvm_get_local_version_for "v12.18.0")
[ "$local_version" = "v12.16.0" ] || die "_znvm_get_local_version_for fail return version alias, got $local_version"
local_version=$(_znvm_get_local_version_for "default")
[ "$local_version" = "v12.16.0" ] || die "_znvm_get_local_version_for fail return default alias, got $local_version"


download_output_path=$(_znvm_get_download_output_path "v12.16.0")
[ "$download_output_path" = "/tmp/znvm/foo/bar/node-v12.16.0.tar.xz" ] || die "_znvm_get_download_output_path fail, got $download_output_path"


path_for_version=$(_znvm_get_path_for_version "v12")
[ "$path_for_version" = "/tmp/znvm_test/versions/v12.16.0/bin" ] || echo "_znvm_get_path_for_version fail, got $path_for_version"

alias_version=$(_znvm_get_alias_version "default")
[ "$alias_version" = "v12.16.0" ] || die "_znvm_get_alias_version wrong alias for deafult, got $alias_version"

alias_version=$(_znvm_get_alias_version "v12.18.0")

[ "$alias_version" = "v12.16.0" ] || die "_znvm_get_alias_version wrong alias for version, got $alias_version"

alias_version=$(_znvm_get_alias_version "v12.16.0")
[ "$alias_version" = "" ] || die "_znvm_get_alias_version wrong no alias version, got $alias_version"


closest_version="$(_znvm_find_closest_upper_version "12.1.1")"
[ "$closest_version" = "v12.16.0" ] || die "wrong closet version: $closest_version"
