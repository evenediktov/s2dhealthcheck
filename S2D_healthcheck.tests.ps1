 [CmdletBinding()]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [Object[]]$clunodes,
        [Parameter(Mandatory=$True)]
        [Object[]]$clusters
    )
#Cluster tests
foreach ($cluster in $clusters) {
    Describe "[$cluster] configuration" {
        context "Failover Cluster configuration" {
            #Check if cluster network SMB and heartbeat traffic is configured correctly
            $LMnet = Invoke-Command -computername $cluster -scriptblock {Get-ClusterNetwork -Name *-SMB}
            It "SMB cluster network should exist" {
                $LMnet | should Belike "*SMB"
            }
            #Check if cluster network is configured for cluster traffic
            It "[$LMnet] cluster network should be configured for cluster traffic" {
                $LMnet.Role |  Should be "Cluster"
            }
            #Check if cluster network is configured for Live Migration traffic
            It "[$LMnet] cluster network should be configured for Live Migration" {
                Invoke-Command -computername $cluster -scriptblock {(Get-ItemProperty -Path “HKLM:\Cluster\ResourceTypes\Virtual Machine\Parameters” -Name MigrationNetworkOrder).MigrationNetworkOrder} | should be $LMnet.Id
            }
            #Check if correct subnet is configured for cluster network
	        It "[$LMnet] cluster network subnet should be 192.168.100.0" {
                $LMnet.Address | should be "192.168.100.0"
            }
            #Check if cloud witness is configured
            It "Cluster should use cloud witness" {
                (Invoke-Command -computername $cluster -scriptblock {(Get-ClusterQuorum).QuorumResource}).Name | Should Be "Cloud Witness"
            }
            #Check if cloud witness is online
            It "Cluster witness should be Online" {
                (Invoke-Command -computername $cluster -scriptblock {(Get-ClusterQuorum).QuorumResource.State}).Value | Should Be "Online"
            }
            #Check that CSV balancer is disabled
            It "CSV balancer should be disabled" {
                (Invoke-Command -computername $cluster -scriptblock {Get-Cluster}).CsvBalancer |  Should Be 0
            }
            #Check that CSV cache is configured
            It "CSV cache should be configured to 10GB" {
                (Invoke-Command -computername $cluster -scriptblock {Get-Cluster}).BlockCacheSize |  Should Be 10240
            }
            #Check if core cluster resources online
            $coreClusterResources = Invoke-Command -computername $cluster -ScriptBlock {
            Get-ClusterResource | Where-Object {$PSItem.OwnerGroup -eq 'Cluster Group'} | Select-Object -Property Name,State,OwnerGroup,ResourceType
            }
            if($coreClusterResources){
            foreach($ccResource in $coreClusterResources){
                IT "Verifying resource {$($ccResource.Name)} state is {Online}" {
                    $ccResource.State.Value | Should Be 'Online'
                }
            }
            }
            #Check if cluster core network online
            $coreNetworkResources = Invoke-Command -computername $cluster -ScriptBlock { Get-ClusterNetwork }
            if($coreNetworkResources){
                foreach($cnResource in $coreNetworkResources){ 
                    IT "Verifying network resource {$($cnResource.Name)} state is {UP}"{
                        $cnResource.State | Should Be 'Up'
                    }
                }
            }
            #Check if cluster network interface online
            $networkInterfaces = Invoke-Command -computername $cluster -ScriptBlock { Get-ClusterNetworkInterface }
            if($networkInterfaces) {
                foreach ($nInterface in $networkInterfaces){
                    IT "Verifying network interface {$($nInterface.Name)} from Node {$($nInterface.Node)} State is {Up}" {
                        $nInterface.State | Should Be 'Up'
                    }
                }
            }
            #Check if cluster nodes online
            $clusterNodes = Invoke-Command -computername $cluster -ScriptBlock { Get-ClusterNode }
            foreach($cNode in $clusterNodes){
                IT "Veryfing node {$($cNode.Name)} Status" { 
                    $cNode.State | Should Be 'Up'
                }
            }
            #Check if CSV(s) online
            $clusterSharedVolumes = Invoke-Command -computername $cluster -ScriptBlock {Get-ClusterSharedVolume}
            if($clusterSharedVolumes) {
                foreach ($csVolume in $clusterSharedVolumes){
                    IT "Verifying Volume {$($csVolume.Name)} State is {Online}" {
                        $csVolume.State | Should Be 'Online'
                    }
                }
            }
            #Check if storage jobs are running
            $storageJobs = Invoke-Command -computername $cluster -ScriptBlock { Get-StorageJob }
            IT "There should be no storageJobs running" {
                $storageJobs | Should Be $null
            }
            #Check that S2D is enabled
            It "Storage Spaces Direct should be Enabled" {
                Invoke-Command -computername $cluster -scriptblock {(Get-ClusterS2D -WarningAction Ignore).State} |  Should Be "Enabled"
            }
            #Check that S2D Pool is healthy
            It "S2D Pool should be healthy" {
                Invoke-Command -computername $cluster -scriptblock {(Get-StoragePool S2D*).HealthStatus} |  Should Be "Healthy"
            }
            #Check that virtual disk(s) are healthy
            $vdisks = Invoke-Command -computername $cluster -scriptblock {Get-VirtualDisk | select FriendlyName,HealthStatus}
            foreach ($vdisk in $vdisks) {
                $vdiskname = $vdisk.FriendlyName
	            It "Virtual Disk [$vdiskname] should be healthy" {
                    $vdisk.HealthStatus |  Should Be "Healthy"
                }
            }
            #Check that S2D fault domain (S2D node) is healthy
            $faultdomains = Invoke-Command -computername $cluster -scriptblock {Get-StorageFaultDomain -type StorageScaleUnit | select FriendlyName,HealthStatus}
                foreach ($faultdomain in $faultdomains){
                    IT "Verifying Fault Domain {$($faultdomain.FriendlyName)} health" {
                        $faultdomain.HealthStatus |  Should Be "Healthy"
                    }
                }
            #Check that all physical disks in S2D pool are healthy
            $unhealthydisks = Invoke-Command -computername $cluster -scriptblock {Get-PhysicalDisk | ? {$_.HealthStatus -ne "Healthy"} | select SerialNumber,HealthStatus}
            foreach ($unhealthydisk in $unhealthydisks) {
                $unhealthydisksn = $unhealthydisk.SerialNumber
	            It "Physical Disk [$unhealthydisksn] is not healthy" {
                    $unhealthydisk.HealthStatus |  Should Be "Healthy"
                    }
            }

        }        
        }
        }
