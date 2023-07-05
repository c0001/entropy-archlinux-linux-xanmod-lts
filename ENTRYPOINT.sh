#!/usr/bin/env bash

set -e
_date_show ()
{
    printf "%(%Y%m%d%H%M%S)T\n" "$@"
}

_err ()
{
    echo -e "\e[31m$(_date_show) err: ${1}\e[0m"; exit 1;
}

_nerr ()
{
    if [ $? -ne 0 ]; then
        _err "$1"
    fi
}

_print ()
{
    printf "$@" >&2
}

_msg ()
{
    printf "\e[032m$(_date_show) msg: ${1}\e[0m" >&2
    printf "\n" >&2
}

_cmd_show ()
{
    local command="$1"
    local -a args=("${@:2}")
    local this_date="$(trap '' SIGINT; _date_show)"
    _print "\e[33m%s\e[0m [\e[33m%s\e[0m]: " "[${this_date}]" "SHOW"
    _print "\e[1m%s\e[0m" "${command}"
    local item
    local count=1
    for item in "${args[@]}"
    do
        _print " \e[34m%s\e[0m:\e[4m%s\e[0m" "[$count]" "${item}"
        let count++ ; : ;
    done
    _print '\n'
}

_cmd_exec ()
{
    _cmd_show "$@"; "$@"
}

_cmd_exec gpg --locate-keys torvalds@kernel.org gregkh@kernel.org
_nerr "Import gpg keys with fatal"

_v_workspace=/home/builder/project/linux-xanmod-lts
_v_make_type=${__MAKE_TYPE__}
if [[ -z $_v_make_type ]] ; then
    _err "make type is not specified"
fi
cd "$_v_workspace"
export __MAKE_NO_CONFIRM__=1
make "$_v_make_type"
