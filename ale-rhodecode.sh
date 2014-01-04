#!/bin/bash

### BEGIN INIT INFO
# Provides: rhodecode
# Required-Start: $all
# Required-Stop: $all
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Starts RhodeCode
### END INIT INFO


USER=rhodecode

VENV_DIR=/var/www/rhode/venv
DATA_DIR=/var/www/rhode/data

CELERY_ARGS="$VENV_DIR/bin/paster celeryd $DATA_DIR/production.ini"
RHODECODE_ARGS="$VENV_DIR/bin/paster serve $DATA_DIR/production.ini"

CELERY_PID_FILE=/var/run/celeryd.pid
RHODECODE_PID_FILE=/var/run/rhodecode.pid

CELERY_LOG_FILE=/var/log/celeryd_init.log
RHODECODE_LOG_FILE=/var/log/rhodecode_init.log


# chkconfig: 345 81 04

start_celery() {
  if [ ! -f CELERY_PID_FILE ]; then
    su -c "$CELERY_ARGS --pidfile=$CELERY_PID_FILE -f $CELERY_LOG_FILE -l WARNING -q &" $USER
    while [[ ! -f CELEREY_PID_FILE ]]; do
      sleep 1 && echo ".";
    done
    echo "Done. PID is $(cat $CELERY_PID_FILE)."
  else
    echo "The celeryd paste script has filed a paste PID $(cat $CELERY_PID_FILE)"
    echo "It's likely started already at that PID."
  fi
}

start_rhodecode() {
  if [[ ! -f RHODECODE_PID_FILE ]]; then
    su -c "$RHODECODE_ARGS --pidfile=$RHODECODE_PID_FILE -f RHODECODE_LOG_FILE -l WARNING -q &" $USER
    while [[ ! -f RHODECODE_PID_FILE ]]; do
      sleep 1 && echo ".";
    done
    echo "Done. PID is $(cat $CELERY_PID_FILE)."
  else
    echo "The celeryd paste script has filed a paste PID $(cat $RHODECODE_PID_FILE)"
    echo "It's likely started already at that PID."
  fi
}


stop_celery() {
  if [[ -f CELEREY_PID_FILE ]]; then

  fi
}