#!/bin/bash
set -o xtrace
docker exec -it cobbler cat /var/lib/dhcpd/dhcpd.leases|grep '^lease'|cut -d '' -f 2|sort -u|xargs -I {} echo {}
