#!/usr/bin/perl
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
