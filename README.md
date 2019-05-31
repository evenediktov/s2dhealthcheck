# s2dhealthcheck

This script is intended to be used as BPA against Storage Spaces Direct Clusters. Script checks the following configurations:

Tests against cluster(s):
1.	Check if dedicated cluster network is configured for SMB (scripts assumes cluster network name ends with  *-SMB )
2.	Check if cluster network is configured for cluster traffic 
3.	Check if cluster network is configured for Live Migration traffic 
4.	Check if correct subnet is configured for cluster network (script assumes that cluster network uses 192.168.100.0/24 subnet)
5.	Check if cloud witness is configured (script assumes Azure storage account is configured as witness)
6.	Check if cloud witness is online 
7.	Check that CSV balancer is disabled 
8.	Check that CSV cache is configured to 10GB
9.	Check if core cluster resources online 
10.	Check if cluster core network online 
11.	Check if cluster network interface online 
12.	Check if cluster nodes online 
13.	Check if CSV(s) online 
14.	Check if storage jobs are running 
15.	Check that S2D is enabled 
16.	Check that S2D Pool is healthy 
17.	Check that virtual disk(s) are healthy 
18.	Check that S2D fault domain (S2D node) is healthy 
19.	Check that all physical disks in S2D pool are healthy 

Tests against cluster node(s):
1.	Check if SMB bandwith limit is configured for Live Migration traffic 
2.	Check that MPIO windows feature is not installed 
3.	If Antivirus is TrendMicro OfficeScan we can check AV exclusons in the registry 
a.	Check that necessary extensions are excluded 
b.	Check that necessary folders are excluded 
c.	Check that necessary processes are excluded 
4.	Check that cluster uses SMB protocol for Live Migration 
5.	Check that cluster uses Kerberos authentication for Live Migration 
6.	Check that cluster uses 2 concurrent Live Migrations 
7.	Check that SCVMM WMI classes registered (script assumes S2D hosts are managed by SCVMM)
8.	Check that RMDA is enabled for physical NIC 
9.	Check that iWARP RDMA is configured for physical NIC (script assumes iWARP RDMA is used in S2D intercluster traffic)

