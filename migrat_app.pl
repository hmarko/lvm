#!/usr/bin/perl

use JSON;
use Data::Dumper;
use Time::localtime qw( );
use POSIX;

$debug = 1;


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
$newdevprefix = 'cdotsan_';
$oldlvolsuffix = '_old_to_delete_XIV';

$runalllvmirroratonce = 1;

$vol{'size'} = '100';
$vol{'max-autosize'} = '15t';
$vol{'autosize-grow-threshold-percent'} =  90;
$vol{'autosize-shrink-threshold-percent'} =  75;
$vol{'initial-size-factor'} = 2;
$vol{'initial-max-autosize-factor'} = 4;

$hbaapicmd = 'yum install -y libhbaapi*';
$hak = '/root/netapp_linux_unified_host_utilities-7-1.x86_64.rpm';
$sd = '/root/netapp.snapdrive.linux_x86_64_5_3_1P2.rpm';
$svmpwd = 'St0rage1';
$rescanscript = '/root/lvm/scsi-rescan';

$sshcmd = 'ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey';
$sshcmdsvm = $sshcmd.' vsadmin@'.$svm.' ';
$sshcmddrsvm = $sshcmd.' vsadmin@'.$drsvm.' ';
$sshcmdserver = $sshcmd.' '.$server.' ';

$logpath = '/root/lvm/log/';
$logfile = 'migrate_app';
system("mkdir -p $logpath");


my ($sec,$minute,$hour,$day,$month,$year,$wday,$yday,$isdst) = localtime(time);
$year += 1900;
$month = '0'.$month if $month < 10;
$day = '0'.$day if $day < 10;
$hour = '0'.$hour if $hour < 10;
$minute = '0'.$minute if $minute < 10;
my $starttime = $day.$month.$year.$hour.$minute;

sub runcmd {
    my $cmd = $_[0];
    my @output;
   
	write_log("running command:") if $debug;
	write_log($cmd,1,1) if $debug;
	@output = `$cmd`;
	write_log("commnad output:") if $debug and $#output;
	foreach $line (@output) {
		chomp $line;
		write_log($line,1,1) if $debug;
	}

    return @output;
}

sub runcmdnoarr {
    my $cmd = $_[0];
    my $output;
   
	write_log("running comamnd:") if $debug;
	write_log($cmd,1,1);
	$output = `$cmd`;
	write_log("commnad output:") if $debug;
	write_log($output,1,1) if $debug;

    return $output;
}

sub write_log {
    my $logline = $_[0];
    my $dontwritetime = $_[1];
    my $indent = $_[2];
	
    $now = Time::localtime::ctime();

    open(LOGFILE, '>>'.$logpath.$logfile.'.'.$server.'.'.$app.'.'.$starttime.'.log') || die "cannot open syslog file: ".$logpath.$logfile.'.'.$server.'.'.$app.'.'.$starttime.".log for writing\n";

    $logline = "$now - $logline" if not $dontwritetime;
    print "$logline\n" if not $indent;
    print "\t$logline\n" if $indent;

	if (not $indent) {
		print LOGFILE "$logline\n";
	} else {
		print LOGFILE "\t$logline\n";
	}	
	close (LOGFILE);
}

sub dumpjson {
	my $pvjson = encode_json \%pv;
	my $lvjson = encode_json \%lv;
	my $voljson = encode_json \%vol;

	open (P,">$logpath".'pvjson.'."$server.$app.$starttime.json");
	print P $pvjson;
	close (P);

	open (P,">$logpath".'lvjson.'."$server.$app.$starttime.json");
	print P $lvjson;
	close (P);

	open (P,">$logpath".'voljson.'."$server.$app.$starttime.json");
	print P $voljson;
	close (P);
}

