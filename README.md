# Outline
1. Create a 3 nodes cluster, with one datacenter 
each of the nodes in a different rack , dc:north, racks north1, north2, north3
2. Create a keyspace with 3 tables, one of the tables using STCS, another LCS, another TWCS.
3. Insert 10,000 records in each of the tables, using loop and cqlsh.
4. In the TWCS table, when creating the table and inserting data use time-window 30 minutes and the data to expire with 1 hour TTL
5. Add a DC with 3 more nodes , each of the nodes in a different rack, dc: south, racks south1, south2, south3
6. Install Scylla Manager
7. Run repair using Scylla manager
8. Decommission the old DC, keeping only the new created DC
9. Add a node, decommission a node
10. Then kill one of the nodes, destroy one of the containers (kill the seed node)
11. Replace procedure to replace this node we've killed

# 1. Create a 3 nodes cluster, with one datacenter 
``` 
$ ./1-create_north_cluster 
a7ee5815978e3803ee81ae3be04bcb85a19e2d068df975ac2dcffbc7a438e33e
Node1 IP is: 172.17.0.2
04c71db660887cffa4640a240a14089dece5352bb7b5dd99bf481db3cb6029fc
b7a65d9bc5710f9fb50f19b90a7e63a22bcbbbeac617c314aa92f4f3cc41bb30
felipemendes@skywalker:~/scylla-enterprise$ docker exec node1 nodetool status
Datacenter: north
=================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens       Owns    Host ID                               Rack
UN  172.17.0.3  91.32 KB   256          ?       c45b8584-3540-4238-98d3-a978ded5dd26  north2
UN  172.17.0.2  92.01 KB   256          ?       0a0147f2-12b5-4e3c-bf7d-550b5aae885a  north1
UN  172.17.0.4  96.34 KB   256          ?       c772ce33-4746-41b7-b67b-db6baf3ee31c  north3

Note: Non-system keyspaces don't have the same replication settings, effective ownership information is meaningless
```

