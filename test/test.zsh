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

_znmv_get_download_dir() {
	echo "/tmp/znvm/foo/bar"
}

[ "$(_znvm_get_install_dir)" = "$ZNVM_DIR/versions" ] || die "_znvm_get_install_dir should attach /versions to the ZNVM_DIR variable"

[ "$(_znvm_get_normalized_version "10.1.1")" = "v10.1.1" ] || die "_znvm_get_normalized_version should add v prefix to version"
[ "$(_znvm_get_normalized_version "v10.1.1")" = "v10.1.1" ] || die "_znvm_get_normalized_version should not change"

[ "$(_znvm_get_version_from_path "$ZNVM_DIR/versions/v1.10.1/bin")" = "v1.10.1" ] || die "_znvm_get_version_from_path version is bad"



[ "$(_znvm_get_local_version_for "v10")" = "v10.19.0" ] || die "_znvm_get_local_version_for fail"

[ "$(_znvm_get_local_version_for "v12.18.0")" = "v12.16.0" ] || die "_znvm_get_local_version_for fail return version alias"
[ "$(_znvm_get_local_version_for "default")" = "v12.16.0" ] || die "_znvm_get_local_version_for fail return default alias"


[ "$(_znvm_get_download_output_path "v12.16.0")" = "/tmp/znvm/foo/bar/node-v12.16.0.tar.xz" ] || die "_znvm_get_download_output_path fail"
