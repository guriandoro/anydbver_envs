anydbver --namespace=citus deploy \
node0 pg:latest \
node1 pg:latest \
node2 pg:latest \
node3 pg:latest 

# Check network address, if needed, to change pg_hba.conf rule
anydbver --namespace=citus exec node0 -- ip a

cat <<EOF >run_alters.sql
 alter system set wal_level = 'logical';
 alter system set listen_addresses = '*';
 alter system set ssl = 'on';
 show shared_preload_libraries;
 alter system set shared_preload_libraries = 'citus';
 create database db01;
EOF

cat <<EOF >run_citus.sh
 sudo -u postgres psql db01 -c "create extension citus";
EOF

cat <<EOF >run_setup.sh
echo -n "Running setup in: "
hostname
yum -y install citus_16.x86_64
sudo -u postgres psql < run_alters.sql
sed -i -e 's/local   all             all/hostssl all all 192.168.0.0\/8 trust\nlocal all all/' /var/lib/pgsql/16/data/pg_hba.conf
cd /var/lib/pgsql/16/data/
openssl req -nodes -new -x509 -keyout server.key -out server.crt -subj '/C=US/L=NYC/O=Percona/CN=postgres'
chmod 400 server.{crt,key}
chown postgres:postgres server.{crt,key}
systemctl restart postgresql-16
cd
bash /run_citus.sh
EOF

for node in node0 node1 node2 node3; do
  echo; echo "## Setup for" $node
  docker cp ./run_alters.sql citus-$(whoami|tr '.' '-')-$node:run_alters.sql
  docker cp ./run_citus.sh citus-$(whoami|tr '.' '-')-$node:run_citus.sh
  docker cp ./run_setup.sh citus-$(whoami|tr '.' '-')-$node:run_setup.sh
  anydbver --namespace=citus exec $node -- bash run_setup.sh
done

# On coordinator node only
# anydbver --namespace=citus exec node0
{
echo "SELECT citus_set_coordinator_host('node0', 5432);"
echo "SELECT citus_add_node('node1', 5432);"
echo "SELECT citus_add_node('node2', 5432);"
echo "SELECT citus_add_node('node3', 5432);"
echo "SELECT citus_get_active_worker_nodes();"
} | psql -Upostgres db01
