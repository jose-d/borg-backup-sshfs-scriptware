# parse arguments as described here:
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    echo "Hey, you should source this script, not execute it!"
    exit 1
fi

! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'ERROR: `getopt --test` failed in this environment.'
    exit 1
fi

OPTIONS=dvmiuosp
LONGOPTS=debug,verbose,mountonly,ignoremount,umount,osonly,skipcheck,pruneonly

! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    echo 'ERROR: getopt failed to parse arguments'
    exit 2
fi

eval set -- "$PARSED"

# detect options
DEBUG=n
MOUNTONLY=false
UMOUNT=false
IGNOREMOUNT=false
VERBOSE=n
OSONLY=false
PRUNEONLY=false

while true; do
    case "$1" in
        -o|--osonly)
            OSONLY=true
            shift
            ;;
        -d|--debug)
            DEBUG=y
            shift
            ;;
        -u|--umount)
            UMOUNT=true
            shift
            ;;
        -m|--mountonly)
            MOUNTONLY=true
            shift
            ;;
        -i|--ignoremount)
            IGNOREMOUNT=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=y
            shift
            ;;
        -s|--skipcheck)
            SKIPCHECK=true
            shift
            ;;
        -p|--pruneonly)
            PRUNEONLY=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error in argument parsing section"
            exit 3
            ;;
    esac
done
