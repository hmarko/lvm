#!/usr/bin/perl

use POSIX;
#use JSON;
use Data::Dumper;

$server = $ARGV[0];
$svm = $ARGV[1];
$app = $ARGV[2];
$aggr = $ARGV[3];
$igroup = $ARGV[4];
$vgs = $ARGV[5];
$drsvm = $ARGV[6];
$draggr = $ARGV[7];
$drsched = $ARGV[8];

$wwidprefix = '3600a0980';
$deviceprefix = '/dev/mapper/';
$pvcreateparams = '--dataalignment 4k';
#$rescancmd1="iscsiadm -m session --rescan";
$rescancmd1="echo \"- - -\" > /sys/class/scsi_host/host0/scan";
$rescancmd2="echo \"- - -\" > /sys/class/scsi_host/host1/scan";
$rescancmd3="echo \"- - -\" > /sys/class/scsi_host/host2/scan";
$rescancmd4="echo \"- - -\" > /sys/class/scsi_host/host3/scan";
$newdevprefix = 'cdotsan_';
$oldlvolsuffix = '_old_to_delete_XIV';

$vol{'size'} = '100';
$vol{'max-autosize'} = '15t';
$vol{'autosize-grow-threshold-percent'} =  90;
$vol{'autosize-shrink-threshold-percent'} =  75;
$vol{'initial-size-factor'} = 2;
$vol{'initial-max-autosize-factor'} = 4;

$hak = '/root/netapp_linux_unified_host_utilities-7-1.x86_64.rpm';

$sshcmd = 'ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey ';
$sshcmdsvm = $sshcmd.' vsadmin@'.$svm.' ';
$sshcmddrsvm = $sshcmd.' vsadmin@'.$drsvm.' ';
$sshcmdserver = $sshcmd.' '.$server.' ';

sub createlvmapping {
	%lv = ();
	@lvs = `$sshcmdserver lvs --all -o +devices --units g --separator ^`;
	foreach my $line (@lvs) {
		chomp $line;
		@param = split(/\^/,$line);
		if ($param[1] ne 'VG' and $param[2] ne 'Attr') {
			$lv = $param[0];
			$lv =~ s/\s//g;
			$vg = $param[1];
			$lv{$vg}{$lv}{'attr'} = $param[2];
			$lv{$vg}{$lv}{'sizeg'} = $param[3];
			$lv{$vg}{$lv}{'sizeg'} =~ s/g$//;
			$lv{$vg}{$lv}{'copy-percent'} = $param[10];
			@devices = split(/,/,$param[12]);
			foreach $device (@devices) {
				$device =~ s/\(\d+\)$//;
				$lv{$vg}{$lv}{'used-devices'} .= "$device ";
			}			
		}
	}
	@extents = `$sshcmdserver pvdisplay -m`;
	foreach my $line (@extents) {
		chomp $line;
		if ($line =~ /-- Physical volume ---/) {
			$pv = ''; $vg='';
			$first = 1;
		}
		if ($line =~ /^\s*PV Name\s+$deviceprefix(\S+)\S*$/) {
			$pv = $1;
			
		}
		if ($line =~ /^\s*VG Name\s+(\S+)\S*$/) {
			$vg = $1;
		}
		if ($line =~ /^\s*Physical extent\s+(\d+)\s+to\s+(\d+)\s*\:\s*$/) {
			$pestart = $1;
			$peend = $2;
			
		}
		if ($line =~ /^\s*Logical volume\s+\/dev\/$vg\/(\S+)\s*$/) {
			$lv = $1;

			if ($lv =~ /_mimage_(\d+)/) {
				$lv = '['.$lv.']';
			}
			if ($peend and $pv and $vg) {		
				push @{$lv{$vg}{$lv}{'pe-used'}{$pv}}, {'pe-start' => $pestart, 'pe-end' => $peend};
				$pestart = 0; $peend = 0; $lv = '';
			}
		}
	}
}

