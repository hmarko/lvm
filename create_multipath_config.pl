#!/usr/bin/perl

use POSIX;


$server = $ARGV[0];
$svm = $ARGV[1];
$app = $ARGV[2];
$aggr = $ARGV[3];
$igroup = $ARGV[4];

$vgs = $ARGV[5];

$wwidprefix = '3600a0980';

$vol{'size'} = '100';
$vol{'max-autosize'} = '15t';
$vol{'autosize-grow-threshold-percent'} =  90;
$vol{'autosize-shrink-threshold-percent'} =  75;


$hak = '/root/netapp_linux_unified_host_utilities-7-1.x86_64.rpm';

$sshcmd = 'ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey ';
$sshcmdsvm = $sshcmd.' vsadmin@'.$svm.' ';
$sshcmdserver = $sshcmd.' '.$server.' ';

$version = `$sshcmdserver uname -a`;
if (not $version=~/Linux/) {
	print "server $server is not Linux or couldnot be contacted using ssh public key\n";
	exit 1;
}

$version = `$sshcmdsvm version`;
if (not $version=~/NetApp/) {
	print "svm $svm is not cDOT SVM or couldnot be contacted using ssh public key\n";
	exit 1;
}

print "installing $hak on server\n";
$cmd = "scp $hak $server:$hak";
`$cmd`;

$cmd = "$sshcmdserver rpm -i $hak";
`$cmd`;

print "NetApp Creation script\n" ;

@pvdisplay = `$sshcmd $server pvdisplay -C -o pv_name,vg_name,pv_size --units g`;

foreach $inputvg (split(/,/,$vgs)) {
	foreach $line (@pvdisplay) {
		chomp $line;
		if ($line =~ /\/dev\/mapper\/(.\S+)\s+(\S+)\s+([0-9]*\.[0-9]+|[0-9]+)G/) {
			
			$dev = $1;
			if ($dev =~/^cdotsan_/) {
				print "ERROR: VG:$inputvg already contains NetApp PV:$dev\n";
				exit;
			}
			$vg = $2;
			#add 1g on the netapp luns
			$sizeg = floor($3) + 1;
			if ($vg eq $inputvg) {
				$vol{'total-pv-size'} += $sizeg;
				$vol{'vgs'}{$vg}{'lun-count'} += 1;
				$vol{'vgs'}{$vg}{'luns'}[$vol{'vgs'}{$vg}{'lun-count'}] = $sizeg;
			}
		}
	}
	
	if (not $vol{'vgs'}{$inputvg}{'lun-count'}) {
		print "ERROR: couldnt identify PVs for VG: $inputvg\n";
		exit 1;
	}
}
$volume = $server.'_'.$app;

if ($vol{'total-pv-size'} * 2 > 100) {
	$vol{'initial-size'} = floor($vol{'total-pv-size'}) * 2;
	$vol{'max-autosize'} = floor($vol{'total-pv-size'}) * 4;
}

$cmd = "volume show -volume $volume -field state,type";
@out = `$sshcmdsvm $cmd`;

if ($out[2]=~/$svm\s+$volume\s+(\S+)\s+(\S+)/) {
	$state = $1;
	$type = $2;
	if ($state ne 'online' or $type ne 'RW') {
		print "ERROR: Volume $volume already exists on the SVM with state:$state type:$type\n";
		exit 1;
	}
	$cmd = "volume modify -volume $volume -size $vol{'initial-size'}g -space-guarantee none -percent-snapshot-space 0 -autosize-mode grow-shrink -max-autosize $vol{'max-autosize'}g -min-autosize $vol{'initial-size'}g -autosize-grow-threshold-percent $vol{'autosize-grow-threshold-percent'}  -autosize-shrink-threshold-percent $vol{'autosize-shrink-threshold-percent'}";
} else {

	$cmd = "volume create -volume $volume -aggregate $aggr -size $vol{'initial-size'}g -space-guarantee none -percent-snapshot-space 0 -autosize-mode grow-shrink -max-autosize $vol{'max-autosize'}g -min-autosize $vol{'initial-size'}g -autosize-grow-threshold-percent $vol{'autosize-grow-threshold-percent'}  -autosize-shrink-threshold-percent $vol{'autosize-shrink-threshold-percent'}";
}

#create/modify the volume 
@out = `$sshcmdsvm $cmd`;
print @out;

