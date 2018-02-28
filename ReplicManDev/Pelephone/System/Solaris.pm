package Pelephone::System::Solaris;

use strict;
use warnings;
use Sys::Hostname;
use Pelephone::System;
use Pelephone::System::Debug;
#print "in Pelephone::System::Solaris\n\n\n" ;

$| = 1;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw(&GetMPList &ReleasDG &DeleteDG &ReAttachDG &CreateDG
					  &DiskAddDG &ActivateDG);
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
	my $SourceFile = $Host . ":/etc/vfstab" ;
	my $TargetFile = "/tmp/" . $Host . "_vfstab." . $$ ;
	system ("rcp $SourceFile $TargetFile") ;
	foreach my $line (`cat $TargetFile`) {
		if ($line =~ /$VG_Name/) {
			my $MP = (split (' ', $line))[2] ;
			$MP_List{$MP} = $MP ;
#			push (@MP_List, $MP) ;
		}
	}
	return %MP_List ;
}
sub ReleasDG($$) {
	my $Host = shift ;		chomp $Host ;
	my $DG = shift ;		chomp $DG ;
	my $cmd = $METASET . " -s " . $DG . " -r" ;
	my $ExitCode = RunProgram ($Host, "$cmd") ;
	return $ExitCode ;
}
sub DeleteDG($$) {
	my $Host = shift ;		chomp $Host ;
	my $DG = shift ;		chomp $DG ;
	my $cmd = $METASET . " -s " . $DG . " -P" ;
	my $ExitCode = RunProgram ($Host, "$cmd") ;
	return $ExitCode ;
}
sub ReAttachDG($$) {
	my $Host = shift ;		chomp $Host ;
	my $DG = shift ;		chomp $DG ;
	my $cmd = $METASET . " -s " . $DG . " -t" ;
	my $ExitCode = RunProgram ($Host, "$cmd") ;
	return $ExitCode ;
}
sub CreateDG($$) {
	my $Host = shift ;		chomp $Host ;
	my $DG = shift ;		chomp $DG ;
	my $cmd = $METASET . " -s " . $DG . " -a -h " . $Host ;
	my $ExitCode = RunProgram ($Host, "$cmd") ;
	return $ExitCode ;
}
sub DiskAddDG($$$) {
	my $Host = shift ;		chomp $Host ;
	my $DG = shift ;		chomp $DG ;
	my $Disks = shift ;		chomp $Disks ;
	$Disks =~ s/:/ /g ;
	my $cmd = $METASET . " -s " . $DG . " -a " . $Disks ;
	my $ExitCode = RunProgram ($Host, "$cmd") ;
	return $ExitCode ;
}
sub ActivateDG($$) {
	my $Host = shift ;		chomp $Host ;
	my $DG = shift ;		chomp $DG ;
	my $cmd = $METAINIT . " -s " . $DG . " -a" ;
	my $ExitCode = RunProgram ($Host, "$cmd") ;
	return $ExitCode ;
}
1;
