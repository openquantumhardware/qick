#!/bin/bash
# environment setup copied from /usr/local/bin/start_jupyter.sh
set -a
. /etc/environment
set +a
for f in /etc/profile.d/*.sh; do source $f; done

dir=`dirname $0`
$dir/qick_client.py &
pid=$!
echo $pid > /tmp/qick.pid

