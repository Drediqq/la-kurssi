# la-kurssi

Setup whole thing:
```bash install.sh```
Master server:
Install master scripts Y
install docker Y, (for master mode M after)

.env can be precreated to either /opt/master or /opt/replica, then env creation part will be skipped.

# modify
server_backup.sh
export REMOTE_HOST=""
export REMOTE_USER=""
export SSH_KEY=""

replica_report.sh
USER_NAME="${USER_NAME:-je}"

must be modified separately to reflect correct pathing.

