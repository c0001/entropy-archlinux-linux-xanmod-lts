#!/usr/bin/env bash

set -e

this_source_name="${BASH_SOURCE[0]}"
while [ -h "$this_source_name" ]; do # resolve $this_source_name until the file is no longer a symlink
    this_dir_name="$( cd -P "$( dirname "$this_source_name" )" >/dev/null && pwd )"
    this_source_name="$(readlink "$this_source_name")"

    # if $this_source_name was a relative symlink, we need to resolve it relative
    # to the path where the symlink file was located
    [[ $this_source_name != /* ]] && this_source_name="$this_dir_name/$this_source_name"
done
this_dir_name="$( cd -P "$( dirname "$this_source_name" )" >/dev/null && pwd )"

# ensure do with project root
cd "$this_dir_name"

declare Vmarch=0
declare Vmulticpu=y
declare Vconfig='config_x86-64-v1'
declare Vcompress=n
declare Vtest=n
declare Vinstall=n

_err ()
{
    echo -e "\e[31m${1}\e[0m"; exit 1;
}

_nerr ()
{
    if [ $? -ne 0 ]; then
        err "$1";
    fi
}

_date_show ()
{
    date -u +"%Y%m%d%H%M%S"
}

_msg ()
{
    printf "$@" >&2
}

_cmd_show ()
{
    local command="$1"
    local -a args=("${@:2}")
    local this_date="$(trap '' SIGINT; _date_show)"
    _msg "\e[33m%s\e[0m [\e[33m%s\e[0m]: " "[${this_date}]" "SHOW"
    _msg "\e[1m%s\e[0m" "${command}"
    local item
    local count=1
    for item in "${args[@]}"
    do
        _msg " \e[34m%s\e[0m:\e[4m%s\e[0m" "[$count]" "${item}"
        let count++ ; : ;
    done
    _msg '\n'
}

_cmd_exec ()
{
    _cmd_show "$@"
    if [ "$Vtest" = y ]; then
        exit 0
    fi
    "$@"
}

_march_list ()
{
    cat choose-gcc-optimization.sh | grep -x -P '^ +[0-9]+\) .+[^;][^;]$' | less
}

_help ()
{
    cat <<EOF
${BASH_SOURCE[0]} [-h|--help|--list-arch] [-a architecture] [--nm] [-c config] [--test]

1. --nm :

   Disable NUMA since most users do not have multiple
   processors. Breaks CUDA/NvEnc.  Archlinux and Xanmod enable it by
   default.  Set variable "use_numa" to:
   * n to disable (possibly increase performance)
   * y to enable  (stock default)

2. -a : The target cpu microarchitecture for optimized for this kernel
   building. (use option --list-arch to show available architectures)

3. -c :

   Choose between the 4 main configs for stable branch. Default
   x86-64-v1 which use CONFIG_GENERIC_CPU2: Possible values:
   'config_x86-64-v1' (default) / 'config_x86-64-v2' /
   'config_x86-64-v3' / 'config_x86-64-v4' This will be overwritten by
   selecting any option in microarchitecture script Source files:
   https://github.com/xanmod/linux/tree/5.17/CONFIGS/xanmod/gcc

4. --test : Dry run without do anything but show the makepkg command
   pipeline.

EOF
}

declare options
options="$(getopt -o ha:c:i \
--long help --long list-arch --long nm --long compress --long test -- "$@")"
_nerr
eval set -- "$options"
while true; do
    case "$1" in
        -h|--help)   _help;        exit 0 ;;
        --list-arch) _march_list ; exit 0 ;;
        -a) shift;   Vmarch="$1"          ;;
        -i)          Vinstall=y           ;;
        --nm)        Vmulticpu=n          ;;
        -c) shift;   Vconfig="$1"         ;;
        --compress)  Vcompress=y          ;;
        --test)      Vtest=y              ;;
        --) shift;                  break ;;
        *) _help;                  exit 1 ;;
    esac
    shift
done

case "$Vmarch" in
    0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47)
        : ;;
    92|93|94|98|99) : ;;
    *) _err "wrong type of architecture chosen '$Vmarch'." ;;
esac

case "$Vconfig" in
    config_x86-64-v1) : ;;
    config_x86-64-v2) : ;;
    config_x86-64-v3) : ;;
    config_x86-64-v4) : ;;
    *) _err "wrong type of config chosen '$Vconfig'" ;;
esac

declare -a Vargs
Vargs=("_microarchitecture=${Vmarch}"
       "use_numa=${Vmulticpu}"
       "_config=${Vconfig}"
       "_compress_modules=${Vcompress}"
      )

if [ "$Vinstall" = y ]; then
    _cmd_exec makepkg -sfCi "${Vargs[@]}"
else
    _cmd_exec makepkg -sfC  "${Vargs[@]}"
fi
