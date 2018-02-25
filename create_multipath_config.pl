#!/usr/bin/perl

use POSIX;


$server = $ARGV[0];
$svm = $ARGV[1];
$app = $ARGV[2];
$aggr = $ARGV[3];

$vgs = $ARGV[4];


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
			$vg = $2;
			#add 1g on the netapp luns
			$sizeg = $3 + 1;
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
print "$cmd\n";
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

@luns = `$sshcmdsvm lun show -fields path,size,state,mapped -volume $volume`;
@lunmappingss = `$sshcmdsvm lun mapping show -volume $volume`;

foreach $vg (keys %{$vol{'vgs'}}) {
	for ($lun=1;$lun <= $vol{'vgs'}{$vg}{'lun-count'};$lun++) {
		$lunpath = '/vol/'.$volume.'/'.$vg.'_'.$lun;
		$lunsize = $vol{'vgs'}{$vg}{'luns'}[$lun];
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
