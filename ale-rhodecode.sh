#!/bin/sh

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

CELERY_PID_FILE=/var/run/rhodecode/celeryd.pid
RHODECODE_PID_FILE=/var/run/rhodecode/rhodecode.pid

CELERY_LOG_FILE=/var/log/rhodecode/celeryd_init.log
RHODECODE_LOG_FILE=/var/log/rhodecode/rhodecode_init.log


# chkconfig: 345 81 04

start_celery() {
  if [ ! -f $CELERY_PID_FILE ]; then
    # actual cmd of run.
    su -c "$CELERY_ARGS --pidfile=$CELERY_PID_FILE -f $CELERY_LOG_FILE -l WARNING -q &" $USER
    
    while [[ ! -f $CELERY_PID_FILE ]]; do 
      sleep 1 && echo ".";
    done
    
    echo "Done. PID is $(cat $CELERY_PID_FILE)."
  else
    echo "The celery part has filed a PID $(cat $CELERY_PID_FILE)"
    echo "It's likely started already at that PID."
  fi
}

start_rhodecode() {
  if [[ ! -f $RHODECODE_PID_FILE ]]; then
    su -c "$RHODECODE_ARGS --daemon --user=$USER --pid-file=$RHODECODE_PID_FILE --log-file=$RHODECODE_LOG_FILE" $USER
    # check to make sure it's running
    while [[ ! -f $RHODECODE_PID_FILE ]]; do
      sleep 1 && echo ".";
    done
    
    echo "Done. PID is $(cat $RHODECODE_PID_FILE)."
  else
    echo "The rhodecode script has filed a PID $(cat $RHODECODE_PID_FILE)"
    echo "It's likely started already at that PID."
  fi
}


stop_celery() {
  if [[ -f $CELERY_PID_FILE ]]; then
    su -c "kill -s SIGINT $(cat $CELERY_PID_FILE)" $USER
  
    echo "waiting for process to die..."
    while [[ -f $CELERY_PID_FILE ]]; do
      sleep 1 && echo ".";
    done
    
    echo "Closed celery."
  else
    echo "$CELERY_PID_FILE does not exist. Need to be running for closing."
  fi
}

stop_rhodecode() {
  if [[ -f $RHODECODE_PID_FILE ]]; then

    su -c "$VENV_DIR/bin/paster serve --stop-daemon --pid-file=$RHODECODE_PID_FILE" $USER
  
    echo "waiting for process to die..."
    while [[ -f $RHODECODE_PID_FILE ]]; do
      sleep 1 && echo ".";
    done
    
    echo "Closed rhodecode."
  else
    echo "$RHODECODE_PID_FILE does not exist. Need to be running for closing."
  fi
}

case "$1" in
  start)
    echo "Starting Celery"
    start_celery
    echo "Starting RhodeCode"
    start_rhodecode
    ;;
  start_celery)
    echo "Starting Celery"
    start_celery
    ;;
  start_rhodecode)
    echo "Starting RhodeCode"
    start_rhodecode
    ;;
  stop)
    echo "Stopping RhodeCode"
    stop_rhodecode
    echo "Stopping Celery"
    stop_celery
    ;;
  stop_rhodecode)
    echo "Stopping RhodeCode"
    stop_rhodecode
    ;;
  stop_celery)
    echo "Stopping Celery"
    stop_celery
    ;;
  restart)
    echo "Stopping RhodeCode and Celery"
    stop
    echo "Starting Celery"
    start_celery
    echo "Starting RhodeCode"
    start_rhodecode
    ;;
  *)
    echo "Usage: ./rhodecode {start|stop|restart|start_celery|stop_celery|start_rhodecode|stop_rhodecode}"
    exit 2
    ;;
esac

exit 0