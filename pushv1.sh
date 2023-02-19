# vim: set ai si et sw=4 ts=4 :

#
# Adaption of the PHP routine written by James Hicks
# SJB@20080417
#
# * Moved it all to shell script
# * Added full locking mechanism to stop concurrent runnings per server
#

LOG_DIR="/var/log/rsync"
LCK_DIR="/var/lock/rsync"
CFG_DIR="/rsyncbkp/rsync"
SRC_DIR="/rsyncbkp/backups"

DST_SERV="ldap2"
DST_PATH="push"
PWD=/home/ansible/bkpscript

CP="/bin/cp"
RM="/bin/rm"
DATE="/bin/date"
NICE="/bin/nice"
MKDIR="/bin/mkdir"
TOUCH="/bin/touch"
RSYNC="/bin/ionice -c3 /bin/rsync -rtv"
RSYNC_DEF_ARGS="-a --compress-level=9 --partial --timeout=3600 --delete-during --delete-excluded"

$RM -f ${LOG_DIR}/exitstatus

[[ ! -d "${LOG_DIR}" ]] && $MKDIR -p ${LOG_DIR}
[[ ! -d "${LCK_DIR}" ]] && $MKDIR -p ${LCK_DIR}


if [[ ! -d "${CFG_DIR}" || ! -d "${SRC_DIR}" ]]
then
    echo "Configuration or source structures don't exist."
    exit 2
fi



while [[ "$1" != "" ]]
do
    SERVER=$1
    LOCKFILE="${LCK_DIR}/rep.${SERVER}.lock"

    if [[ -f "${LOCKFILE}" ]]
    then
        echo "Copy locked for ${SERVER}"
        shift
        continue
    fi

    $TOUCH $LOCKFILE

    RSYNC_ARGS="${RSYNC_DEF_ARGS} --exclude-from=${CFG_DIR}/${SERVER}.exclude --password-file=${CFG_DIR}/${DST_SERV}.secret"


#  RSYNC_ARGS="${RSYNC_DEF_ARGS} --exclude-from=${CFG_DIR}/rep.${SERVER}.exclude --password-file=${CFG_DIR}/${DST_SERV}.secret"



#
# Set up default exclude patterns


#
# Set up default exclude patterns
#
    if [[ ! -f "${CFG_DIR}/${SERVER}.exclude" ]]
    then
        $CP ${CFG_DIR}/default.exclude ${CFG_DIR}/${SERVER}.exclude
    fi


#
# Set up default secret
#
    if [[ ! -f "${CFG_DIR}/${SERVER}.secret" ]]
    then
        $CP ${CFG_DIR}/default.secret ${CFG_DIR}/${SERVER}.secret
    fi




#
# Don't include a rate-limit by default.
#
    RATELIMIT=""
   if [[ -f "${CFG_DIR}/${SERVER}.ratelimit" ]]
    then
#
# Set a default value if it is needed
#
# NOTE: Should probably allow for the content of the ratelimit file to be included with
# a $(< FILE ) type construct, if the file is non-zero
#
        RATELIMIT="--bwlimit=500"
    fi





#
# Include a compress-level by default.
#
    COMPRESSLVL="--compress-level=9 "
    if [[ -f "${CFG_DIR}/${SERVER}.nocompress" ]]
    then
#
# Empty the value if we don't want one (RHEL4 servers)
#
        COMPRESSLVL=""
    fi

#
# Include extra command line arguments
#
    EXTRAS=""
    if [[ -f "${CFG_DIR}/${SERVER}.extras" ]]
    then
#
# Empty the value if we don't want one (RHEL4 servers)
#
        EXTRAS="$(< "${CFG_DIR}/${SERVER}.extras")"
    fi

#
# Attempt a copy
#
    $DATE > ${LOG_DIR}/${SERVER}.log

    $NICE $RSYNC $RSYNC_ARGS $EXTRAS $COMPRESSLVL $RATELIMIT rsync://root@${SERVER}:873/root/ ${SRC_DIR}/${SERVER}/ >> ${LOG_DIR}/${SERVER}.log 2>&1 &

    C_PID=$!
    echo $C_PID > $LOCKFILE
    wait $C_PID
    EXIT=$?
    echo $EXIT

#
# If we didn't finish cleanly, try again
#
    if [[ $EXIT -ne 0 ]]
    then
        echo "Non-clean exit.  Re-running for ${SERVER}."
        $DATE >> ${LOG_DIR}/${SERVER}.log

 $NICE $RSYNC $RSYNC_ARGS $EXTRAS $COMPRESSLVL $RATELIMIT rsync://root@${SERVER}:873/root/ ${SRC_DIR}/${SERVER}/ >> ${LOG_DIR}/${SERVER}.log 2>&1 &


        C_PID=$!
        echo $C_PID > $LOCKFILE
        wait $C_PID
        EXIT=$?
    fi

    echo "${EXIT}" > ${LOG_DIR}/exitvalue.${SERVER}

#
# For mail notfication backup completion status
#
   if [[ $EXIT -eq 0 ]]
   then

    printf "\tBackup SUCCESSFULL! for ${SERVER} rsync daemon exited with status code $EXIT\n" >> ${LOG_DIR}/exitstatus

   else

    printf "\tBackup UNSUCCESSFULL! for ${SERVER} rsync daemon exited with status code $EXIT\n" >> ${LOG_DIR}/exitstatus

   fi



   $RM -f ${LOCKFILE}

#
# Continue to next server in passed list
#
    shift 1
done




