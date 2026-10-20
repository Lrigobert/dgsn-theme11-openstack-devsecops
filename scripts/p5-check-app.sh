#!/usr/bin/env bash
# Vérifie le conteneur déployé sur l'instance cible (exécuté sur VM1). Usage : p5-check-app.sh <ip>
IP=$1
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts_p5 debian@"$IP" '
sudo docker ps --format "{{.Names}} {{.Image}} {{.Status}}"
sudo docker inspect dgsn-app --format "lecture_seule={{.HostConfig.ReadonlyRootfs}} cap_drop={{.HostConfig.CapDrop}} securite={{.HostConfig.SecurityOpt}} utilisateur={{.Config.User}} redemarrage={{.HostConfig.RestartPolicy.Name}}"
sudo docker exec dgsn-app id
'
