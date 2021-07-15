###############################################################################
# singRstudio.sh 
#
# Reto Gerber
# reto.gerber@uzh.ch
# 
# Licenced under the GNU General Public License 3.0 license.
###############################################################################

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
       printf " -r R lib	       set path to host R libs\n"
       printf " -d dry run	       dry run, construct singularity command\n"
       return 0
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.
PASSWORD="password"
PORT="8788"
TMPDIR="~/tmp"
RLIB_CONTAINER="/usr/local/lib/R/site-library,/usr/local/lib/R/library"
DRY_RUN=false
while getopts "h?a:p:c:l:b:t:r:d" opt; do
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
    r)  RLIB=$OPTARG
	;;
    d)  DRY_RUN=true
	;;
    esac
done

shift "$(( OPTIND - 1 ))"

[ "${1:-}" = "--" ] && shift

#echo $CONTAINER_LOCATION
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
if [ ! -f "$CONTAINER" ]; then
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
if [ -z "$RLIB" ]; then
	echo "No RLIB specified, installing packages is restricted."
	RLIB_COMB="$RLIB_CONTAINER"
elif  [ ! -d "$RLIB" ]; then
	echo "Directory '$RLIB' does not exist"
	exit 1
else
	RLIB_BIND_LOC="/home/rstudio/Rlib"
	RLIB_COMB="$RLIB_BIND_LOC,$RLIB_CONTAINER"
fi
# random string for subdirectory
TMPDIR_SINGULARITY=$( cat /dev/urandom | tr -dc '[:alnum:]' | fold -w ${1:-8} | head -n 1 )
# create temporary subdirectories
mkdir -p $TMPDIR/$TMPDIR_SINGULARITY/{run,tmp,db,rstudio,rsession,.rstudio-desktop}


BIND_UTILS="$TMPDIR/$TMPDIR_SINGULARITY/tmp:/tmp,$TMPDIR/$TMPDIR_SINGULARITY/run:/run,$TMPDIR/$TMPDIR_SINGULARITY/db:/var/lib/rstudio-server,$TMPDIR/$TMPDIR_SINGULARITY/rstudio:/home/rstudio,$TMPDIR/$TMPDIR_SINGULARITY/rsession/rsession.conf:/etc/rstudio/rsession.conf,$TMPDIR/$TMPDIR_SINGULARITY/.rstudio-desktop:/home/$USER/.rstudio-desktop"

if [ ! -z "$RLIB" ]; then
	BIND_UTILS="$BIND_UTILS,$RLIB:$RLIB_BIND_LOC"
	echo "r-libs-user='$RLIB_BIND_LOC'" > $TMPDIR/$TMPDIR_SINGULARITY/rsession/rsession.conf
	#cat $TMPDIR/$TMPDIR_SINGULARITY/rsession/rsession.conf
else
	touch $TMPDIR/$TMPDIR_SINGULARITY/rsession/rsession.conf
	#cat $TMPDIR/$TMPDIR_SINGULARITY/rsession/rsession.conf
fi


if [ -z "$BIND" ]; then
	SINGULARITY_BIND="$BIND_UTILS"
else
	SINGULARITY_BIND="$BIND,$BIND_UTILS"
fi

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        printf "\nDelete tmp dir\n"
	rm -r $TMPDIR/$TMPDIR_SINGULARITY	
}

#SINGULARITY_CMD="R_LIBS_USER='$RLIB_COMB' SINGULARITY_BIND='$SINGULARITY_BIND' PASSWORD='$PASSWORD' singularity exec $CONTAINER rserver --auth-none=0 --auth-pam-helper=pam-helper --www-address=127.0.0.1 --www-port $PORT"
SINGULARITY_CMD="SINGULARITY_BIND='$SINGULARITY_BIND' PASSWORD='$PASSWORD' singularity exec $CONTAINER rserver --auth-none=0 --auth-pam-helper=pam-helper --www-address=127.0.0.1 --www-port $PORT"
if $DRY_RUN; then
	echo $SINGULARITY_CMD
else 
	eval $SINGULARITY_CMD
fi