sub createlvmapping {
	%lv = ();
	@lvs = runcmd("$sshcmdserver lvs --all --units g --separator ^ -o lv_name,vg_name,size,devices,copy_percent,lv_attr");
	foreach my $line (@lvs) {
		chomp $line;
		@param = split(/\^/,$line);
		if ($param[2] ne 'LSize') {
			$lv = $param[0];
			$lv =~ s/\s//g;
			$vg = $param[1];
			$lv{$vg}{$lv}{'attr'} = $param[5];
			$lv{$vg}{$lv}{'sizeg'} = $param[2];
			$lv{$vg}{$lv}{'sizeg'} =~ s/g$//;
			$lv{$vg}{$lv}{'copy-percent'} = $param[4];
			@devices = split(/,/,$param[3]);
			foreach $device (@devices) {
				$device =~ s/\(\d+\)$//;
				$lv{$vg}{$lv}{'used-devices'} .= "$device ";
			}			
		}
	}
	@extents = runcmd("$sshcmdserver pvdisplay -m");
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
			if ($lv =~ /_rimage_(\d+)/) {
				$lv = '['.$lv.']';
			}	
			if ($lv =~ /_rmeta_(\d+)/) {
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

	@diskscan = runcmd("$sshcmdserver lvmdiskscan");
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

	@diskscan = runcmd("$sshcmdserver pvs --units m -o +pv_pe_count");
	foreach my $line (@diskscan) {
		chomp $line;
		if ($line=~/$deviceprefix(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+([0-9]*\.[0-9]+|[0-9]+)(\w+)\s+([0-9]*\.[0-9]+|[0-9]+)(\w+)\s+(\d+)/) {
			$pv{$1}{vg} = $2;
			$pv{$1}{vgsize} = $5;
			$pv{$1}{vgsizequantifer} = $6;
			$pv{$1}{vgfree} = $7;
			$pv{$1}{vgfreequatifier} = $8;
			$pv{$1}{lastpe} = $9;
			$pv{$1}{lastpe}--;
		}
	}
	dumpjson();
}

$version = (runcmd("$sshcmdserver uname -a"))[0];
if (not $version=~/Linux/) {
	write_log("server $server is not Linux or couldnot be contacted using ssh public key");
	exit 1;
}


$version = (runcmd("$sshcmdsvm version"))[0];
if (not $version=~/NetApp/) {
	write_log("ERROR: svm $svm is not cDOT SVM or couldnot be contacted using ssh public key");
	exit 1;
}

$majorver = (runcmd("$sshcmdserver \"lsb_release -s -r | cut -d '.' -f 1\""))[0]; chomp $majorver;
$minorver = (runcmd("$sshcmdserver \"lsb_release -s -r | cut -d '.' -f 2\""))[0]; chomp $minorver;

if ( $majorver or $minorver) {
	write_log("identified RedHat release as $majorver".'.'."$minorver");
}

write_log("installing HAK and SD on server");
runcmd("$sshcmdserver $hbaapicmd");
runcmd("scp -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey $hak $server:$hak");
runcmd("scp -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey $sd $server:$sd");


runcmd("$sshcmdserver rpm -i $hak");
runcmd("$sshcmdserver rpm -i $sd");

runcmd("scp -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey snapdrive.conf ".$server.':/opt/NetApp/snapdrive/snapdrive.conf');

runcmd("$sshcmdserver /opt/NetApp/snapdrive/bin/snapdrived stop");
runcmd("$sshcmdserver /opt/NetApp/snapdrive/bin/snapdrived start");

runcmd("$sshcmdserver snapdrive config delete $svm");
runcmd("$sshcmdserver \"printf '".$svmpwd.'\n'.$svmpwd.'\n'."'".' | snapdrive config set vsadmin '.$svm.'"');

write_log("",1);
write_log("creating/modifing netapp volume and luns");

@pvdisplay = runcmd("$sshcmd $server pvdisplay -C -o pv_name,vg_name,pv_size --units g");
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
		write_log("ERROR: could not identify PVs for VG or all been migrated: $inputvg");
		exit 1;
	}
}
$volume = $server.'_'.$app;
$volume =~ s/\-/\_/g;

if ($vol{'total-pv-size'} * 2 > 100) {
	$vol{'initial-size'} = floor($vol{'total-pv-size'}) * $vol{'initial-size-factor'};
	$vol{'max-autosize'} = floor($vol{'total-pv-size'}) * $vol{'initial-max-autosize-factor'};
}

$cmd = "volume show -volume $volume -field state,type";
@out = runcmd("$sshcmdsvm $cmd");