#cluster nodes tests
foreach ($clunode in $clunodes) {
    Describe "[$clunode] S2D node configuration" {
        context "Windows OS configuration" { 
            #Check if SMB bandwith linmit is configured for Live Migration traffic
            $smbmw = Invoke-Command -computername $clunode -scriptblock {Get-WindowsFeature -Name FS-SMBBW}
            If ($smbmw.Installed -eq $true) {
                It "SMB Bandwidth Limit feature should be installed on the host" {
                    $smbmw.Installed |  Should Be $true
                }
	            It "SMB Bandwidth Limit for Live Migration SMB traffic should be set to 750MB" {
                    (Invoke-Command -computername $clunode -scriptblock {Get-SmbBandwidthLimit -Category LiveMigration}).BytesPerSecond |  Should Be 750MB
                }
            }
            else {
                It "SMB Bandwidth Limit feature should be installed on the host" {
		            $smbmw.Installed |  Should Be $true
                }
            }
            #Check that MPIO windows feature is not installed
            It "MPIO should not be installed" {
                Invoke-Command -computername $clunode -scriptblock {(Get-WindowsFeature Multipath-IO).Installed} |  Should Be $false
            }
        }
        #If Antivirus is TrendMicro OfficeScan we can check AV exclusons in the registry
        context "AV exclusions configuration" {
        $realtimeexclusions = Invoke-Command -computername $clunode -scriptblock {Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\TrendMicro\PC-cillinNTCorp\CurrentVersion\Real Time Scan Configuration'}
        #Check that necessary extensions are excluded
        $ExcludedExt = $realtimeexclusions.ExcludedExt.Split(",")
        $hvsextexcl = @(".vhd",".vhdx",".avhd",".avhdx",".vhds",".vhdpmem",".iso",".rct",".vsv",".bin",".vmcx",".vmrs",".vmgs",".hrl",".mrt")
        foreach ($hvsextexclitem in $hvsextexcl) {
            $hvsextexcltest = if ($hvsextexclitem -in ($ExcludedExt)){$hvsextexclitem} else {$null}
            It "[$hvsextexclitem] extension should be excluded from AV scan" {
                $hvsextexcltest | should be $hvsextexclitem
            }
        }
        #Check that necessary folders are excluded
        $ExcludedFolder = $realtimeexclusions.ExcludedFolder.Split("|")
        $hvsdirexcl = @("%ProgramData%\Microsoft\Windows\Hyper-V","%ProgramFiles%\Hyper-V","%Public%\Documents\Hyper-V\Virtual Hard Disks","%SystemDrive%\ProgramData\Microsoft\Windows\Hyper-V\Snapshots","C:\ClusterStorage","\Device\HarddiskVolume*","%Systemroot%\Cluster")
        foreach ($hvsdirexclitem in $hvsdirexcl) {
            $hvsdirexttest = if ($hvsdirexclitem -in ($ExcludedFolder)){$hvsdirexclitem} else {$null}
            It "[$hvsdirexclitem] folder should be excluded from AV scan" {
                $hvsdirexttest | should be $hvsdirexclitem
        }
        }
        #Check that necessary processes are excluded
        $ExcludedFile = $realtimeexclusions.ExcludedFile.Split("|")
        $hvsproxexcl =@("Vmms.exe","Vmwp.exe","Vmsp.exe","Vmcompute.exe","VmmAgent.exe","clussvc.exe","rhs.exe")
        foreach ($hvsproxexclitem in $hvsproxexcl) {
            $hvsprocetest = if ($hvsproxexclitem -in ($ExcludedFile)) {$hvsproxexclitem} else {$null}
            It "[$hvsproxexclitem] process should be excluded from AV scan" {
                $hvsprocetest | should be $hvsproxexclitem
            }
        }
        }
        context "Hyper-V configuration" { 
            #Check that cluster uses SMB protocol for Live Migration
            $vmhost = Invoke-Command -computername $clunode -scriptblock {Get-VMHost}
            It "Cluster should use SMB for Live Migration" {
                $vmhost.VirtualMachineMigrationPerformanceOption |  Should Be "SMB"
            }
            #Check that cluster uses Kerberos authentication for Live Migration
            It "Cluster should use Kerberos for Live Migration" {
                $vmhost.VirtualMachineMigrationAuthenticationType |  Should Be "Kerberos"
            }
            #Check that cluster uses 2 concurrent Live Migrations
            It "Cluster should use 2 concurrent Live Migration sesssions" {
                $vmhost.MaximumVirtualMachineMigrations |  Should Be 2
            }
            #Check that SCVMM WMI classes registered
            It "VMM WMI classes should be registered" {
                Invoke-Command -computername $clunode -scriptblock {Get-CimClass -Namespace root/virtualization/v2 -classname *vmm*} | Should Not BeNullOrEmpty
            }
        }

        context "RDMA configuration" {
            #Check that RMDA is enabled for pysical NIC
            $RDMApnics = Invoke-Command -computername $clunode -scriptblock {Get-NetAdapterRdma -InterfaceDescription HPE*}
            foreach ($RDMApnic in $RDMApnics) {
                $RDMApname = $RDMApnic.InterfaceDescription
                It "RMDA should be Enabled for [$RDMApname]" {
		        $RDMApnic.Enabled | Should Be $True
	            }
            }
            #Check that iWARP RDMA is configured for physical NIC
            $RDMAnicproperty = Invoke-Command -computername $clunode -scriptblock {Get-NetAdapterAdvancedProperty -InterfaceDescription HPE* -RegistryKeyword *NetworkDirectTechnology}
            if ($RDMAnicproperty -ne $null) {
                foreach ($RDMApnicprop in $RDMAnicproperty) {
                    $NICname = $RDMApnicprop.InterfaceDescription
                    It "iWARP RMDA should be configured for [$NICname]" {
		                $RDMApnicprop.DisplayValue | Should Be "iWARP"
                    }
                }
            }
            else {
                $RDMApnics = Invoke-Command -computername $clunode -scriptblock {Get-NetAdapterAdvancedProperty -InterfaceDescription HPE* -RegistryKeyword *RDMAmode}
                foreach ($RDMApnic in $RDMApnics) {
                    $RDMApnicname = $RDMApnic.InterfaceDescription
                    It "iWARP RMDA should be configured for [$RDMApnicname]" {
		                $RDMApnic.DisplayValue | Should Be "iWARP"
                    }
                }
            }
        }
    }
}
    