### 2. Create a keyspace with 3 tables, one of the tables using STCS, another LCS, another TWCS.
### 3. Insert 10,000 records in each of the tables, using loop and cqlsh.
### 4. In the TWCS table, when creating the table and inserting data use time-window 30 minutes and the data to expire with 1 hour TTL
```
$ ./2-feed.sh 
Displaying count for mykeyspace.stcs_table: 

 count
-------
 10000

(1 rows)
Displaying count for mykeyspace.lcs_table: 

 count
-------
 10000

(1 rows)
Displaying count for mykeyspace.twcs_table: 

 count
-------
 10000

(1 rows)
```
# 5. Add a DC with 3 more nodes , each of the nodes in a different rack, dc: south, racks south1, south2, south3
```
$ ./3-create_south_cluster 
f36f8bf1655578c06570600adf2bb1e45cf3df816e755477d9a7b1b34f1bef7b
South1 IP is: 172.17.0.5
cdf92ec34b13210d26b1b2c4888a7957f80e5a34a67d29ac75655d336d30a49c
aca96061981f5e99dae7ea176abce98c1f85358ac1908681b4c6870450b727e3

$ docker exec node1 nodetool status
Datacenter: north
=================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens       Owns    Host ID                               Rack
UN  172.17.0.3  103.67 KB  256          ?       8e0f6d64-252b-4eac-b49e-7740749ff6c8  north2
UN  172.17.0.2  98.72 KB   256          ?       8366b2fe-6484-4759-9fd4-cd9a41ffc607  north1
UN  172.17.0.4  103.71 KB  256          ?       b1669c8c-4697-40a3-b657-b34580f70937  north3
Datacenter: south
=================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens       Owns    Host ID                               Rack
UN  172.17.0.5  97.98 KB   256          ?       2a689861-1f54-4c29-b199-44d84a0bf3af  south1
UN  172.17.0.7  ?          256          ?       6f3decf0-ee24-49e0-8b36-14dd209f6a55  south3
UN  172.17.0.6  107.56 KB  256          ?       1628f3c5-02ec-4d73-96a5-1b163f513913  south2

Note: Non-system keyspaces don't have the same replication settings, effective ownership information is meaningless
```
Update keyspaces, rebuild and repair
```
$ ./4-update_keyspaces_for_south 

CREATE KEYSPACE mykeyspace WITH replication = {'class': 'NetworkTopologyStrategy', 'north': '3', 'south': '3'}  AND durable_writes = true;
CREATE KEYSPACE system_auth WITH replication = {'class': 'NetworkTopologyStrategy', 'north': '3', 'south': '3'}  AND durable_writes = true;
CREATE KEYSPACE system_distributed WITH replication = {'class': 'NetworkTopologyStrategy', 'north': '3', 'south': '3'}  AND durable_writes = true;
CREATE KEYSPACE system_traces WITH replication = {'class': 'NetworkTopologyStrategy', 'north': '3', 'south': '3'}  AND durable_writes = true;

Executing nodetool rebuild
Running a full cluster repair
[2021-05-08 16:32:11,427] Starting repair command #4, repairing 1 ranges for keyspace mykeyspace (parallelism=SEQUENTIAL, full=true)
[2021-05-08 16:32:43,531] Repair session 4 
[2021-05-08 16:32:43,531] Repair session 4 finished
[2021-05-08 16:32:43,544] Starting repair command #5, repairing 1 ranges for keyspace system_auth (parallelism=SEQUENTIAL, full=true)
[2021-05-08 16:32:45,646] Repair session 5 
[2021-05-08 16:32:45,646] Repair session 5 finished
[2021-05-08 16:32:45,654] Starting repair command #6, repairing 1 ranges for keyspace system_traces (parallelism=SEQUENTIAL, full=true)
[2021-05-08 16:32:48,756] Repair session 6 
[2021-05-08 16:32:48,756] Repair session 6 finished
(...)
```
Update seed nodes and do a rolling restart
```
$ ./5-update_seeds 
node1: 
SCYLLA_DOCKER_ARGS="--memory 800M --smp 1 --listen-address 172.17.0.2 --rpc-address 172.17.0.2 --seed-provider-parameters seeds=172.17.0.2,172.17.0.5 999999999"
node2: 
SCYLLA_DOCKER_ARGS="--memory 800M --smp 1 --listen-address 172.17.0.3 --rpc-address 172.17.0.3 --seed-provider-parameters seeds=172.17.0.2,172.17.0.5 999999999"
node3: 
SCYLLA_DOCKER_ARGS="--memory 800M --smp 1 --listen-address 172.17.0.4 --rpc-address 172.17.0.4 --seed-provider-parameters seeds=172.17.0.2,172.17.0.5 999999999"
south1: 
SCYLLA_DOCKER_ARGS="--memory 800M --smp 1 --listen-address 172.17.0.5 --rpc-address 172.17.0.5 --seed-provider-parameters seeds=172.17.0.2,172.17.0.5 999999999"
south2: 
SCYLLA_DOCKER_ARGS="--memory 800M --smp 1 --listen-address 172.17.0.6 --rpc-address 172.17.0.6 --seed-provider-parameters seeds=172.17.0.2,172.17.0.5 999999999"
south3: 
SCYLLA_DOCKER_ARGS="--memory 800M --smp 1 --listen-address 172.17.0.7 --rpc-address 172.17.0.7 --seed-provider-parameters seeds=172.17.0.2,172.17.0.5 999999999"
Restarting cluster, this will wait 30 seconds for EACH node. Grab a coffee :-)
node1
node1
node2
node2
node3
node3
south1
south1
south2
south2
south3
south3
$ docker exec node1 nodetool status
Datacenter: north
=================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens       Owns    Host ID                               Rack
UN  172.17.0.3  1.23 MB    256          ?       75d57fde-af6b-46eb-8764-8a10a90b6b15  north2
UN  172.17.0.2  1.23 MB    256          ?       3cf930bc-9709-4dad-ae2f-6060f00dbe05  north1
UN  172.17.0.4  1.23 MB    256          ?       db6e0a8d-cee1-443d-8f3c-804354c24777  north3
Datacenter: south
=================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens       Owns    Host ID                               Rack
UN  172.17.0.5  1.38 MB    256          ?       01c87838-1d34-4c5e-9e41-f008d60d85bf  south1
UN  172.17.0.7  1.38 MB    256          ?       7504d9c0-89d3-4254-a2d9-5f62babc4f1a  south3
UN  172.17.0.6  1.39 MB    256          ?       fbb8b399-30f1-46b6-93dd-c1079384354f  south2

Note: Non-system keyspaces don't have the same replication settings, effective ownership information is meaningless
```

