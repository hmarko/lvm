package Pelephone::System::Debug;

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
	@EXPORT      = qw(&Debug &SetDebugMode &IsDebugMode);
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

	@EXPORT_OK   = qw($DebugMode);
}

our @EXPORT_OK;
our $DebugMode;
our $DebugFile;

$DebugMode = "No" ;

END { }

#-----------------------------------------------------------------------------#
# This function set the DebugMode parameter.                                  #
# input value are (Yes,yes,Y,y, No,no,N,n) incorrect value will return 1      #
#-----------------------------------------------------------------------------#
sub SetDebugMode($) {
	my $Mode = shift ;
	chomp $Mode ;
	if ($Mode eq "Yes" || $Mode eq "yes" || $Mode eq "Y" || $Mode eq "y") {
		$DebugFile = $main::LogsDir . "/" . $0 . "_" . $$ . ".debug" ;
		print "The Debug info is in the file : $DebugFile\n" ;
		$DebugMode = "Yes" ;
	}elsif ($Mode eq "No" || $Mode eq "no" || $Mode eq "N" || $Mode eq "n") {
		$DebugMode = "No" ;
	}else{
		return 1 ;
	}
	return 0 ;
}
#-----------------------------------------------------------------------------#
# This function check if the system run in DebugMode.                         #
#-----------------------------------------------------------------------------#
sub IsDebugMode() {
	if ($DebugMode eq "Yes") {  return 1 ;  }
	else                     {  return 0 ;  }
}
#-----------------------------------------------------------------------------#
# This function display debug message !                                       #
#-----------------------------------------------------------------------------#
sub Debug($$) {
	my $SubName = shift ;		chomp ($SubName) ;
	my $Message = shift ;		chomp ($Message) ;
	my $dbgmsg = "[Debug] $SubName" . ": ";
	if (IsDebugMode()){		
		open (DBG, ">>$DebugFile") || die "Can not open Debug file $DebugFile\n" ;
		print DBG "$dbgmsg $Message\n"  ;	
		close DBG ;
	}
}

1;
