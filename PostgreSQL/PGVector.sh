#!/bin/bash

anydbver --namespace=pgvector deploy node0 pg:16

anydbver --namespace=pgvector exec node0 <<EOF
yum install -q -y pgvector_16 && echo "Installation: OK" || echo "Installation: Not OK"
psql -c "CREATE DATABASE db01"
{
echo "CREATE EXTENSION vector;"
echo "\dx;"
echo "CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));"
echo "INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');"
echo "SELECT * FROM items ORDER BY embedding <-> '[3,1,2]';"
} | psql db01
EOF

anydbver --namespace=pgvector exec node0
