# la-kurssi

Setup whole thing:<br>
```
git clone https://github.com/drediqq/la-kurssi

cd la-kurssi

bash install.sh
```
Master server:
Install master scripts Y
install docker Y, M (for master mode)

.env can be precreated to either /opt/master or /opt/replica, then env creation part will be skipped.

# modify
```server_backup.sh```<br>
export REMOTE_HOST=""<br>
export REMOTE_USER=""<br>
export SSH_KEY=""

```replica_report.sh```<br>
USER_NAME="${USER_NAME:-je}"

must be modified separately to reflect correct pathing.

