### nodes 0-2: PG nodes
### nodes 3 4: HAProxy + Keepalived nodes

./anydbver --namespace=pg-haproxy deploy \
node0 pg:16 patroni \
node1 pg:16,master=node0 patroni:master=node0 \
node2 pg:16,master=node0 patroni:master=node0 

# node3:
# We are adding docker network (cap-add) flags to be able to manipulate VIPs
docker run --cap-add=NET_ADMIN --cap-add=NET_BROADCAST --cap-add=NET_RAW \
--name pg-haproxy-$(whoami)-node3 --platform linux/amd64 \
-d --cgroupns=host --tmpfs /tmp --network pg-haproxy-$(whoami)-anydbver \
--tmpfs /run --tmpfs /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup \
--hostname node3 rockylinux:8-sshd-systemd-$(whoami)

# node4:
# We are adding docker network (cap-add) flags to be able to manipulate VIPs
docker run --cap-add=NET_ADMIN --cap-add=NET_BROADCAST --cap-add=NET_RAW \
--name pg-haproxy-$(whoami)-node4 --platform linux/amd64 \
-d --cgroupns=host --tmpfs /tmp --network pg-haproxy-$(whoami)-anydbver \
--tmpfs /run --tmpfs /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup \
--hostname node4 rockylinux:8-sshd-systemd-$(whoami)


./anydbver --namespace=pg-haproxy ssh node0
psql -c "create user healthchkusr superuser encrypted password 'hc321'"

### On all database nodes:
./anydbver --namespace=pg-haproxy ssh node0
./anydbver --namespace=pg-haproxy ssh node1
./anydbver --namespace=pg-haproxy ssh node2

cat <<EOF >/opt/pgsqlchk
#!/bin/bash
PGBIN=/usr/pgsql-16/bin/
PGSQL_HOST="localhost"
PGSQL_PORT="5432"
PGSQL_DATABASE="postgres"
PGSQL_USERNAME="healthchkusr"
export PGPASSWORD="hc321"

TMP_FILE="/tmp/pgsqlchk.out"
ERR_FILE="/tmp/pgsqlchk.err"

# We perform a simple query that should return a few results
VALUE=\`\$PGBIN/psql -t -h \$PGSQL_HOST -U \$PGSQL_USERNAME -p \$PGSQL_PORT -d \$PGSQL_DATABASE -c "select pg_is_in_recovery()" 2> /dev/null\`
# Check the output. If it is not empty then everything is fine and we return something. Else, we just do not return anything.

if [ \$VALUE == "t" ]; then
    /bin/echo -e "HTTP/1.1 206 OK\r\n"
    /bin/echo -e "Content-Type: Content-Type: text/plain\r\n"
    /bin/echo "Standby"
elif [ \$VALUE == "f" ]; then
    /bin/echo -e "HTTP/1.1 200 OK\r\n"
    /bin/echo -e "Content-Type: Content-Type: text/plain\r\n"
    /bin/echo "Primary"
else
    /bin/echo -e "HTTP/1.1 503 Service Unavailable\r\n"
    /bin/echo -e "Content-Type: Content-Type: text/plain\r\n"
    /bin/echo "DB Down"
fi
EOF

chmod 755 /opt/pgsqlchk

yum install -y xinetd telnet

cat <<EOF >/etc/xinetd.d/pgsqlchk
service pgsqlchk
{
        flags           = REUSE
        socket_type     = stream
        port            = 23267
        wait            = no
        user            = nobody
        server          = /opt/pgsqlchk
        log_on_failure  += USERID
        disable         = no
        only_from       = 0.0.0.0/0
        per_source      = UNLIMITED
}
EOF

cat <<EOF >>/etc/services
pgsqlchk        23267/tcp           # pgsqlchk
EOF

systemctl start xinetd

/opt/pgsqlchk


### On all HAproxy nodes:
docker exec -it pg-haproxy-$(whoami)-node3 bash
docker exec -it pg-haproxy-$(whoami)-node4 bash

cat <<EOF >>/etc/hosts
172.28.0.2 pg0
172.28.0.3 pg1
172.28.0.4 pg2
172.28.0.5 haproxy1
172.28.0.6 haproxy2
EOF

## HAProxy section:

yum install -y haproxy postgresql

cat <<EOF >/etc/haproxy/haproxy.cfg
global
    maxconn 100

defaults
    log /dev/log local0
    log global
    mode tcp
    retries 2
    timeout client 30m
    timeout connect 4s
    timeout server 30m
    timeout check 5s

listen stats
    mode http
    bind *:7000
    stats enable
    stats uri /

listen ReadWrite
    bind *:5000
    option httpchk
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server pg0 pg0:5432 maxconn 100 check port 23267
    server pg1 pg1:5432 maxconn 100 check port 23267
    server pg2 pg2:5432 maxconn 100 check port 23267

listen ReadOnly
    bind *:5001
    option httpchk
    http-check expect status 206
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server pg0 pg0:5432 maxconn 100 check port 23267
    server pg1 pg1:5432 maxconn 100 check port 23267
    server pg2 pg2:5432 maxconn 100 check port 23267
EOF

systemctl start haproxy
journalctl -u haproxy -f

# Test connections through HAProxy:
PGPASSWORD='verysecretpassword1^' psql -h 127.0.0.1 -p 5000 -U postgres postgres -c "select inet_server_addr();"
PGPASSWORD='verysecretpassword1^' psql -h 127.0.0.1 -p 5001 -U postgres postgres -c "select inet_server_addr();"
PGPASSWORD='verysecretpassword1^' psql -h 127.0.0.1 -p 5001 -U postgres postgres -c "select inet_server_addr();"


## Keepalived section:

cat <<EOF >>/etc/hosts
172.28.0.2 pg0
172.28.0.3 pg1
172.28.0.4 pg2
172.28.0.5 haproxy1
172.28.0.6 haproxy2
EOF

yum -y install keepalived

# Select one different priority for each node:
haproxy_node_prio=100
haproxy_node_prio=50

cat <<EOF >/etc/keepalived/keepalived.conf
global_defs {
  # Keepalived process identifier
  lvs_id haproxyID1
}

# Script used to check if HAProxy is running
vrrp_script keepalived_check {
      script "killall -0 haproxy"
      interval 1
      timeout 5
      rise 3
      fall 3
}

# Virtual interface
# The priority specifies the order in which the assigned interface to take over in a failover
vrrp_instance VRRP_01 {
  state MASTER 
  interface eth0
  virtual_router_id 24
  # calculate on the WEIGHT for each node
  priority $haproxy_node_prio
  # The virtual ip address shared between the two loadbalancers
  virtual_ipaddress {
    172.28.0.200/16
  }
  track_script {
    keepalived_check
  }
}
EOF

systemctl start keepalived
journalctl -u keepalived -f 

