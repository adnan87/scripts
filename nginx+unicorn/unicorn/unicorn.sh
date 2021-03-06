#!/bin/bash
### BEGIN INIT INFO
# Provides:          unicorn init script
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: unicorn
# Description:       Rails http server
### END INIT INFO

CONFIGPATH=/etc/unicorn
CONFIG_VARS='RAILS_USER RAILS_ENV RAILS_DIR UNICORN_CONFIG UNICORN_PID'

check_pidfile() {
    PIDFILE=$1
    PID=0
    if [[ -f "$PIDFILE" ]]; then
        PID_IN_FILE=`cat $PIDFILE`
        [[ -f "/proc/$PID_IN_FILE/cmdline" ]] && [[ "`grep -c '^unicorn' /proc/$PID_IN_FILE/cmdline`" = "1" ]] && PID=$PID_IN_FILE
    fi
    echo $PID
}

[[ -d "$CONFIGPATH" ]] || { echo "Cannot find $CONFIGPATH"; exit 3; };

if [[ -n "$2" ]]; then
    ACTION=$2
    SITES=$1
else
    ACTION=$1
    SITES=`cd $CONFIGPATH && ls *conf | sed -e 's%.conf$%%'`
fi

for SITE in $SITES; do
    unset $CONFIG_VARS
    . $CONFIGPATH/$SITE.conf
    for CONFIG_VAR in $CONFIG_VARS; do
        [[ -n "${!CONFIG_VAR}" ]] || { echo "Variable $CONFIG_VAR is not set in $CONFIGPATH/$SITE.conf"; exit 3; }
    done
done

case "$ACTION" in
    start)
        for SITE in $SITES; do
            unset $CONFIG_VARS
            . $CONFIGPATH/$SITE.conf
            PID=`check_pidfile $UNICORN_PID`
            if [[ "$PID" = "0" ]]; then
                echo -n "Starting $SITE ..."
                CMD="export rvm_trust_rvmrcs_flag=1; cd $RAILS_DIR && bundle exec unicorn -c $UNICORN_CONFIG -E $RAILS_ENV -D"
                if [ "$RAILS_USER" != "`whoami`" ]; then
                    su - $RAILS_USER -c "$CMD"
                else
                    bash -l -c "$CMD"
                fi
            else
                echo "$SITE is already running (PID $PID)"
            fi
        done
        ;;

    stop)
        for SITE in $SITES; do
            unset $CONFIG_VARS
            . $CONFIGPATH/$SITE.conf
            echo -n "Stopping $SITE ..."
            PID=`check_pidfile $UNICORN_PID`
            if [[ "$PID" != "0" ]]; then
                COUNT=0
                while [ $COUNT -lt 10 -a "`check_pidfile $UNICORN_PID`" != "0" ]; do
                    kill $PID
                    sleep 1
                done
                [[ $COUNT -eq 10 ]] && kill -9 $PID
                echo "done"
            else
                echo "$SITE is not running"
            fi
        done
        ;;

    status)
        EXIT_CODE=0
        for SITE in $SITES; do
            unset $CONFIG_VARS
            . $CONFIGPATH/$SITE.conf
            PID=`check_pidfile $UNICORN_PID`
            echo -n "$SITE: "
            if [[ "$PID" != "0" ]]; then
                echo "running (PID $PID)"
            else
                echo "not running"
                EXIT_CODE=3
            fi
        done
        exit $EXIT_CODE
        ;;

    reload)
        EXIT_CODE=0
        for SITE in $SITES; do
            unset $CONFIG_VARS
            . $CONFIGPATH/$SITE.conf
            echo -n "Reloading $SITE ... "
            PID=`check_pidfile $UNICORN_PID`
            if [[ "$PID" != "0" ]]; then
                kill -USR2 $PID
    if [[ "$?" = "0" ]]; then
                    echo "done"
                else
                    echo "failed"
                    EXIT_CODE=3
                fi
            else
                echo "not running! Will start instead"
                $0 $SITE start
            fi
        done
        exit $EXIT_CODE
        ;;

    restart)
        for SITE in $SITES; do
            $0 $SITE stop
            sleep 2
            $0 $SITE start
        done
        ;;

    *)
        echo "Usage: $0 [`echo $SITES | sed -e 's# #|#g'`] {start|stop|restart|status|reload}"
        exit 3
esac
