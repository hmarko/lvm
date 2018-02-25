#!/usr/bin/perl

use POSIX;
use JSON;

$server = $ARGV[0];
$svm = $ARGV[1];
$app = $ARGV[2];
$aggr = $ARGV[3];
$igroup = $ARGV[4];

$vgs = $ARGV[5];

$wwidprefix = '3600a0980';
$deviceprefix = '/dev/mapper/';
$pvcreateparams = '--dataalignment 4k';
$rescancmd="iscsiadm -m session --rescan";

$vol{'size'} = '100';
$vol{'max-autosize'} = '15t';
$vol{'autosize-grow-threshold-percent'} =  90;
$vol{'autosize-shrink-threshold-percent'} =  75;
$vol{'initial-size-factor'} = 2;
$vol{'initial-max-autosize-factor'} = 4;


$hak = '/root/netapp_linux_unified_host_utilities-7-1.x86_64.rpm';

$sshcmd = 'ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey ';
$sshcmdsvm = $sshcmd.' vsadmin@'.$svm.' ';
$sshcmdserver = $sshcmd.' '.$server.' ';

sub createmapping {

	@diskscan = `lvmdiskscan`;
	foreach my $line (@diskscan) {
		chomp $line;
		if ($line=~/$deviceprefix(\S+).+\[\s+([0-9]*\.[0-9]+|[0-9]+)\s+(\S+)\]\s+(LVM physical volume)/) {
			$pv{$1}{size} = $2;
			$pv{$1}{quantifier} = $3;
			$pv{$1}{configured} = 1;
		}
		if ($line=~/$deviceprefix(\S+).+\[\s+([0-9]*\.[0-9]+|[0-9]+)\s+(\S+)\]\s+$/) {
			$pv{$1}{size} = $2;
			$pv{$1}{quantifier} = $3;
			$pv{$1}{configured} = 0;	
		}
	}

	@diskscan = `pvs --units m`;
	foreach my $line (@diskscan) {
		chomp $line;
		if ($line=~/$deviceprefix(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+([0-9]*\.[0-9]+|[0-9]+)(\w+)\s+([0-9]*\.[0-9]+|[0-9]+)(\w+)/) {
			$pv{$1}{vg} = $2;
			$pv{$1}{vgsize} = $5;
			$pv{$1}{vgsizequantifer} = $6;
			$pv{$1}{vgfree} = $7;
			$pv{$1}{vgfreequatifier} = $8;
		}
	}
}

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

print "creating/modifing netapp volume and luns\n" ;

@pvdisplay = `$sshcmd $server pvdisplay -C -o pv_name,vg_name,pv_size --units g`;
foreach $inputvg (split(/,/,$vgs)) {
	foreach $line (@pvdisplay) {
		chomp $line;
		if ($line =~ /$deviceprefix(\S+)\s+(\S+)\s+([0-9]*\.[0-9]+|[0-9]+)(g|G)/) {
			$dev = $1;
			$vg = $2;
			if (not $dev =~/^cdotsan_/) {	
				#add 1g on the netapp luns
				$sizeg = floor($3) + 1;
				if ($vg eq $inputvg) {
					$vol{'total-pv-size'} += $sizeg;
					$vol{'vgs'}{$vg}{'lun-count'} += 1;
					$vol{'vgs'}{$vg}{'luns'}[$vol{'vgs'}{$vg}{'lun-count'}] = $sizeg;
				}
			}
		}
	}
	
	if (not $vol{'vgs'}{$inputvg}{'lun-count'}) {
		print "ERROR: could not identify PVs for VG: $inputvg\n";
		exit 1;
	}
}
$volume = $server.'_'.$app;

if ($vol{'total-pv-size'} * 2 > 100) {
	$vol{'initial-size'} = floor($vol{'total-pv-size'}) * $vol{'initial-size-factor'};
	$vol{'max-autosize'} = floor($vol{'total-pv-size'}) * $vol{'initial-max-autosize-factor'};
}

$cmd = "volume show -volume $volume -field state,type";
@out = `$sshcmdsvm $cmd`;

if ($out[2]=~/$svm\s+$volume\s+(\S+)\s+(\S+)/) {
	$state = $1;
	$type = $2;
	if ($state ne 'online' or $type ne 'RW') {
		print "ERROR: volume $volume exists on the SVM with state:$state type:$type\n";
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
			print "creating lun: $lunpath\n";
			$cmd = "lun create -path $lunpath -size $lunsize".'GB -ostype linux -space-reserve disable -space-allocation enabled';
			`$sshcmdsvm $cmd`;
		}

		$cmd = "lun show -path $lunpath -fields serial-hex";
		@luninfo = `$sshcmdsvm $cmd`;
		if ($luninfo[2] =~/$lunpath\s+(\S+)/) {
			$serial = $1;
			$vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'serial'} = $serial;
			$vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'lun-name'} = $vg.'_'.$lun;
			$vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'device-alias'} = 'cdotsan_'.$server.'_'.$vg.'_'.$lun;
			$vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'wwid'} = $wwidprefix .$serial;
		}		
		
		$mapped = 0;
		foreach $lun (@existinglunmappingss ) { 
			if ($lun=~/\S+\s+($lunpath)\s+(\S+)/) {
				$mappedigroup = $2;
				if ($mappedigroup ne $igroup) {
					print "ERROR: lun:$lunpath is already mapped to another igroup:$mappedigroup\n";
					exit 1;
				}
				$mapped =1;
			}
		}
		if (not $mapped) {
			print "mapping lun: $lunpath to igroup:$igroup\n";
			$cmd = "lun map -path $lunpath -igroup $igroup";
			`$sshcmdsvm $cmd`;
		}
		$found = 0;				
	}
}