# 6. Install Scylla Manager
```
$ docker-compose up -d 
Creating scylla-manager-db ... done
Creating scylla-manager    ... done

$ ./6-install_and_configure_scyllamgr_nodes 
Installing scylla-manager-agent
Setting-up token pdlz69fjKZm3uZMjje1zbxl2xkHPOaABfFdTYONon9grwsNv2VEhEKoLpgMa4rt05oUn9waIH1XSpUtJbzQfCY686TU371euXxActA1h2PsLClpXfENAW8QHgfqZK261 on all nodes:
auth_token: pdlz69fjKZm3uZMjje1zbxl2xkHPOaABfFdTYONon9grwsNv2VEhEKoLpgMa4rt05oUn9waIH1XSpUtJbzQfCY686TU371euXxActA1h2PsLClpXfENAW8QHgfqZK261
auth_token: pdlz69fjKZm3uZMjje1zbxl2xkHPOaABfFdTYONon9grwsNv2VEhEKoLpgMa4rt05oUn9waIH1XSpUtJbzQfCY686TU371euXxActA1h2PsLClpXfENAW8QHgfqZK261
auth_token: pdlz69fjKZm3uZMjje1zbxl2xkHPOaABfFdTYONon9grwsNv2VEhEKoLpgMa4rt05oUn9waIH1XSpUtJbzQfCY686TU371euXxActA1h2PsLClpXfENAW8QHgfqZK261
auth_token: pdlz69fjKZm3uZMjje1zbxl2xkHPOaABfFdTYONon9grwsNv2VEhEKoLpgMa4rt05oUn9waIH1XSpUtJbzQfCY686TU371euXxActA1h2PsLClpXfENAW8QHgfqZK261
auth_token: pdlz69fjKZm3uZMjje1zbxl2xkHPOaABfFdTYONon9grwsNv2VEhEKoLpgMa4rt05oUn9waIH1XSpUtJbzQfCY686TU371euXxActA1h2PsLClpXfENAW8QHgfqZK261
auth_token: pdlz69fjKZm3uZMjje1zbxl2xkHPOaABfFdTYONon9grwsNv2VEhEKoLpgMa4rt05oUn9waIH1XSpUtJbzQfCY686TU371euXxActA1h2PsLClpXfENAW8QHgfqZK261
Starting Scylla Manager agent on all nodes:
Add cluster to Scylla Manager
5f5322fd-42b9-446d-bef4-74e61021710e
 __  
/  \     Cluster added! You can set it as default, by exporting its name or ID as env variable:
@  @     $ export SCYLLA_MANAGER_CLUSTER=5f5322fd-42b9-446d-bef4-74e61021710e
|  |     $ export SCYLLA_MANAGER_CLUSTER=docker-cluster
|| |/    
|| ||    Now run:
|\_/|    $ sctool status -c docker-cluster
\___/    $ sctool task list -c docker-cluster

$ docker exec scylla-manager sctool status -c docker-cluster
Datacenter: north
+----+----------+----------+------------+------------+------+----------+----------+-------+--------------------------------------+
|    | CQL      | REST     | Address    | Uptime     | CPUs | Memory   | Scylla   | Agent | Host ID                              |
+----+----------+----------+------------+------------+------+----------+----------+-------+--------------------------------------+
| UN | UP (0ms) | UP (1ms) | 172.17.0.2 | 101h35m56s | 12   | 15.35GiB | 2020.1.7 | 2.3.0 | bf3b52e5-e73a-4742-b5e3-b69f65bab1c7 |
| UN | UP (0ms) | UP (1ms) | 172.17.0.3 | 101h35m56s | 12   | 15.35GiB | 2020.1.7 | 2.3.0 | 4e221abc-a467-4182-b04c-20632b266eb8 |
| UN | UP (1ms) | UP (1ms) | 172.17.0.4 | 101h35m56s | 12   | 15.35GiB | 2020.1.7 | 2.3.0 | 04ded3fc-e206-4d8a-b455-6a07f0778339 |
+----+----------+----------+------------+------------+------+----------+----------+-------+--------------------------------------+
Datacenter: south
+----+----------+----------+------------+------------+------+----------+----------+-------+--------------------------------------+
|    | CQL      | REST     | Address    | Uptime     | CPUs | Memory   | Scylla   | Agent | Host ID                              |
+----+----------+----------+------------+------------+------+----------+----------+-------+--------------------------------------+
| UN | UP (0ms) | UP (1ms) | 172.17.0.5 | 101h35m56s | 12   | 15.35GiB | 2020.1.7 | 2.3.0 | 937f8ddc-2eeb-4a67-b0ce-464efaf09804 |
| UN | UP (1ms) | UP (1ms) | 172.17.0.6 | 101h35m56s | 12   | 15.35GiB | 2020.1.7 | 2.3.0 | 542cfeff-872e-4f44-85b9-70b0d0c55ceb |
| UN | UP (1ms) | UP (1ms) | 172.17.0.7 | 101h35m56s | 12   | 15.35GiB | 2020.1.7 | 2.3.0 | bd2fac50-64c8-4792-989a-fe3e505695af |
+----+----------+----------+------------+------------+------+----------+----------+-------+--------------------------------------+
```
# 7. Run repair using Scylla manager
```
$ docker exec scylla-manager sctool repair -c docker-cluster 
repair/756db8d8-16a8-4da7-9529-5a97c0e16614
$ docker exec scylla-manager sctool task progress repair/756db8d8-16a8-4da7-9529-5a97c0e16614 -c docker-cluster 
Status:		RUNNING
Start time:	08 May 21 17:42:11 UTC
Duration:	20s
Progress:	40%
Intensity:	1
Parallel:	0
Datacenters:	
  - north
  - south

+--------------------+--------------------------+----------+----------+
| Keyspace           |                    Table | Progress | Duration |
+--------------------+--------------------------+----------+----------+
| mykeyspace         |                lcs_table | 0%       | 0s       |
| mykeyspace         |               stcs_table | 0%       | 0s       |
| mykeyspace         |               twcs_table | 0%       | 0s       |
+--------------------+--------------------------+----------+----------+
| system_auth        |          role_attributes | 100%     | 2s       |
| system_auth        |             role_members | 100%     | 2s       |
| system_auth        |                    roles | 100%     | 2s       |
+--------------------+--------------------------+----------+----------+
| system_distributed |          cdc_description | 0%       | 1s       |
| system_distributed | cdc_topology_description | 100%     | 2s       |
| system_distributed |           service_levels | 100%     | 3s       |
| system_distributed |        view_build_status | 100%     | 2s       |
+--------------------+--------------------------+----------+----------+
| system_traces      |                   events | 0%       | 0s       |
| system_traces      |            node_slow_log | 0%       | 0s       |
| system_traces      |   node_slow_log_time_idx | 0%       | 0s       |
| system_traces      |                 sessions | 0%       | 0s       |
| system_traces      |        sessions_time_idx | 0%       | 0s       |
+--------------------+--------------------------+----------+----------+
```
# 8. Decommission the old DC, keeping only the new created DC
Run repair, update keyspaces and decomission:
```
./7-decomission-north 
Running nodetool repair
[2021-05-08 17:51:12,307] Starting repair command #1, repairing 1 ranges for keyspace mykeyspace (parallelism=SEQUENTIAL, full=true)
[2021-05-08 17:51:15,405] Repair session 1 
[2021-05-08 17:51:15,405] Repair session 1 finished
[2021-05-08 17:51:15,416] Starting repair command #2, repairing 1 ranges for keyspace system_auth (parallelism=SEQUENTIAL, full=true)
[2021-05-08 17:51:17,517] Repair session 2 
[2021-05-08 17:51:17,517] Repair session 2 finished
[2021-05-08 17:51:17,527] Starting repair command #3, repairing 1 ranges for keyspace system_traces (parallelism=SEQUENTIAL, full=true)
[2021-05-08 17:51:20,628] Repair session 3 
[2021-05-08 17:51:20,628] Repair session 3 finished
[2021-05-08 17:51:22,165] Starting repair command #1, repairing 1 ranges for keyspace mykeyspace (parallelism=SEQUENTIAL, full=true)
[2021-05-08 17:51:25,262] Repair session 1 
[2021-05-08 17:51:25,262] Repair session 1 finished
[2021-05-08 17:51:25,274] Starting repair command #2, repairing 1 ranges for keyspace system_auth (parallelism=SEQUENTIAL, full=true)
[2021-05-08 17:51:27,379] Repair session 2 
[2021-05-08 17:51:27,379] Repair session 2 finished
[2021-05-08 17:51:27,390] Starting repair command #3, repairing 1 ranges for keyspace system_traces (parallelism=SEQUENTIAL, full=true)
[2021-05-08 17:51:30,493] Repair session 3 
[2021-05-08 17:51:30,493] Repair session 3 finished
[2021-05-08 17:51:31,991] Starting repair command #1, repairing 1 ranges for keyspace mykeyspace (parallelism=SEQUENTIAL, full=true)
[2021-05-08 17:51:35,089] Repair session 1 
[2021-05-08 17:51:35,089] Repair session 1 finished
[2021-05-08 17:51:35,101] Starting repair command #2, repairing 1 ranges for keyspace system_auth (parallelism=SEQUENTIAL, full=true)
[2021-05-08 17:51:37,202] Repair session 2 
[2021-05-08 17:51:37,203] Repair session 2 finished
[2021-05-08 17:51:37,215] Starting repair command #3, repairing 1 ranges for keyspace system_traces (parallelism=SEQUENTIAL, full=true)
[2021-05-08 17:51:40,316] Repair session 3 
[2021-05-08 17:51:40,316] Repair session 3 finished
Update keyspaces
CREATE KEYSPACE mykeyspace WITH replication = {'class': 'NetworkTopologyStrategy', 'south': '3'}  AND durable_writes = true;
CREATE KEYSPACE system_auth WITH replication = {'class': 'NetworkTopologyStrategy', 'south': '3'}  AND durable_writes = true;
CREATE KEYSPACE system_distributed WITH replication = {'class': 'NetworkTopologyStrategy', 'south': '3'}  AND durable_writes = true;
CREATE KEYSPACE system_traces WITH replication = {'class': 'NetworkTopologyStrategy', 'south': '3'}  AND durable_writes = true;
Decomissioning nodes
Datacenter: south
=================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens       Owns    Host ID                               Rack
UN  172.17.0.5  1.37 MB    256          ?       937f8ddc-2eeb-4a67-b0ce-464efaf09804  south1
UN  172.17.0.7  1.37 MB    256          ?       bd2fac50-64c8-4792-989a-fe3e505695af  south3
UN  172.17.0.6  1.36 MB    256          ?       542cfeff-872e-4f44-85b9-70b0d0c55ceb  south2

Note: Non-system keyspaces don't have the same replication settings, effective ownership information is meaningless
```
# 9. Add a node, decommission a node
```
$ ./8-add_decommission_node 
05a307965d7cf11d22706faaec7afe7d1e0c38c5779487db7e363a5dc0301b8d
Sleeping for 2 minutes so it can finish joining the cluster
Running nodetool cleanup on all, but the newly added node.
Decommissioning south2 node (not a seed)
Display final cluster status: 
Datacenter: south
=================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address      Load       Tokens       Owns    Host ID                               Rack
UN  172.17.0.5   1.37 MB    256          ?       937f8ddc-2eeb-4a67-b0ce-464efaf09804  south1
UN  172.17.0.7   1.37 MB    256          ?       bd2fac50-64c8-4792-989a-fe3e505695af  south3
UN  172.17.0.10  1.85 MB    256          ?       330f3cd5-8c9a-469b-aa3e-b73bb9f82d78  south2

Note: Non-system keyspaces don't have the same replication settings, effective ownership information is meaningless
```
### 10. Then kill one of the nodes, destroy one of the containers (kill the seed node)
### 11. Replace procedure to replace this node we've killed
```
$ ./9-kill_and_replace_seed 
Kill seed node (south1)
south1
Spin up new seed node south5 :
5192b485a76c7b65902ad39aacfea92cc49b081975ee083a9c39e5f49d17b5e2
Update south3 and south4 seed node list and restart: 
south4: 
SCYLLA_DOCKER_ARGS="--memory 800M --smp 1 --listen-address 172.17.0.2 --rpc-address 172.17.0.2 --seed-provider-parameters seeds=172.17.0.3 999999999"
south4 restart
scylla: stopped
scylla: started
south3: 
SCYLLA_DOCKER_ARGS="--memory 800M --smp 1 --listen-address 172.17.0.7 --rpc-address 172.17.0.7 --seed-provider-parameters seeds=172.17.0.3 999999999"
south3 restart
scylla: stopped
scylla: started

$ docker exec south5 nodetool status
Datacenter: south
=================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens       Owns    Host ID                               Rack
UN  172.17.0.3  92.22 KB   256          ?       dddd4cdc-a34b-44d2-ad18-676e7721e2c7  south1
UN  172.17.0.2  1.23 MB    256          ?       2d9ef49c-698b-4174-8c57-790e74ae2fd2  south2
UN  172.17.0.4  1.39 MB    256          ?       ca54505c-8a24-41b4-b7df-2dcfd38cd2fa  south3

Note: Non-system keyspaces don't have the same replication settings, effective ownership information is meaningless
```
