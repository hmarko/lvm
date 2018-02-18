#!/usr/bin/perl

use JSON;

$deviceprefix = '/dev/mapper/';
$pvcreateparams = '--dataalignment 4k';
sub createmapping {
	$pv = false;
	@file = `cat pvmove.txt`;
	foreach my $line (@file) {
		chomp $line;
		($srcpv,$dstpv) = split(/\s+/,$line);
		$pv{$srcpv}{destname}=$dstpv;
		$pv{$dstpv}{srcname}=$srcpv;
		if (exists $pvsrc{$dstpv} or exists $pvdst{$srcpv}) {
			print "error in config file for dst:$dstpv or src:$srcpv\n";
			exit 1;
		}
	}
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

createmapping();

foreach $p (keys %pv) {
	if (not $pv{$p}{configured} and $pv{$p}{srcname}) {
		$dev = $deviceprefix.$p;
		print "creating PV: $dev :";
		@pvcreate = `pvcreate $pvcreateparams $dev`;
		print "$pvcreate[0]\n";
	}
}
createmapping();

foreach $p (keys %pv) {
	if ($pv{$p}{configured} and $pv{$p}{srcname}) {
		$vg = $pv{$pv{$p}{srcname}}{vg};
		if ($vg and not $pv{$p}{vg}) {
			$dev = $deviceprefix.$p;
			print "extanding VG:$vg with $dev :";
			@pvextand = `vgextend $vg $dev`;
			print "$pvextand[0]\n";
		} elsif (not $vg) {
			print "WARNING: $deviceprefix$p source PV:$pv{$p}{srcname} is not part of a VG\n";
			$pv{$p}{nomigrate} = 1;
		} elsif ($vg ne $pv{$p}{vg}) {
			print "WARNING: $deviceprefix$p is already part of VG:$pv{$p}{vg} which is diffrent than it's source VG:$vg\n";
			$pv{$p}{nomigrate} = 1;
		}
	}
}
createmapping();

my $pvjson = encode_json \%pv;

print " $pvjson\n";