@existingluns = `$sshcmdsvm \"set -units gb;lun show -fields path,size,state,mapped -volume $volume\"`;
@existinglunmappingss = `$sshcmdsvm lun mapping show -volume $volume -fields path,igroup`;

@igroup = `$sshcmdsvm igroup show $igroup -fields initiator`;

if (not $igroup[2] =~ /\s+($igroup)\s+/) {
	print "ERROR: igroup:$igroup does not exists\n";
	exit 1;
}

foreach $vg (keys %{$vol{'vgs'}}) {
	for ($lun=1;$lun <= $vol{'vgs'}{$vg}{'lun-count'};$lun++) {
		$lunpath = '/vol/'.$volume.'/'.$vg.'_'.$lun;
		$lunsize = $vol{'vgs'}{$vg}{'luns'}[$lun];
		
		print "creating lun: $lunpath\n";
		$found = 0;
		foreach $lun (@existingluns ) {
			if ($lun =~/^(\S+)\s+($lunpath)\s+(\d+)GB\s+(\S+)/) {
				$size = $3.'GB';
				$state = $4;
				print "WARNING: lun $lunpath already exists on this volume with size:$size state:$state\n";
				$found = 1;
			}
		}
		if (not $found) {
			$cmd = "lun create -path $lunpath -size $lunsize".'GB -ostype linux -space-reserve disable -space-allocation enabled';
			`$sshcmdsvm $cmd`;
		}

		$cmd = "lun show -path $lunpath -fields serial-hex";
		@luninfo = `$sshcmdsvm $cmd`;
		if ($luninfo[2] =~/$lunpath\s+(\S+)/) {
			$serial = $1;
			$vol{'vgs'}{$vg}{'created-luns'}{$lunpath} = $serial;
		}		

		foreach $lun (@existinglunmappingss ) { 
			if ($lun=~/\S+\s+($lunpath)\s+(\S+)/) {
				$mappedigroup = $2;
			}
				
			print "mapping lun: $lunpath to igroup:$igroup\n";
			$found = 0;		
	}
}


$redhat = `$sshcmdserver cat /etc/redhat-release`;

$multipathconf = `$sshcmdserver cat /etc/multipath.conf`;

$addvendor = 1;
if ($multipathconf =~ /^\s*vendor\s+ \"NETAPP\"/) {
	$addvendor = 0;
}

$newfile = '';
foreach $line (split(/\n/,$multipathconf)) {
	$newfile .= "$line\n";
	
	chomp $line;
	if ($line =~ /^\s*devices\s*\{\s*$/ and $addvendor) {
		$addvendor = 0;
		$newfile .= << 'END_TEXT'
	device {
		vendor "NETAPP"
		product "LUN"
		path_grouping_policy group_by_prio
		features "3 queue_if_no_path pg_init_retries 50"
		prio_callout "/sbin/mpath_prio_alua /dev/%n"
		path_checker tur
		path_selector "round-robin 0"
		failback immediate
		hardware_handler "1 alua"
		rr_weight uniform
		rr_min_io 128
		getuid_callout "/sbin/scsi_id -g -u -s /block/%n"
	}
END_TEXT
	}
	if ($line =~ /^\s*multipaths\s*\{\s*$/) {
		
		foreach $vg (keys %{$vol{'vgs'}}) {
			foreach $lunpath (keys %{$vol{'vgs'}{$vg}{'created-luns'}}) {
				$serial = $vol{'vgs'}{$vg}{'created-luns'}{$lunpath };
				print "$lunpath  $serial\n";
			}
		}
		
	}
	
}


exit ;

open(SL, "sanlun lun show -p|");

$svm = '';
$lunpath = '';

while (<SL>) {
  chomp ;
  $line = $_;
  if ($line =~ /^\s+ONTAP Path: (\S+):(\/vol\/\S+)/) {
	$svm = $1;
	$lunpath = $2;
  }
  if ($line =~ /^\s+Host Device: (\S+)\((\w+)\)/) {
	$mpath = $1;
	$wwid = $2;
	@ln = split(/\//,$lunpath);
	$newmapth = ($ln[4]=~/\S/) ? $ln[2].'_'.$ln[3].'_'.$ln[4] : $ln[2].'_'.$ln[3]; 
	print '# lunpath:'.$svm.':'.$lunpath."\n";
	print "$newmapth $wwid\n"; 
	$svm = ''; $newlunpath= '';
  }
}

close(SL);
