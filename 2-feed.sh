#!/bin/bash

# Dummy script to feed N entries to Scylla
# 
# Adjust as needed.
#
ENTRIES=10000
KEYSPACE="mykeyspace"
CQLSH_HOST="172.17.0.2"

export CQLSH_HOST

# Keyspace & Tables creation

cqlsh -e "CREATE KEYSPACE $KEYSPACE WITH replication = {'class': 'NetworkTopologyStrategy', 'north': '3'};"

cqlsh -e "CREATE TABLE ${KEYSPACE}.stcs_table ( id int, col1 int, col2 int, col3 int, PRIMARY KEY(id)) WITH compaction = {'class': 'SizeTieredCompactionStrategy'};"
cqlsh -e "CREATE TABLE ${KEYSPACE}.lcs_table ( id int, col1 int, col2 int, col3 int, PRIMARY KEY(id)) WITH compaction = {'class': 'LeveledCompactionStrategy', 'sstable_size_in_mb': 30};"
cqlsh -e "CREATE TABLE ${KEYSPACE}.twcs_table ( id int, col1 int, col2 int, col3 int, PRIMARY KEY(id)) WITH compaction = {'class': 'TimeWindowCompactionStrategy', 'compaction_window_unit': 'MINUTES', 'compaction_window_size': 30} AND default_time_to_live = 3600;"

# Feed.

for i in stcs_table lcs_table twcs_table; do

   > ${i}.cql

   for x in $(seq 1 ${ENTRIES}); do
     if [ "$i" == "twcs_table" ]; then
	     echo "INSERT INTO ${KEYSPACE}.${i} (id,col1,col2,col3) VALUES ($x,$RANDOM,$RANDOM,$RANDOM) USING TTL 3600;" >> ${i}.cql
     else
	     echo "INSERT INTO ${KEYSPACE}.${i} (id,col1,col2,col3) VALUES ($x,$RANDOM,$RANDOM,$RANDOM);" >> ${i}.cql
     fi
   done

   cqlsh -f ${i}.cql

   echo "Displaying count for ${KEYSPACE}.${i}: "
   cqlsh -e "SELECT COUNT(*) FROM ${KEYSPACE}.${i};"
done