if ($out[2]=~/$svm\s+$volume\s+(\S+)\s+(\S+)/) {
	$state = $1;
	$type = $2;
	if ($state ne 'online' or $type ne 'RW') {
		write_log("ERROR: volume $volume exists on the SVM with state:$state type:$type");
		exit 1;
	}
	write_log("modifing volume:$volume size:$vol{'initial-size'}g");
	$cmd = "volume modify -volume $volume -size +".$vol{'initial-size'}."g -space-guarantee none -percent-snapshot-space 0 -autosize-mode grow-shrink -max-autosize $vol{'max-autosize'}g -min-autosize $vol{'initial-size'}g -autosize-grow-threshold-percent $vol{'autosize-grow-threshold-percent'}  -autosize-shrink-threshold-percent $vol{'autosize-shrink-threshold-percent'}";
} else {
	write_log("creating volume:$volume size:$vol{'initial-size'}g");
	$cmd = "volume create -volume $volume -aggregate $aggr -size $vol{'initial-size'}g -space-guarantee none -percent-snapshot-space 0 -autosize-mode grow-shrink -max-autosize $vol{'max-autosize'}g -min-autosize $vol{'initial-size'}g -autosize-grow-threshold-percent $vol{'autosize-grow-threshold-percent'} -autosize-shrink-threshold-percent $vol{'autosize-shrink-threshold-percent'}";
}

#create/modify the volume 
@out = runcmd("$sshcmdsvm $cmd");
$cmd = "volume efficiencys on -volume $volume";
@out = runcmd("$sshcmdsvm $cmd");

if ($drsvm and $draggr and $drsched) {
	$version = `$sshcmddrsvm version`;
	if (not $version=~/NetApp/) {
		write_log("ERROR:DR svm $drsvm is not cDOT SVM or couldnot be contacted using ssh public key");
		exit 1;
	}
	write_log("creating snapmirror replication");
	$cmd = "volume create -volume $volume -aggregate $aggr -size $vol{'initial-size'}g -space-guarantee none -percent-snapshot-space 0 -autosize-mode grow-shrink -max-autosize $vol{'max-autosize'}g -min-autosize $vol{'initial-size'}g -autosize-grow-threshold-percent $vol{'autosize-grow-threshold-percent'} -autosize-shrink-threshold-percent $vol{'autosize-shrink-threshold-percent'} -type DP";
	@out = runcmd("$sshcmddrsvm $cmd");
	$cmd = "snapmirror create -source-path $svm:$volume -destination-path $drsvm:$volume -type DP -schedule $drsched";
	@out = runcmd("$sshcmddrsvm $cmd");
	$cmd = "snapmirror initialize -destination-path $drsvm:$volume";
	@out = runcmd("$sshcmddrsvm $cmd");
}

@existingluns = runcmd("$sshcmdsvm \"set -units gb;lun show -fields path,size,state,mapped -volume $volume\"");
@existinglunmappingss = runcmd("$sshcmdsvm lun mapping show -volume $volume -fields path,igroup");

@igroup = runcmd("$sshcmdsvm igroup show $igroup -fields initiator");

if (not $igroup[2] =~ /\s+($igroup)\s+/) {
	write_log("ERROR: igroup:$igroup does not exists");
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
				write_log("WARNING: lun $lunpath already exists on this volume with size:$size state:$state");
				$found = 1;
			}
		}
		if (not $found) {
			write_log("creating lun: $lunpath");
			$cmd = "lun create -path $lunpath -size $lunsize".'GB -ostype linux -space-reserve disable -space-allocation enabled';
			runcmd("$sshcmdsvm $cmd");
		}

		$cmd = "lun show -path $lunpath -fields serial-hex";
		@luninfo = runcmd("$sshcmdsvm $cmd");
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
					write_log("ERROR: lun:$lunpath is already mapped to another igroup:$mappedigroup");
					exit 1;
				}
				$mapped =1;
			}
		}
		if (not $mapped) {
			write_log("mapping lun: $lunpath to igroup:$igroup");
			$cmd = "lun map -path $lunpath -igroup $igroup";
			runcmd("$sshcmdsvm $cmd");
		}
		$found = 0;				
	}
}



$multipathconf = runcmdnoarr("$sshcmdserver cat /etc/multipath.conf");
$addvendor = 1;
if ($multipathconf =~ /\s*vendor\s+\"NETAPP\"/) {
	$addvendor = 0;
}

$newfile = '';

$path_checker = 'tur';
$features = '"3 queue_if_no_path pg_init_retries 50"';
$prio = 'prio_callout "/sbin/mpath_prio_alua /dev/%n"';
$getuid_callout = '"/sbin/scsi_id -g -u -s /block/%n"';

if ($majorver == '5' and $minorver <= 6) {
	$path_checker = 'directio';
	$features = '"1 queue_if_no_path"';
}
if ($majorver == '6') {
	$prio = 'prio "alua"';
	$getuid_callout = '"/lib/udev/scsi_id -g -u -d /dev/%n"';
}
write_log("path_checker been set as: $path_checker",0,1);
write_log("features been set as: $features",0,1);
write_log("prio been set as: $prio",0,1);
write_log("getuid_callout been set as: $getuid_callout",0,1);

