#!/bin/bash


# Usage info
show_help() {
       printf "Usage: ${0##*/} [-h] [-a PASSWORD] [-p PORT] [-c .sif FILE]\n"
       printf " -h                     display this help and exit\n"
       printf " -a PASSWORD            Rstudio password, default='password'\n"
       printf " -p PORT                Port, default=8788\n"
       printf " -c container 	       Singularity '.sif' container\n"
       printf " -l container  	       pull location of container, default=docker://bioconductor/bioconductor_docker:latest\n"
       printf " -b bind                bind paths\n"
       printf " -t tmp dir	       tmp dir for bind paths, default=~/tmp\n"
       return 0
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.
PASSWORD="password"
PORT="8788"
TMPDIR="~/tmp"
while getopts "h?a:p:c:l:b:t:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    a)  PASSWORD=$OPTARG
        ;;
    p)  PORT=$OPTARG
        ;;
    c)  CONTAINER=$OPTARG
        ;;
    l)  CONTAINER_LOCATION=$OPTARG
        ;;
    b)  BIND=$OPTARG
        ;;
    t)  TMPDIR=$OPTARG
	;;
    esac
done

shift "$(( OPTIND - 1 ))"

[ "${1:-}" = "--" ] && shift

echo $CONTAINER_LOCATION
# input checks
if [ -z "$CONTAINER" ] && [ -z "$CONTAINER_LOCATION" ]; then
	echo 'One of -c or -l has to be specified' >&2
	exit 1
fi
if [ ! -z "$CONTAINER" ] && [ ! -z "$CONTAINER_LOCATION" ]; then
	echo 'Only of -c or -l can be specified' >&2
	exit 1
fi
if [ -z "$CONTAINER" ]; then
	CONTAINER_NAME=$( echo "$CONTAINER_LOCATION" | grep -o "[a-z:_]*$" | grep -o "^[a-z_]*" ).sif
	echo $CONTAINER_NAME
	singularity pull $CONTAINER_NAME $CONTAINER_LOCATION || { echo "pulling container '$CONTAINER_LOCATION' failed" ; exit 1;  }
	CONTAINER=$( pwd )/$CONTAINER_NAME
	echo $CONTAINER
fi
if [ ! -f "$( pwd )/$CONTAINER" ]; then
	echo "Container '$CONTAINER' does not exist" >&2
	exit 1
fi
if [ -z "$TMPDIR" ]; then
	echo 'Missing -t tmp dir' >&2
	exit 1
fi
if [ ! -d "$TMPDIR" ]; then
	echo "Directory '$TMPDIR' does not exist" >&2
	exit 1
fi
# random string for subdirectory
TMPDIR_SINGULARITY=$( cat /dev/urandom | tr -dc '[:alnum:]' | fold -w ${1:-8} | head -n 1 )
# create temporary subdirectories
mkdir -p $TMPDIR/$TMPDIR_SINGULARITY/{run,tmp}
BIND_UTILS="$TMPDIR/$TMPDIR_SINGULARITY/tmp:/tmp,$TMPDIR/$TMPDIR_SINGULARITY/run:/run"

if [ -z "$BIND" ]; then
	SINGULARITY_BIND="$BIND_UTILS"
else
	SINGULARITY_BIND="$BIND,$BIND_UTILS"
fi

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        printf "\nDelete tmp dir"
	rm -r $TMPDIR/$TMPDIR_SINGULARITY	
}

SINGULARITY_CMD="SINGULARITY_BIND='$SINGULARITY_BIND' PASSWORD='$PASSWORD' singularity exec $CONTAINER rserver --auth-none=0 --auth-pam-helper=pam-helper --www-address=127.0.0.1 --www-port $PORT"
echo $SINGULARITY_CMD
eval $SINGULARITY_CMD