sub createpvmapping {

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
			if (not $dev =~/^$newdevprefix/) {	
				#add 1g on the netapp luns
				$sizeg = floor($3) + 1;
				if ($vg eq $inputvg) {
					$vol{'total-pv-size'} += $sizeg;
					$vol{'vgs'}{$vg}{'lun-count'} += 1;
					$vol{'vgs'}{$vg}{'old-dev-list'} .= "$deviceprefix$dev ";
					$vol{'vgs'}{$vg}{'luns'}[$vol{'vgs'}{$vg}{'lun-count'}]{'sizeg'} = $sizeg;
					$vol{'vgs'}{$vg}{'luns'}[$vol{'vgs'}{$vg}{'lun-count'}]{'old-device'} = $dev;
					$vol{'vgs'}{$vg}{'luns'}[$vol{'vgs'}{$vg}{'lun-count'}]{'new-device'} = $newdevprefix.$server.'_'.$vg.'_'.$vol{'vgs'}{$vg}{'lun-count'};			
				}
			}
		}
	}
	
	if (not $vol{'vgs'}{$inputvg}{'lun-count'}) {
		print "ERROR: could not identify PVs for VG or all been migrated: $inputvg\n";
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
	print "modifing volume:$volume size:$vol{'initial-size'}g\n";
	$cmd = "volume modify -volume $volume -size $vol{'initial-size'}g -space-guarantee none -percent-snapshot-space 0 -autosize-mode grow-shrink -max-autosize $vol{'max-autosize'}g -min-autosize $vol{'initial-size'}g -autosize-grow-threshold-percent $vol{'autosize-grow-threshold-percent'}  -autosize-shrink-threshold-percent $vol{'autosize-shrink-threshold-percent'}";
} else {
	print "creating volume:$volume size:$vol{'initial-size'}g\n";
	$cmd = "volume create -volume $volume -aggregate $aggr -size $vol{'initial-size'}g -space-guarantee none -percent-snapshot-space 0 -autosize-mode grow-shrink -max-autosize $vol{'max-autosize'}g -min-autosize $vol{'initial-size'}g -autosize-grow-threshold-percent $vol{'autosize-grow-threshold-percent'} -autosize-shrink-threshold-percent $vol{'autosize-shrink-threshold-percent'}";
}

#create/modify the volume 
@out = `$sshcmdsvm $cmd`;
$cmd = "volume efficiency on -volume $volume";
@out = `$sshcmdsvm $cmd`;

if ($drsvm and $draggr and $drsched) {
	$version = `$sshcmddrsvm version`;
	if (not $version=~/NetApp/) {
		print "DR svm $drsvm is not cDOT SVM or couldnot be contacted using ssh public key\n";
		exit 1;
	}
	print "creating snapmirror replication\n";
	$cmd = "volume create -volume $volume -aggregate $aggr -size $vol{'initial-size'}g -space-guarantee none -percent-snapshot-space 0 -autosize-mode grow-shrink -max-autosize $vol{'max-autosize'}g -min-autosize $vol{'initial-size'}g -autosize-grow-threshold-percent $vol{'autosize-grow-threshold-percent'} -autosize-shrink-threshold-percent $vol{'autosize-shrink-threshold-percent'} -type DP";
	@out = `$sshcmddrsvm $cmd`;
	$cmd = "snapmirror create -source-path $svm:$volume -destination-path $drsvm:$volume -type DP -schedule $drsched";
	@out = `$sshcmddrsvm $cmd`;
	$cmd = "snapmirror initialize -destination-path $drsvm:$volume";
	@out = `$sshcmddrsvm $cmd`;
}

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
		$lunsize = $vol{'vgs'}{$vg}{'luns'}[$lun]{'sizeg'};
		
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
			$vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'device-alias'} = $newdevprefix.$server.'_'.$vg.'_'.$lun;
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
`$sshcmdserver $rescancmd1` if $rescancmd1;
`$sshcmdserver $rescancmd2` if $rescancmd2;
`$sshcmdserver $rescancmd3` if $rescancmd3;
`$sshcmdserver $rescancmd4` if $rescancmd4;
#sleep 10;
print "\nconfiguration of dmultipath devices\n";
`$sshcmdserver multipath -r`;

print "\ncreating PV from new devices\n";
createpvmapping();
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

print "\nextending VG based on new devices\n";
createpvmapping();
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

print "\ncreating lvmirrors\n";

