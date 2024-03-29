#!/usr/bin/env bash

# ==================== set -e start ====================
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

function _Vfunc_array_memberp ()
{
    local i
    for i in "${@:3}"; do
        [ $i = "$1" ] && return 0
    done
    echo -e "\e[31m$2\e[0m"
    return 1
}

_date_show ()
{
    printf "%(%Y%m%d%H%M%S)T\n" "$@"
}
declare -a Vmakepkg_opts
declare Vpkgbasename
Vpkgbasename=$(set -e; source PKGBUILD; echo "$pkgbase")
declare Vpkgver
Vpkgver=$(set -e; source PKGBUILD; echo "$pkgver")
declare Vpkgrel
Vpkgrel=$(set -e; source PKGBUILD; echo "$pkgrel")
declare Vpkgarch
Vpkgarch="$(uname -m)"
( set -e; source PKGBUILD;
  _Vfunc_array_memberp \
      "$Vpkgarch" \
      "current machine architecture $Vpkgarch \
is not supported by defined { ${arch[*]} }" \
      "${arch[@]}" ;
)

declare Vmarch=0
declare Vmulticpu=y
declare Vconfig='config_x86-64-v1'
declare Vcompress=n
declare Vtest=n
declare Vinstall=n
declare Vrtn=0
declare Vshalogfilename="sha256sum.log"
declare Vshalogascfilename="sha256sum.log.asc"
declare VgpgverifyID="D7E3805570B934FEC2CC8C6F1E72C8B73C01055B"

declare VdistDirHostName=dist
declare VdistDir
declare VdistDirName
declare VdistDirParent
declare VdistTarball
declare VpkgName
function _Vfunc_set_pkgnames_and_distdir ()
{
    local prefix='' tmpvar
    [[ $Vtest = 'y' ]] && prefix='FAKE__'
    # fake basename will also applied to fake pkgbuild's env
    Vpkgbasename="${prefix}${Vpkgbasename}"
    VpkgName="${Vpkgbasename}-${Vpkgver}-${Vpkgrel}-${Vpkgarch}-march_${Vmarch}"
    VdistDirParent="${this_dir_name%/}/${VdistDirHostName}"
    VdistDir="${VdistDirParent%/}/${VpkgName}_release_$(_date_show)"
    if [[ $Vinstall != 'y' ]] ; then
        if [[ -e $VdistDir ]] ; then
            _msg "remove old dist: $VdistDir"
            if ( read -p "Really?(y/n) " _yon && [[ $_yon = 'y' ]] )
            then
                _cmd_exec_notest rm -rf "$VdistDir"
                _nerr "rm -rf $VdistDir"
            else
                while [[ -e $VdistDir ]]; do
                    VdistDir="${VdistDir%/}_$(_date_show)_${RANDOM}"
                done
            fi
        fi
        mkdir -p "$VdistDir" ; _nerr "inner: mkdir '$VdistDir'"
        VdistTarball="${VdistDir%/}.tar.xz"
        if [[ -e $VdistTarball ]] ; then
            _err "dist tarball existed: $VdistTarball"
        fi
    fi
    tmpvar="${VdistDir%/}"
    VdistDirName="${tmpvar##*/}"
    if [[ -z $VdistDirName ]] ; then
        _err "inner VdistDirName empty"
    fi
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
    _cmd_show "$@"
    if [ "$Vtest" = 'y' ]; then
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
    local opts="$1"
    local -a _envs=("${@:2}")
    if [ "$Vtest" = 'y' ]; then
        _cmd_exec_notest \
            makepkg "${_envs[@]}"       \
            "PKGBASE=$Vpkgbasename" \
            "PKGVER=$Vpkgver"       \
            "PKGREL=$Vpkgrel"       \
            "$opts" "${Vmakepkg_opts[@]}" \
            -p __FAKE_PKGBUILD__
        return $?
    fi
    _cmd_exec_notest \
        makepkg "${_envs[@]}" "$opts" "${Vmakepkg_opts[@]}"
}

