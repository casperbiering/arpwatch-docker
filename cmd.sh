#!/usr/bin/env bash

#set -x
set -e

trap "killall rsyslog arpwatch nullmailer-send; exit 1" TERM

if [[ -z $ARPWATCH_NOTIFICATION_EMAIL_TO ]]; then
	echo "env ARPWATCH_NOTIFICATION_EMAIL_TO missing"
	exit 1
fi

if [[ -z $ARPWATCH_NOTIFICATION_EMAIL_FROM ]]; then
        echo "env ARPWATCH_NOTIFICATION_EMAIL_FROM missing"
	exit 1
fi

if [[ -z $ARPWATCH_NOTIFICATION_EMAIL_SERVER ]]; then
        echo "env ARPWATCH_NOTIFICATION_EMAIL_SERVER missing"
	exit 1
fi

COMMAND="arpwatch -u arpwatch -a -p"

if [[ "x$ARPWATCH_DEBUG" == "xyes" ]]; then
	COMMAND="${COMMAND} -d"
fi

if [[ "x$ARPWATCH_INTERFACE" != "x" ]]; then
        COMMAND="${COMMAND} -i ${ARPWATCH_INTERFACE}"
fi

COMMAND="${COMMAND} -m ${ARPWATCH_NOTIFICATION_EMAIL_TO}"

NULLMAILER_REMOTE="$ARPWATCH_NOTIFICATION_EMAIL_SERVER smtp"

if [[ "x$ARPWATCH_NOTIFICATION_EMAIL_SERVER_ENCRYPTION" == "xnone" ]]; then
	# skipping
	NULLMAILER_REMOTE="$NULLMAILER_REMOTE"
elif [[ "x$ARPWATCH_NOTIFICATION_EMAIL_SERVER_ENCRYPTION" == "xstarttls" ]]; then
	NULLMAILER_REMOTE="$NULLMAILER_REMOTE --starttls"
else
        NULLMAILER_REMOTE="$NULLMAILER_REMOTE --ssl"
fi

if [[ ! -z $ARPWATCH_NOTIFICATION_EMAIL_SERVER_PORT ]]; then
	NULLMAILER_REMOTE="$NULLMAILER_REMOTE --port=$ARPWATCH_NOTIFICATION_EMAIL_SERVER_PORT"
fi

if [[ ! -z $ARPWATCH_NOTIFICATION_EMAIL_SERVER_USER ]]; then
        NULLMAILER_REMOTE="$NULLMAILER_REMOTE --user=$ARPWATCH_NOTIFICATION_EMAIL_SERVER_USER"
fi

if [[ ! -z $ARPWATCH_NOTIFICATION_EMAIL_SERVER_PASS ]]; then
	NULLMAILER_REMOTE="$NULLMAILER_REMOTE --user=$ARPWATCH_NOTIFICATION_EMAIL_SERVER_PASS"
fi

DIR="/var/lib/arpwatch"
if ! su - arpwatch -s /bin/sh -c "test -w '$DIR'" ; then
	echo "$DIR is not writable by arpwatch user. chmod it 777."
	exit 1
fi

IFS='@' read -ra FROM <<< "$ARPWATCH_NOTIFICATION_EMAIL_FROM"

export NULLMAILER_FLAGS="fst"
export NULLMAILER_USER="${FROM[0]}"
export NULLMAILER_HOST="${FROM[1]}"
export NULLMAILER_NAME="Arpwatch ($HOSTNAME)"
echo $NULLMAILER_REMOTE > /etc/nullmailer/remotes
/etc/init.d/nullmailer start

touch /var/lib/arpwatch/arp.dat
chmod 777 /var/lib/arpwatch/arp.dat

touch /var/lib/arpwatch/arp.dat.new
chmod 777 /var/lib/arpwatch/arp.dat.new

# run rsyslogd to catch cron messages
rsyslogd -f /rsyslog.conf

${COMMAND}

while sleep 10; do
  ps aux |grep rsyslog |grep -q -v grep
  PROCESS_1_STATUS=$?
  ps aux |grep arpwatch |grep -q -v grep
  PROCESS_2_STATUS=$?
  ps aux |grep nullmailer-send |grep -q -v grep
  PROCESS_3_STATUS=$?

  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 -o $PROCESS_3_STATUS -ne 0 ]; then
    echo "One of the processes has already exited."
    exit 1
  fi
done
