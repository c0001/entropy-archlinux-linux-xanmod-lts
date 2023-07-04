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
declare Vrtn=0
declare VdistDir="${this_dir_name%/}/dist"
declare Vshalogfile="${this_dir_name%/}/sha256sum.log"
declare Vshalogascfile="${this_dir_name%/}/sha256sum.log.asc"
declare VgpgverifyID="D7E3805570B934FEC2CC8C6F1E72C8B73C01055B"

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
    printf "%(%Y%m%d%H%M%S)T\n" "$@"
}

_print ()
{
    printf "$@" >&2
}

_msg ()
{
    printf "\e[032m${1}\e[0m" >&2
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
    _cmd_show "$@"
    if [ "$Vtest" = y ]; then
        return 0
    fi
    "$@"
}

_cmd_exec_notest ()
{
    _cmd_show "$@"; "$@"
}

_cmd_exec_main_step ()
{
    _cmd_show "$@"
    if [ "$Vtest" = y ]; then
        touch linux-xanmod-lts-headers-x86_64_test_fake.pkg.tar.zst
        _nerr "inner: fake touch"
        touch linux-xanmod-lts-x86_64_test_fake.pkg.tar.zst
        _nerr "inner: fake touch"
        return 0
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
   processors. Breaks CUDA/NvEnc.  Archlinux and Xanmod not set it by
   default.
   * If set possibly(may) increase performance
   * Default not set as stock default with multi processors usage

2. -a : The target cpu microarchitecture for optimized for this kernel
   building. (use option --list-arch to show available architectures)

3. -c :

   Choose between the 4 main configs for stable branch. Default
   x86-64-v1 which use CONFIG_GENERIC_CPU2: Possible values:
   'config_x86-64-v1' (default) / 'config_x86-64-v2' /
   'config_x86-64-v3' / 'config_x86-64-v4' This will be overwritten by
   selecting any option in microarchitecture script Source files:
   https://github.com/xanmod/linux/tree/5.17/CONFIGS/xanmod/gcc

4. -i : install packages after built

5. --sign-gpg-key : the gnupg keyid/name for sign the distribution, if
   not set, using the author's one if found and can be used.

6. --compress : compress modules with ZSTD methods (default disabled)

7. --test : Dry run without do anything but show the makepkg command
   pipeline.

EOF
}

declare options
options="$(getopt -o ha:c:i \
--long help \
--long list-arch \
--long nm \
--long compress \
--long sign-gpg-key \
--long test -- "$@")"
_nerr
eval set -- "$options"
while true; do
    case "$1" in
        -h|--help)   _help;        exit 0 ;;
        --list-arch) _march_list ; exit 0 ;;
        -a) shift 1; Vmarch="$1"          ;;
        -i)          Vinstall=y           ;;
        --nm)        Vmulticpu=n          ;;
        -c) shift;   Vconfig="$1"         ;;
        --compress)  Vcompress=y          ;;
        --sign-gpg-key)
            shift 1
            VgpgverifyID="$1"             ;;
        --test)      Vtest=y              ;;
        --) shift 1;                break ;;
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

rm -f *.pkg.tar.zst ; _nerr "rm -f *.pkg.tar.zst"
rm -f "$Vshalogfile" ; _nerr "rm -f $Vshalogfile"
rm -f "$Vshalogascfile" ; _nerr "rm -f $Vshalogascfile"

if [[ -e $VdistDir ]] ; then
    _msg "remove old dist: $VdistDir"
    if ( read -p "Really?(y/n) " _yon && [[ $_yon = 'y' ]] )
    then
        _cmd_exec_notest rm -rf "$VdistDir"
        _nerr "rm -rf $Vshalogascfile"
    else
        while [[ -e $VdistDir ]]; do
            VdistDir="${VdistDir%/}_$(_date_show)_${RANDOM}"
        done
    fi
fi
mkdir -p "$VdistDir" ; _nerr "inner: mkdir '$VdistDir'"

if [ "$Vinstall" = y ]; then
    _cmd_exec_main_step makepkg -sfCi "${Vargs[@]}"
else
    _cmd_exec_main_step makepkg -sfC  "${Vargs[@]}"
fi
Vrtn=$?
if [[ $Vrtn -eq 0 ]]; then
    if [[ $Vinstall != 'y' ]] ; then
        _msg "Generate dist ..."
        _msg "Gen sha256sum.log ..."
        if [[ -e $Vshalogfile ]] || [[ -e $Vshalogascfile ]]
        then
            _err "inner: '$Vshalogfile' or '$Vshalogascfile' existed"
        fi
        sha256sum -b *.pkg.tar.zst >> "$Vshalogfile"
        _nerr "shahash for pkgs fatal"
        if [[ -n $VgpgverifyID ]] && \
               gpg --list-secret-keys \
                   "$VgpgverifyID" >/dev/null 2>&1
        then
            gpg --detach-sign --armor \
                -u "$VgpgverifyID" -o "$Vshalogascfile"  "$Vshalogfile"
        fi
        _nerr "shahash asc file generated with fatal"
        _cmd_exec_notest mv *.pkg.tar.zst "$Vshalogascfile" "$Vshalogfile" "${VdistDir%/}/"
        _nerr "mv generations to dist with fatal"
        _msg "Ok: dist dir is '$VdistDir'"
    fi
else
    _err "makepkg with fatal"
fi