$continue = 1 ;
while ($continue) {
	createlvmapping();
	foreach $vg (keys %{$vol{'vgs'}}) {
		if (exists $lv{$vg}) {
			foreach $lvol (keys %{$lv{$vg}}) {
				if (not $lv{$vg}{$lvol}{'attr'} =~ /m/ and not exists $lv{$vg}{$lvol.$oldlvolsuffix} and not $lvol =~ /$oldlvolsuffix$/ ) {
					$mirrortopvs = '';
					foreach $pv (keys %{$lv{$vg}{$lvol}{'pe-used'}}) {
						if ($vol{'vgs'}{$vg}{'old-dev-list'} =~ /\s*$deviceprefix$pv\s+/) {
							$replacementdevice = '';
							for ($lun=1;$lun <= $vol{'vgs'}{$vg}{'lun-count'};$lun++) {
								if ($vol{'vgs'}{$vg}{'luns'}[$lun]{'old-device'} eq $pv) {
									$replacementdevice = $vol{'vgs'}{$vg}{'luns'}[$lun]{'new-device'};
								}
							}
							if (not $replacementdevice) {
								print "ERROR: could not identify new replacment device for PV:$pv\n";
								exit 1;
							}
							foreach $perange (@{$lv{$vg}{$lvol}{'pe-used'}{$pv}}) {
								$pes = $perange->{'pe-start'};
								$pee = $perange->{'pe-end'};
								$mirrortopvs .= $deviceprefix.$replacementdevice.':'.$pes.'-'.$pee.' ';
							}
						}	
					}
					if ($mirrortopvs) {
						$vol{'vgs'}{$vg}{'lvols'}{$lvol}{'done-mirror'} = 0;
						print "setting up mirror for LV:$vg/$lvol: \n";
						$lvmcmd = 'lvconvert -i 10 -m 1 --mirrorlog core '.$vg.'/'.$lvol.' '.$mirrortopvs;
						system("$sshcmdserver $lvmcmd");
						print "$out";
					} else {
						print "LV: $vg/$lvol is not located on old devices\n";
						$vol{'vgs'}{$vg}{'lvols'}{$lvol}{'done-mirror'} = 1;
					}
					
				} elsif (exists $lv{$vg}{$lvol.$oldlvolsuffix}) {
					$vol{'vgs'}{$vg}{'lvols'}{$lvol}{'done-mirror'} = 1;
				} elsif ($lv{$vg}{$lvol}{'attr'} =~ /m/ and $lv{$vg}{$lvol}{'copy-percent'} eq '100.00' and not $lvol =~/\[/) {
					$vol{'vgs'}{$vg}{'lvols'}{$lvol}{'done-mirror'} = 0;
					print "splitting mirror for LV:$vg/$lvol and keeping backup LV as:$vg/$lvol$oldlvolsuffix :";
					$lvmcmd = 'lvconvert --splitmirrors 1 --name '.$lvol.$oldlvolsuffix.' '.$vg.'/'.$lvol.' '.$vol{'vgs'}{$vg}{'old-dev-list'};
					$out = `$sshcmdserver $lvmcmd`;
					print "$out";
					print "deactivating of backup LV:$vg/$lvol$oldlvolsuffix\n"; 
					$lvmcmd = 'lvchange -a n '.$vg.'/'.$lvol.$oldlvolsuffix;
					$out = `$sshcmdserver $lvmcmd`;
				}
			}
		}
	}
	
	#check if all done and split vg
	$continue = 0;
	foreach $vg (keys %{$vol{'vgs'}}) {
		$vgdone = 1;
		foreach $lvol (keys %{$vol{'vgs'}{$vg}{'lvols'}}) {
			if (not $vol{'vgs'}{$vg}{'lvols'}{$lvol}{'done-mirror'}) {
				$continue =1;
				$vgdone = 0;
			}
		}
		if ($vgdone) {
			$lvmcmd = "vgsplit $vg $vg$oldlvolsuffix $vol{'vgs'}{$vg}{'old-dev-list'}";
			print "spliting vg:$vg keeping old lvs on vg:$vg$oldlvolsuffix :";
			$out = `$sshcmdserver $lvmcmd`;
			print $out;
		}
	}
	
	print "all done\n" if not $continue;
}

#my $pvjson = encode_json \%pv;
#my $lvjson = encode_json \%lv;
#my $voljson = encode_json \%vol;

#open (P,">/tmp/pvjson");
#print P $pvjson;

#open (P,">/tmp/lvjson");
#print P $lvjson;

#open (P,">/tmp/voljson");
#print P $voljson;