$redhat = `$sshcmdserver cat /etc/redhat-release`;

$multipathconf = `$sshcmdserver cat /etc/multipath.conf`;

$addvendor = 1;
if ($multipathconf =~ /\s*vendor\s+\"NETAPP\"/) {
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
				$serial = $vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'serial'};
				$lunname = $vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'lun-name'};
				$devicealias = $vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'device-alias'};
				$wwid = $vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'wwid'};
				if (not $multipathconf =~ /\s*wwid\s+$wwid/ and not $multipathconf =~ /\s*alias\s+$devicealias/) {
					$newfile .= "\t".'multipath {'."\n";
					$newfile .= "\t\talias $devicealias\n";
					$newfile .= "\t\twwid $wwid\n";
					$newfile .= "\t".'}'."\n";
				}
			}
		}
		
	}
	
}

print "backing up and recreating /etc/multipath.conf\n";
`$sshcmdserver \" yes|cp -rf /etc/multipath.conf /etc/multipath.conf.orig\"`;
$mpfile = "/tmp/multipath_$server.tmp";
open (MPCONF,">$mpfile") || die "ERROR cannot open  $mpfile for writing\n";
print MPCONF "$newfile\n";
close(MPCONF);
$cmd = "scp $mpfile $server".':/etc/multipath.conf';
`$sshcmdserver $cmd`;

print "\nrescanning new devices\n";
`$sshcmdserver $rescancmd`;
#sleep 10;
print "\ncreating new dmultipath devices\n";
`$sshcmdserver multipath -r`;

print "\ncreating PV from new devices\n";
createmapping();
foreach $vg (keys %{$vol{'vgs'}}) {
	foreach $lunpath (keys %{$vol{'vgs'}{$vg}{'created-luns'}}) {
		$devicealias = $vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'device-alias'};
		if (not exists $pv{$devicealias}) {
			print "ERROR: multipath device $deviceprefix$devicealias could not be found\n";
			exit 1;
		} elsif (not $pv{$devicealias}{configured}) {
			print "creating pv:$devicealias :";
			@out = `$sshcmdserver pvcreate $pvcreateparams $deviceprefix$devicealias`;
			print "$out[0]";
		} else {
			print "pv:$devicealias already configured as pv\n";
		}
	}
}
createmapping();

print "\nextending VG based on new devices\n";
createmapping();
foreach $vg (keys %{$vol{'vgs'}}) {
	foreach $lunpath (keys %{$vol{'vgs'}{$vg}{'created-luns'}}) {
		$devicealias = $vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'device-alias'};
		if ($pv{$devicealias}{configured}) {
			if (not exists $pv{$devicealias}{vg}) {
				print "extending vg:$vg with pv:$deviceprefix$devicealias :";
				@out = `$sshcmdserver vgextend $vg $deviceprefix$devicealias`;
				print "$out[0]";
			} elsif ( $pv{$devicealias}{vg} ne $vg) {
				print "ERROR: pv:$devicealias is part of vg:$pv{$devicealias}{vg} while it should be part of vg:$vg\n";
				exit 1;
			} else {
				print "pv:$devicealias is already part of vg:$vg\n";
			}
		} else {
			print "ERROR: pv:$devicealias could not be created\n";
			exit 1;
		}
	}
}
createmapping();

my $pvjson = encode_json \%pv;
print " $pvjson\n";
