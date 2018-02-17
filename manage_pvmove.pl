#!/usr/bin/perl

use JSON;

@file = `cat pvmove.txt`;
foreach my $line (@file) {
	chomp $line;
	($srcpv,$dstpv) = split(/\s+/,$line);
	$pvsrc{$srcpv}{name}=$dstpv;
	$pvdst{$dstpv}{name}=$srcpv;
	if (exists $pvsrc{$dstpv} or exists $pvdst{$srcpv}) {
		print "error in config file for dst:$dstpv or src:$srcpv\n";
		exit 1;
	}
}
@diskscan = `lvmdiskscan`;
foreach my $line (@diskscan) {
	chomp $line;
	if ($line=~/(\/dev\/mapper\/\S+).+\[\s+([0-9]*\.[0-9]+|[0-9]+)\s+(\S+)\]\s+(LVM physical volume)/) {
		if (exists $pvsrc{$1}) {
			$pvsrc{$1}{size} = $2;
			$pvsrc{$1}{quantifier} = $3;
			$pvsrc{$1}{pvconfigured} = 1;
		}
                if (exists $pvdst{$1}) {
                        $pvdst{$1}{size} = $2;
                        $pvdst{$1}{quantifier} = $3;
                        $pvdst{$1}{pvconfigured} = 1;
                }
	}
        if ($line=~/(\/dev\/mapper\/\S+).+\[\s+([0-9]*\.[0-9]+|[0-9]+)\s+(\S+)\]\s+$/) {
                if (exists $pvsrc{$1}) {
                        $pvsrc{$1}{size} = $2;
                        $pvsrc{$1}{quantifier} = $3;
                        $pvsrc{$1}{pvconfigured} = 0;
                }
                if (exists $pvdst{$1}) {
                        $pvdst{$1}{size} = $2;
                        $pvdst{$1}{quantifier} = $3;
                        $pvdst{$1}{pvconfigured} = 0;
                }
        }
	
}

my $pvdstjson = encode_json \%pvdst;
my $pvsrcjson = encode_json \%pvsrc;

print " $pvsrcjson\n";
