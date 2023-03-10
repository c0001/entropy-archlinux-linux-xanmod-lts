#!/usr/bin/env bash

set -e

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
    cat << EOF

    Available CPU microarchitectures:

    1) AMD K6/K6-II/K6-III
    2) AMD Athlon/Duron/K7
    3) AMD Opteron/Athlon64/Hammer/K8
    4) AMD Opteron/Athlon64/Hammer/K8 with SSE3
    5) AMD 61xx/7x50/PhenomX3/X4/II/K10
    6) AMD Family 10h (Barcelona)
    7) AMD Family 14h (Bobcat)
    8) AMD Family 16h (Jaguar)
    9) AMD Family 15h (Bulldozer)
   10) AMD Family 15h (Piledriver)
   11) AMD Family 15h (Steamroller)
   12) AMD Family 15h (Excavator)
   13) AMD Family 17h (Zen)
   14) AMD Family 17h (Zen 2)
   15) AMD Family 19h Zen 3 processors (Zen 3)
   16) Transmeta Crusoe
   17) Transmeta Efficeon
   18) IDT Winchip C6
   19) Winchip-2/Winchip-2A/Winchip-3
   20) AMD Elan
   21) Geode GX1 (Cyrix MediaGX)
   22) AMD Geode GX and LX
   23) Cyrix III or C3
   24) VIA C3 "Nehemiah"
   25) VIA C7
   26) Intel Pentium 4, Pentium D and older Nocona/Dempsey Xeon CPUs with Intel 64bit
   27) Intel Atom
   28) Intel Core 2 and newer Core 2 Xeons (Xeon 51xx and 53xx)
   29) Intel 1st Gen Core i3/i5/i7-family (Nehalem)
   30) Intel 1.5 Gen Core i3/i5/i7-family (Westmere)
   31) Intel Silvermont
   32) Intel Goldmont (Apollo Lake and Denverton)
   33) Intel Goldmont Plus (Gemini Lake)
   34) Intel 2nd Gen Core i3/i5/i7-family (Sandybridge)
   35) Intel 3rd Gen Core i3/i5/i7-family (Ivybridge)
   36) Intel 4th Gen Core i3/i5/i7-family (Haswell)
   37) Intel 5th Gen Core i3/i5/i7-family (Broadwell)
   38) Intel 6th Gen Core i3/i5/i7-family (Skylake)
   39) Intel 6th Gen Core i7/i9-family (Skylake X)
   40) Intel 8th Gen Core i3/i5/i7-family (Cannon Lake)
   41) Intel 8th Gen Core i7/i9-family (Ice Lake)
   42) Xeon processors in the Cascade Lake family
   43) Intel Xeon (Cooper Lake)
   44) Intel 3rd Gen 10nm++ i3/i5/i7/i9-family (Tiger Lake)
   45) Intel Sapphire Rapids
   46) Intel Rocket Lake
   47) Intel Alder Lake

   92) Generic-x86-64-v2 (Nehalem and newer)
   93) Generic-x86-64-v3 (Haswell and newer)
   94) Generic-x86-64-v4 (AVX512 CPUs)

   98) Intel-Native optimizations autodetected by GCC
   99) AMD-Native optimizations autodetected by GCC

    0) Generic (default)

EOF
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