declare -a VdistITEMS
declare VdistShaHashStr
_get_dist_files ()
{
    local i j opwd
    opwd="$(pwd)"
    _nerr "inner: pwd -- _get_dist_files"
    cd "${this_dir_name}"; _nerr "inner cd: ${this_dir_name}"
    local _dotglob_p=0
    if shopt -pq dotglob ; then
        _dotglob_p=1
    else
        shopt -s dotglob
        _nerr "shopt -s dotglob"
    fi

    for i in * ; do
        if [[ $i = '.git' ]]     || \
               [[ $i = 'src' ]]  || \
               [[ $i = 'pkg' ]]  || \
               [[ $i =~ ^"$VdistDirHostName" ]] || \
               [[ $i =~ ^sha256sum\.log.* ]]
        then
            :
        else
            VdistITEMS+=("$i")
            if [[ -d $i ]] ; then
                _nerr "inner pwd -- 2"
                _msg "gen shahash for dir $i ..."
                j="$(find "$i" -type f -print0 | xargs --null sha256sum -b)"
                _nerr "shahash: dir $i"
            else
                _msg "gen shahash for file $i ..."
                j="$(sha256sum -b "$i")"
                _nerr "shahash: file $i"
            fi
            if [[ -z $VdistShaHashStr ]]; then
                VdistShaHashStr="${j}"
            else
                VdistShaHashStr="${VdistShaHashStr}
${j}"
            fi
        fi
    done
    if [[ $_dotglob_p -ne 1 ]] ; then
        shopt -u dotglob
        _nerr "shopt -u dotglob"
    fi
    cd "$opwd" ;  _nerr "inner cd: $opwd"
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

# ==================== set -e end ====================
set +e

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
_Vfunc_set_pkgnames_and_distdir

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
declare Vnprocs
Vnprocs="$(nproc)"; _nerr "inner nproc"
if [[ ! $Vnprocs =~ ^[1-9][0-9]* ]] ; then
    _nerr "inner invalid nproc value: $Vnprocs"
fi
Vargs+=("MAKEFLAGS=-j${Vnprocs}")
Vargs+=("_microarchitecture=${Vmarch}")
Vargs+=("use_numa=${Vmulticpu}")
Vargs+=("_config=${Vconfig}")
Vargs+=("_compress_modules=${Vcompress}")
if [[ -n $__MAKE_NO_CONFIRM__ ]]; then
    Vmakepkg_opts+=("--noconfirm")
fi

function _Vfunc_clean_build_cache () {
    local opwd
    opwd="$(pwd)"; _nerr "inner pwd -- _Vfunc_clean_build_cache"
    _cmd_exec_notest cd "$this_dir_name"; _nerr "inner cd: $this_dir_name"
    _cmd_exec_notest rm -f *.pkg.tar.zst ; _nerr "rm -f *.pkg.tar.zst"
    _cmd_exec_notest rm -f *.tar.xz ; _nerr "rm -f *.tar.xz"
    _cmd_exec_notest rm -f *.tar.sign ; _nerr "rm -f *.tar.sign"
    _cmd_exec_notest rm -f patch-*-xanmod*.xz ; _nerr "rm -f patch-*-xanmod*.xz"
    if [[ -d src ]] ; then
        _cmd_exec_notest rm -rf ./src ; _nerr "rm -rf src"
    fi
    if [[ -d pkg ]] ; then
        _cmd_exec_notest rm -rf ./pkg ; _nerr "rm -rf pkg"
    fi
    _cmd_exec_notest cd "$opwd" ; _nerr "inner cd: $opwd"
}

_Vfunc_clean_build_cache

if [ "$Vinstall" = y ]; then
    _cmd_exec_main_step -sfCi "${Vargs[@]}"
else
    _cmd_exec_main_step -sfC  "${Vargs[@]}"
fi
Vrtn=$?
if [[ $Vrtn -eq 0 ]]; then
    if [[ $Vinstall != 'y' ]] ; then
        _msg "Generate dist ..."
        _get_dist_files
        _cmd_exec_notest cp -a "${VdistITEMS[@]}" "${VdistDir%/}/"
        _nerr "cp generations to dist with fatal"
        cd "$VdistDir"
        _msg "Gen sha256sum.log ..."
        if [[ -e $Vshalogfilename ]] || [[ -e $Vshalogascfilename ]]
        then
            _err "inner: '$Vshalogfilename' or '$Vshalogascfilename' existed"
        fi
        echo "$VdistShaHashStr" >> "$Vshalogfilename"
        _nerr "write shahashs fatal"
        _cmd_exec_notest sha256sum -c "$Vshalogfilename"
        _nerr "shahash recheck fatal"
        if [[ -n $VgpgverifyID ]] && \
               gpg --list-secret-keys \
                   "$VgpgverifyID" >/dev/null 2>&1
        then
            gpg --detach-sign --armor \
                -u "$VgpgverifyID" -o "$Vshalogascfilename"  "$Vshalogfilename"
        fi
        _nerr "shahash asc file generated with fatal"
        _msg "Ok: dist dir is '$VdistDir'"
        _msg "clean build cache ..."
        _Vfunc_clean_build_cache
        _msg "create release tarball ..."
        _cmd_exec_notest tar -Jcf "$VdistTarball" -C "${VdistDirParent}" "$VdistDirName"
        _nerr "create dist tarball with fatal: $VdistTarball"
        _cmd_exec_notest rm -rf "$VdistDir"
        _nerr "remove dist dir fatal: $VdistDir"
        _msg "Ok: all is done"
    else
        _msg "makepkg with installation successfull"
    fi
else
    _err "makepkg with fatal"
fi
