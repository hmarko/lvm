package Pelephone::Logger;

use strict;
use warnings;

$| = 1 ;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw(&TimeStamp &Init &Close &Info &Exit &Banner &PlainPrint);
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK   = qw();
}

our @EXPORT_OK;

our $PID ;
our $LogFileName  ;

$PID = $$ ;
$LogFileName = "/tmp/Logger.$PID.log" ;

END { }       # module clean-up code here (global destructor)

#-----------------------------------------------------------------------------#
# This function return the TimeStamp for Logging in file, in the format :     #
#      [DD/MM/YYYY HH:MM:SS] for example : [23/10/2005 17:55:39]              #
#-----------------------------------------------------------------------------#
sub TimeStamp() {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900 ;
	$mday = sprintf("%02d", $mday);
	$mon  = sprintf("%02d", $mon);
	$hour = sprintf("%02d", $hour);
	$min  = sprintf("%02d", $min);
	$sec  = sprintf("%02d", $sec);
	$mon++ ;
	my $Date = "[$mday/$mon/$year $hour:$min:$sec]" ;
	return $Date ;
}
#-----------------------------------------------------------------------------#
# This function Open the LogFile.                                             #
#      The LogFile parameter is : MUST                                        #
#-----------------------------------------------------------------------------#
sub OpenLogFile () {
	open (LOG_FILE, ">>$LogFileName") || die "Can not Open Log File \"$LogFileName\"\n" ;
}

sub Init($) {
	my $LogFile = shift ;	chomp $LogFile ;
	$LogFileName = "$LogFile" ;
	OpenLogFile() ;
}
#-----------------------------------------------------------------------------#
# This function Close the LogFile.                                            #
#-----------------------------------------------------------------------------#
sub Close() {
	close LOG_FILE ;
}
#-----------------------------------------------------------------------------#
# This function Log Info Message to the Log File (after clearing all \n)      #
# & display the Message on the screen                                         #
#-----------------------------------------------------------------------------#
sub Info($) {
	my $Msg = shift ;	chomp $Msg ;
	my $Ts = &TimeStamp() ;
	print "$Msg\n" ;
	$Msg =~ s/\n//g ;
	OpenLogFile() ;
	print LOG_FILE "$Ts : $Msg\n" ;
	Close() ;
}
#-----------------------------------------------------------------------------#
# This function Log Info Message to the Log File (after clearing all \n)      #
# & display the Message on the screen                                         #
#-----------------------------------------------------------------------------#
sub PlainPrint($) {
	my $Msg = shift ;	chomp $Msg ;
	print "$Msg\n" ;
	OpenLogFile() ;
	print LOG_FILE "$Msg\n" ;
	Close() ;
}
#-----------------------------------------------------------------------------#
# This function Log Info Message to the Log File (after clearing all \n),     #
# display the Message on the screen & exit the program with Given ExiteCode   #
#-----------------------------------------------------------------------------#
sub Exit($$) {
	my $Msg = shift ;		chomp ($Msg) ;
	my $ExitCode = shift ;	chomp ($ExitCode) ;
	&Info("$Msg") ;
	exit $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function print Banner to  the LogFile                                  #
#-----------------------------------------------------------------------------#
sub Banner($) {
	my $Text = shift ;	chomp $Text ;
	OpenLogFile() ;
	print LOG_FILE "\n" ;
	my @Res = `banner "$Text"` ;
	print LOG_FILE @Res ;
	Close() ;
}
#-----------------------------------------------------------------------------#
# The Main package Section!
#
	$| = 1 ;
	&Init ($LogFileName) ;

1;
