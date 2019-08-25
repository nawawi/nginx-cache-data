#!/bin/bash
# nginx-proxy-cache-data.sh: 23082019 nawawi jamili <nawawijamili@gmail.com>
# This script converts nginx cache data into human readable format:
# host|size_in_byte|url

# debug
#set -x

if [ "x${UID}" != "x0" ]; then
    echo "This script must run as root ${UID}";
    exit 1;
fi

# path/file
_BASEPATH="/tmp/nginx-proxy-cache-data";
_SRCPATH="/var/run/nginx-proxy-cache";
_RDATE="$(date +"%Y-%m-%d %H:%M:%S")";
_LOCKFILE="${_BASEPATH}/nginx-proxy-cache-data-sh.lock";
_DATA_FILE="${_BASEPATH}/data-file-cache.txt";

# binary
_BIN_STRINGS="$(type -p strings)";
_BIN_SED="$(type -p sed)";
_BIN_DU="$(type -p du)";
_BIN_AWK="$(type -p awk)";
_BIN_GREP="$(type -p grep)";
_BIN_SORT="$(type -p sort)";

# permission
_CHOWN="runcloud-www:runcloud-www";
_CHMOD="600";

# helper, set permission
set_perm() {
    local path="$1";
    if [ -f $path -o -d $path ]; then
        chown $_CHOWN $path;
        chmod $_CHMOD $path;
    fi
}

# helper, create date file
set_time_file() {
    local _file="$1";

    echo $_RDATE > $_file;
    set_perm "${_file}";
}

# get file size
get_file_size() {
    local _file="$1";
    local _size="";

    _size="$($_BIN_DU -b $_file |$_BIN_AWK '{print $1}')";
    echo $_size;
}

# get cache key
get_file_key() {
    local _file="$1";
    local _key="";

    _key="$($_BIN_STRINGS $_file |$_BIN_GREP KEY: |$_BIN_AWK '{print $2}')";
    echo $_key;
}

# set url
get_file_url() {
    local _file="$1";
    local _url="";

    _url="$(get_file_key "${_file}" |$_BIN_SED -e 's#httpsGET#https://#g' -e 's#httpGET#http://#g')";
    echo $_url;
}

# get host
get_file_host() {
    local _file="$1";
    local _host="";

    _host="$(get_file_key "${_file}" |sed -e 's/httpsGET//g' -e 's/httpGET//g' -e 's/\/.*//g')";
    echo $_host;
}

# checking
if [ ! -d $_BASEPATH ]; then
    if ! mkdir $_BASEPATH &>/dev/null; then
        echo "Failed to create ${_BASEPATH}";
        exit 1;
    fi
fi

if ! cd $_BASEPATH &>/dev/null; then
    echo "Cannot change directory to ${_BASEPATH}";
    exit 1;
fi

if [ ! -d $_SRCPATH ]; then
    echo "${_SRCPATH} not exist";
    exit 1;
fi

if [ ! -x "${_BIN_STRINGS}" ]; then
    echo "_STRINGS binary not found";
    exit 1;
fi

if [ ! -x "${_BIN_SED}" ]; then
    echo "_SED binary not found";
    exit 1;
fi

if [ ! -x "${_BIN_DU}" ]; then
    echo "_DU binary not found";
    exit 1;
fi

if [ ! -x "${_BIN_AWK}" ]; then
    echo "_AWK binary not found";
    exit 1;
fi

if [ ! -x "${_BIN_GREP}" ]; then
    echo "_GREP binary not found";
    exit 1;
fi

if [ -f "${_LOCKFILE}" ]; then
    echo "Exit. Process already run.";
    exit 1;
fi

# lock
trap "{ rm -f $_LOCKFILE; exit 1; }" SIGINT SIGTERM SIGHUP SIGKILL SIGABRT EXIT;
set_time_file "${_LOCKFILE}";
set_perm "${_BASEPATH}";

_DATA_FILE_TMP="${_DATA_FILE}.tmp";
echo "# HOST|SIZE_IN_BYTE|URL" > $_DATA_FILE_TMP;

find $_SRCPATH -type f ! -size 0 |while read f; do
    _size="$(get_file_size $f)";
    _url="$(get_file_url $f)";
    _host="$(get_file_host $f)";

    echo "${_host}|${_size}|${_url}" >> $_DATA_FILE_TMP;
done

$_BIN_SORT -u $_DATA_FILE_TMP > $_DATA_FILE;
set_perm "${_DATA_FILE}";
rm $_DATA_FILE_TMP;

set_time_file "${_BASEPATH}/last-run.txt";

rm -f $_LOCKFILE;
exit 0;
