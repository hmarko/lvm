package Pelephone::System::HPUX;

use strict;
use warnings;
use Sys::Hostname;
use Pelephone::System;
use Pelephone::System::Debug;
#print "in Pelephone::System::HPUX\n\n\n" ;

$| = 1;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw(&GetMPList &GetFS);
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK   = qw(@Result $ExitCode $SecureMode $RunRetry);
}

our @EXPORT_OK;
our $METASET = "/usr/sbin/metaset" ;
our $METAINIT = "/usr/sbin/metainit" ;

END { }       # module clean-up code here (global destructor)

sub GetMPList ($$) {
	my $Host = shift ;			chomp $Host ;
	my $VG_Name = shift ;		chomp $VG_Name ;
	my %MP_List ;
	my $SourceFile = $Host . ":/etc/fstab" ;
	my $TargetFile = "/tmp/" . $Host . "_fstab." . $$ ;
	if (IsSecureMode()) {
		system ("scp $SourceFile $TargetFile") ;
	} else {
		system ("rcp $SourceFile $TargetFile") ;
	}
	foreach my $line (`cat $TargetFile`) {
		if ($line =~ /$VG_Name/ && $line !~ /^#/) {
			my ($MP, $FS) = (split (' ', $line))[1,0] ;
			$MP_List{$MP} = $FS ;
		}
	}
	return %MP_List ;
}
sub GetFS ($$) {
	my $Host = shift ;		chomp $Host ;
	my $MP = shift ;		chomp $MP ;
	$MP =~ 's/\//\\//g' ;
	my @MP_List ;
	my $SourceFile = $Host . ":/etc/fstab" ;
	my $TargetFile = "/tmp/" . $Host . "_fstab." . $$ ;
	if (IsSecureMode()) {
		system ("scp $SourceFile $TargetFile") ;
	} else {
		system ("rcp $SourceFile $TargetFile") ;
	}
	foreach my $line (`cat $TargetFile`) {
		if ($line =~ /$MP/) {
			my $FS = (split (' ', $line))[0] ;
			return $FS ;
		}
	}
	return '' ;
}
1;
