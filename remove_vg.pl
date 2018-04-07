#!/usr/bin/perl

use Time::localtime qw( );

$server = $ARGV[0];
$vgs = $ARGV[1];

$debug = 0;
$runalllvmirroratonce = 1;

$sshcmd = 'ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=publickey';
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

sub write_log {
    my $logline = $_[0];
    my $dontwritetime = $_[1];
    my $indent = $_[2];
	
    $now = Time::localtime::ctime();

    open(LOGFILE, '>>'.$logpath.$logfile.'.'.$server.'.'.$volume.'.'.$starttime.'.log') || die "cannot open syslog file: ".$logpath.$logfile.'.'.$server.'.'.$volume.'.'.$starttime.".log for writing\n";

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


sub RemoveMPDevice ($$) {
	my $mpdev = shift;
	my $mp = shift;
	my @mpll = @{$mp};
	
	@out = runcmd($sshcmdserver."multipath -f $mpdev") ;
	if ($out[0]=~/in use/) {
		write_log("Warning: Could not delete device $mpdev force deleting it");
		write_log("Force delete device $mpdev");
		runcmd($sshcmdserver."kpartx -d $mpdev") ;
		runcmd($sshcmdserver."dmsetup remove -f $mpdev") ;
		runcmd($sshcmdserver."multipath -f $mpdev") ;
	}
	my $found = 0;
	foreach my $mlpline (@mpll) {
		chomp $mlpline;
		if ($found and (not $mlpline =~ /(\_)|(size=)|(\|)|(`-)/ or $mlpline=~/(NETAPP)|(IBM)/)) {
				$found = 0;
		}
		
		if ($mlpline =~ /$mpdev\s+/ or $mlpline =~ /\($mpdev\)/) {
			$found = 1;		
		}

		if ($mlpline =~ /\s+(sd\S+)\s+/ and $found) {
			$underlyingdevice = $1;
			write_log("Removing underlying device $underlyingdevice");
			runcmd("echo \"echo 1 > /sys/block/$underlyingdevice/device/delete\" > /tmp/rmdev");
			runcmd("scp /tmp/rmdev $server:/tmp/removedev");
			runcmd($sshcmdserver."bash /tmp/removedev");
		}
	}
}

@mpll = runcmd($sshcmdserver."multipath -ll");
@pvs = runcmd($sshcmdserver."pvs --separator ^");

write_log("Getting Target VG List") ;
my @vgsarr = split (',', $vgs) ;
foreach my $vg (@vgsarr) {
	write_log ("Getting list of PVs for VG:$vg");
	foreach my $pvsline (@pvs) {
		chomp $pvsline;
		my @pvinfo = split(/\^/,$pvsline);
		if ($pvinfo[1] eq $vg) {
			my $mpdev = $pvinfo[0];
			$mpdev =~ /.+\/(\S+)/;
			$mpdev = $1;
			if ($mpdev) {
				write_log("Removing multipath device:$mpdev");
				RemoveMPDevice($mpdev,\@mpll);
			}
		}
	}					
}						