if (not $multipathconf =~ /multipaths\s*{/) {
	$multipathconf .= "\nmultipaths {\n}\n";
}

foreach $line (split(/\n/,$multipathconf)) {
	$newfile .= "$line\n";
	
	chomp $line;
	if ($line =~ /^\s*devices\s*\{\s*$/ and $addvendor) {
		$addvendor = 0;
		$newfile .= << "END_TEXT"
	device {
		vendor "NETAPP"
		product "LUN"
		path_grouping_policy group_by_prio
		features $features
		$prio
		path_checker $path_checker
		path_selector "round-robin 0"
		failback immediate
		hardware_handler "1 alua"
		rr_weight uniform
		rr_min_io 128
		getuid_callout $getuid_callout
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

write_log("backing up and recreating /etc/multipath.conf");
runcmd("$sshcmdserver \"yes|cp -rf /etc/multipath.conf /etc/multipath.conf.orig\"");
$mpfile = "/tmp/multipath_$server.tmp";
open (MPCONF,">$mpfile") || die "ERROR: cannot open $mpfile for writing\n";
print MPCONF "$newfile\n";
close(MPCONF);

runcmd("scp -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey $mpfile $server".':/etc/multipath.conf');

write_log("",1);
write_log("rescanning new devices");
write_log("coping rescan script $rescanscript to the server");
runcmd("scp -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey $rescanscript $server".':/root/scsi-rescan');
$out = runcmd("$sshcmdserver bash /root/scsi-rescan");
$out = runcmd("$sshcmdserver iscsiadm -m session --rescan");
$cmd = "grep mpt /sys/class/scsi_host/host?/proc_name | awk -F \'/\' \'".'{print "scanning scsi host adapter:"$5" " system("echo \"- - -\" > /sys/class/scsi_host/"$5"/scan")}'."'";
$out = runcmd("$sshcmdserver $cmd");
sleep 10;

write_log("",1);
write_log("configuration of dmultipath devices");
runcmd("$sshcmdserver multipath -r");

write_log("",1);
write_log("creating PV from new devices");
createpvmapping();
foreach $vg (keys %{$vol{'vgs'}}) {
	foreach $lunpath (keys %{$vol{'vgs'}{$vg}{'created-luns'}}) {
		$devicealias = $vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'device-alias'};
		if (not exists $pv{$devicealias}) {
			write_log("ERROR: multipath device $deviceprefix$devicealias could not be found");
			exit 1;
		} elsif (not $pv{$devicealias}{configured}) {
			write_log("creating pv:$devicealias :");
			@out = runcmd("$sshcmdserver pvcreate $pvcreateparams $deviceprefix$devicealias");
			write_log($out[0],1);
		} else {
			write_log("pv:$devicealias already configured as pv");
		}
	}
}

write_log("",1);
write_log("extending VG based on new devices");
createpvmapping();
foreach $vg (keys %{$vol{'vgs'}}) {
	foreach $lunpath (keys %{$vol{'vgs'}{$vg}{'created-luns'}}) {
		$devicealias = $vol{'vgs'}{$vg}{'created-luns'}{$lunpath}{'device-alias'};
		if ($pv{$devicealias}{configured}) {
			if (not exists $pv{$devicealias}{vg}) {
				write_log("extending vg:$vg with pv:$deviceprefix$devicealias :");
				@out = runcmd("$sshcmdserver vgextend $vg $deviceprefix$devicealias");
				write_log($out[0],1);
			} elsif ( $pv{$devicealias}{vg} ne $vg) {
				write_log("ERROR: pv:$devicealias is part of vg:$pv{$devicealias}{vg} while it should be part of vg:$vg");
				exit 1;
			} else {
				write_log("pv:$devicealias is already part of vg:$vg");
			}
		} else {
			write_log("ERROR: pv:$devicealias could not be created");
			exit 1;
		}
	}
}

write_log("",1);
write_log("creating lvmirrors");

$continue = 1 ;
while ($continue) {
	createlvmapping();
	dumpjson();
	foreach $vg (keys %{$vol{'vgs'}}) {
		if (exists $lv{$vg}) {
			foreach $lvol (keys %{$lv{$vg}}) {
				$copypercent = floor($lv{$vg}{$lvol}{'copy-percent'});
				$copying = 0; $copying = 1 if $copypercent > 0 and $copypercent <100;
				$copying = 1 if $copypercent <100 and length($lv{$vg}{$lvol}{'copy-percent'}) > 0;
				if ($copying) {
					write_log("LV:$vg/$lvol is currently copying, $copypercent".'% completed');
					$vol{'vgs'}{$vg}{'lvols'}{$lvol}{'done-mirror'}=0;
					sleep 5;
				} elsif (not $lv{$vg}{$lvol}{'attr'} =~ /m/ and not $lv{$vg}{$lvol}{'attr'} =~ /r---/ and not exists $lv{$vg}{$lvol.$oldlvolsuffix} and not $lvol =~ /$oldlvolsuffix$/ and not $lvol =~/\[/ and not $lvol =~ /_rimage_/ and not $lvol =~ /_rmeta_/ and not $copying) {
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
								write_log("ERROR: could not identify new replacment device for PV:$pv");
								exit 1;
							}
							foreach $perange (@{$lv{$vg}{$lvol}{'pe-used'}{$pv}}) {
								%copy = %{$perange};
								$pes = $copy{'pe-start'}; $pes = '0' if not $pes;
								$pee = $copy{'pe-end'};
								print Dumper(\%copy);
								print "IIIIIII $pes $pee\n";
								$mirrortopvs .= $deviceprefix.$replacementdevice.':'.$pes.'-'.$pee.' ';
								$pvforadditionalpe = $replacementdevice;
								$additionalpe = $deviceprefix.$replacementdevice.':'.$pv{$replacementdevice}{lastpe}.'-';
							}
						}	
					}
					if ($mirrortopvs) {
						$vol{'vgs'}{$vg}{'lvols'}{$lvol}{'done-mirror'} = 0;
						write_log("making sure LV:$vg/$lvol is active");
						$lvmcmd = 'lvchange -a y '.$vg.'/'.$lvol;
						runcmd("$sshcmdserver $lvmcmd");
						write_log("setting up mirror for LV:$vg/$lvol: ");
						$wait = '-i 10 ';
						$wait = '' if $runalllvmirroratonce;
						$lvmcmd = 'lvconvert '.$wait.'-m 1 --mirrorlog core '.$vg.'/'.$lvol.' '.$mirrortopvs.' '.$additionalpe;
						$pv{$pvforadditionalpe}{lastpe}--;
						runcmd("$sshcmdserver $lvmcmd");
						sleep 5;
					} else {
						runcmd("LV: $vg/$lvol is not located on old devices");
						$vol{'vgs'}{$vg}{'lvols'}{$lvol}{'done-mirror'} = 1;
					}
				} elsif (exists $lv{$vg}{$lvol.$oldlvolsuffix}) {
					$vol{'vgs'}{$vg}{'lvols'}{$lvol}{'done-mirror'} = 1;
					$lvmcmd = 'lvchange -a n '.$vg.'/'.$lvol.$oldlvolsuffix;
					runcmd("$sshcmdserver $lvmcmd");
				} elsif (($lv{$vg}{$lvol}{'attr'} =~ /m/ or $lv{$vg}{$lvol}{'attr'} =~ /r---/) and $lv{$vg}{$lvol}{'copy-percent'} eq '100.00' and not $lvol =~/\[/) {
					$vol{'vgs'}{$vg}{'lvols'}{$lvol}{'done-mirror'} = 0;
					write_log("splitting mirror for LV:$vg/$lvol and keeping backup LV as:$vg/$lvol$oldlvolsuffix :");
					$lvmcmd = 'lvconvert --splitmirrors 1 --name '.$lvol.$oldlvolsuffix.' '.$vg.'/'.$lvol.' '.$vol{'vgs'}{$vg}{'old-dev-list'};
					$out = (runcmd("$sshcmdserver $lvmcmd"))[0];
					write_log($out,1);
					write_log("deactivating of backup LV:$vg/$lvol$oldlvolsuffix"); 
					$lvmcmd = 'lvchange -a n '.$vg.'/'.$lvol.$oldlvolsuffix;
					runcmd("$sshcmdserver $lvmcmd");
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
			write_log("spliting vg:$vg keeping old lvs on vg:$vg$oldlvolsuffix :");
			$out = (runcmd("$sshcmdserver $lvmcmd"))[0];
			write_log($out,1);
		}
	}
	
	write_log("all done") if not $continue;
}

