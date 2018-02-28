package Pelephone::SVC;  

use strict;
use warnings;
use Pelephone::System ;
use Pelephone::Logger;

$| = 1 ;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw(&isSvcFcCgExists &isSvcFcCgCopying &isSvcFcCgStopped &StopSvcFcCg &StartSvcFcCg);
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

}

our @EXPORT_OK;

END { }       # module clean-up code here (global destructor)


sub isSvcFcCgExists($$) {
	my $svc = shift ;		chomp $svc ;
	my $fc_group = shift ;		chomp $fc_group ;
	Info ("Checking if Flash Copy Group $fc_group exists on SVC Box $svc \n");
	my $cmd = "ssh superuser\@$svc svcinfo lsfcconsistgrp -filtervalue name=$fc_group" ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub isSvcFcCgCopying($$) {
	my $svc = shift ;		chomp $svc ;
	my $fc_group = shift ;		chomp $fc_group ;
	Info ("Checking if Flash Copy Group $fc_group is copying on SVC Box $svc \n");
	my $cmd = "ssh superuser\@$svc svcinfo lsfcconsistgrp -filtervalue name=$fc_group | grep -w copying" ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub isSvcFcCgStopped($$) {
	my $svc = shift ;		chomp $svc ;
	my $fc_group = shift ;		chomp $fc_group ;
	Info ("Checking if Flash Copy Group $fc_group has stopped on SVC Box $svc \n");
	my $cmd = "ssh superuser\@$svc svcinfo lsfcconsistgrp -filtervalue name=$fc_group | grep -w stopped" ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub StopSvcFcCg($$) {
	my $svc = shift ;		chomp $svc ;
	my $fc_group = shift ;		chomp $fc_group ;
	Info ("Stopping the Flash Copy Group $fc_group on SVC Box $svc \n");
	my $cmd = "ssh superuser\@$svc svctask stopfcconsistgrp $fc_group" ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub StartSvcFcCg($$) {
	my $svc = shift ;		chomp $svc ;
	my $fc_group = shift ;		chomp $fc_group ;
	Info ("Starting the Flash Copy Group $fc_group on SVC Box $svc \n");
	my $cmd = "ssh superuser\@$svc svctask startfcconsistgrp -prep $fc_group" ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}



#-----------------------------------------------------------------------------#
# The Main package Section!
#

1;
 
