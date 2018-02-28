package Pelephone::User;

use strict;
use warnings;
use Sys::Hostname;

$| = 1 ;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw(&MustRunAs &MustRunOn);
	@EXPORT_OK   = qw();
	%EXPORT_TAGS = ( );
}

END { }

our @EXPORT_OK;

#-----------------------------------------------------------------------------#
# This function check if the progrum run's under <UserName>, if not           #
# the program will terminate !                                                #
#-----------------------------------------------------------------------------#
sub MustRunAs($) {
	my $Name = shift ;
	chomp ($Name) ;

	# Getting the UID of running Program
	my $resu = `/usr/bin/id` ;
	my $IAm = (split ('\(', (split (' ', $resu))[0]))[1] ;
	$IAm =~ s/\)// ;

	# Check if the UID and the UserName are the right one's
	my $UID = getpwnam ($IAm) ;
	my $name1  = getpwuid($UID);
	if (($name1 ne $Name) or ($name1 ne $IAm)){
		print "\n\tThis Program MUST run under $Name !!!\n\n" ;
		exit 1;
	}
}
#-----------------------------------------------------------------------------#
# This function check if the progrum run's on <HostName>, if not              #
# the program will terminate !                                                #
#-----------------------------------------------------------------------------#
sub MustRunOn($) {
	my $Host = shift ;
	chomp ($Host) ;

	# Getting the HostName of the <Runnig Host>
	my $RunHost = hostname() ;
	chomp ($RunHost) ;

	# Check if the Runnig host is the host theat the progrum shuld run on.
	if ($Host ne $RunHost) {
		print "\n\tThis Program MUST run on $Host !!!\n\n" ;
		exit 1;
	}
}

1;
