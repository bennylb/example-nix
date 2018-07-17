{ writeText, coreutils, gnused }:

writeText "example-shell-lib"
    ''
    do_with_header()
    {
        ${coreutils}/bin/echo
        ${coreutils}/bin/echo
        ${coreutils}/bin/echo "***** $@" | ${gnused}/bin/sed 's/ /\n***** /g'
        ${coreutils}/bin/echo "*****"
        ${coreutils}/bin/echo
        "$@"
    }
    ''
