package Pelephone::OracleASM;  

use strict;
use warnings;
use Pelephone::Logger;
use Pelephone::System;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.01;

	@ISA         = qw(Exporter);
	@EXPORT      = qw(&GetDBStatus &GetASMStatus &GetListenerStatus &GetOracleVersion &RunSqlCommand
					  &SetTNS &GetTNS &UpDownDB &ShutDownRAC &StartUpRAC &RunRmanCommand &RunASMCommand);
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK   = qw($TNS_Name);
}

our @EXPORT_OK;
our $TNS_Name ;


$TNS_Name = "" ;

END { }       # module clean-up code here (global destructor)

#-----------------------------------------------------------------------------#
# Running Sql's commands                                                      #
#-----------------------------------------------------------------------------#
sub RunSqlCommand($) {
	my $CommandFile = shift ;	chomp $CommandFile ;
	my $tns = GetTNS() ;
	my $full_command_file = "/tmp/oracle_command_file.$$" ;
	open (OUT,">$full_command_file") ;
	print OUT "whenever sqlerror  exit 1 ;\n" ;
	print OUT "set pagesize 0 ;\n" ;
	print OUT "set line 200 ;\n" ;
	print OUT "set feed off ;\n" ;
	print OUT "set verif off ;\n" ;
	print OUT "set echo off ;\n" ;
	print OUT "set head off ;\n" ;
	print OUT "\@$CommandFile\n" ;
	close OUT ;

	my $CMD = "su - oraback -c \"sqlplus -s /\@$tns" ;
	$CMD .= " <<EOF >> /dev/null 2>&1\n" ;
	$CMD .= "\@$full_command_file\n" ;
	$CMD .= "EOF\" 1>/dev/null" ;
	print "The SQL Command is : $CMD \n" ;
#	print "The Sql Command is $CMD\n" ;
#	system ("cat $full_command_file ") ;
#	my $r=<STDIN> ;
	alarm(900);
	system ("$CMD") ;
	alarm(0);
	return $?
}

#-----------------------------------------------------------------------------#
# Running ASM Sql's commands                                                  #
#-----------------------------------------------------------------------------#
sub RunASMCommand($) {
	my $CommandFile = shift ;	chomp $CommandFile ;
	my $tns = GetTNS() ;
	my $full_command_file = "/tmp/oracle_command_file.$$" ;
	open (OUT,">$full_command_file") ;
	print OUT "whenever sqlerror  exit 1 ;\n" ;
	print OUT "set pagesize 0 ;\n" ;
	print OUT "set line 200 ;\n" ;
	print OUT "set feed off ;\n" ;
	print OUT "set verif off ;\n" ;
	print OUT "set echo off ;\n" ;
	print OUT "set head off ;\n" ;
	print OUT "\@$CommandFile\n" ;
	close OUT ;

	my $CMD = "su - oraback -c \"sqlplus -s 'sys/oracle\@$tns as sysdba'" ;
	$CMD .= " <<EOF >> /dev/null 2>&1\n" ;
	$CMD .= "\@$full_command_file\n" ;
	$CMD .= "EOF\" 1>/dev/null" ;
	print "The ASM Command is : $CMD \n" ;
#	print "The ASM Command is $CMD\n" ;
#	system ("cat $full_command_file ") ;
#	my $r=<STDIN> ;
	alarm(900);
	system ("$CMD") ;
	alarm(0);
	return $?
}

#-----------------------------------------------------------------------------#
# Check If DB Is Down Or UP !!                                                #
#-----------------------------------------------------------------------------#
sub GetDBStatus($$) {
	my $DB_Name = shift ;		chomp $DB_Name ;
	my $Host = shift ;			chomp $Host ;

	my $Proc = "ora_.*_" . $DB_Name ;
	my $mcmd = "ps -ef | egrep \"$Proc\" | grep -v grep | wc -l 2>/dev/null" ;
	my $Status = RunProgram ($Host, "$mcmd") ;
	my @status = GetCommandResult() ;

	if ($status[0] > 0) {
		return 1 ;
	}else{
		$Status = GetListenerStatus($Host, $DB_Name) ;
		if ($Status > 0) {
			return 2 ;
		}else{
			return 0 ;
		}
	}
}

#-----------------------------------------------------------------------------#
# Check If ASM DB Is Down Or UP !!                                            #
#-----------------------------------------------------------------------------#
sub GetASMStatus($$) {
	my $DB_Name = shift ;		chomp $DB_Name ;
	my $Host = shift ;			chomp $Host ;

	my $Proc = "asm_.*_" . $DB_Name ;
	my $mcmd = "ps -ef | grep \"$Proc\" | grep -v grep | wc -l 2>/dev/null" ;
	my $Status = RunProgram ($Host, "$mcmd") ;
	my @status = GetCommandResult() ;

	if ($status[0] > 0) {
		return 1 ;
	}else{
		$Status = GetListenerStatus($Host, $DB_Name) ;
		if ($Status > 0) {
			return 2 ;
		}else{
			return 0 ;
		}
	}
}

#-----------------------------------------------------------------------------#
# Check If Listener Is Down Or UP !!                                          #
#-----------------------------------------------------------------------------#
sub GetListenerStatus($$) {
	my $Host = shift ;		chomp $Host ;
	my $DB = shift ;		chomp $DB ;
	my $db = lc ($DB) ;

	my $Proc = "tnslsnr" ;
	my $mcmd = "ps -ef | egrep \"$Proc\" | grep -i $db | grep -v grep | wc -l 2>/dev/null" ;
	my $Status = RunProgram ($Host, "$mcmd") ;
	my @status = GetCommandResult() ;

	if ($status[0] > 0) {
		return 1 ;
	}else{
		return 0 ;
	}
}
#-----------------------------------------------------------------------------#
# Shut Down Date-base  !                                                      #
#-----------------------------------------------------------------------------#
sub UpDownDB($$$$) {
	my $HOST = shift ;		chomp $HOST ;	# The Name of the DataBase Host
	my $DB = shift ;		chomp $DB ;		# The Name of the DataBase
	my $Choice = shift ;	chomp $Choice ;	# kind of shutdown (DOWN/SHUT/ABORT)
	my $Group = shift;		chomp $Group;	# The group on Master (''/<groupname>)

	my $mcmd = "/usr/" . $HOST . "/bin/" . $Choice . "_DB -d " . $DB . " -f /tmp/RCODE" ;
	if ($Group ne " ") {	$mcmd = $mcmd ." -g ${Group}"	}
	#$mcmd = $mcmd . " >> ${LOG_FILE} 2>&1" ;
	my $ExitCode = RunProgram ($HOST, "$mcmd") ;
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# returns the Oracle version  !                                               #
#-----------------------------------------------------------------------------#
sub GetOracleVersion($) {
	my $VERSION_FILE = shift ;		chomp $VERSION_FILE ;
	my $CommandFile = "/tmp/version_cmd.$$" ;

	open (OUT, ">$CommandFile") ;
	print OUT "spool $VERSION_FILE ;\n" ;
	print OUT "select * from v\$version ;\n" ;
	print OUT "spool off ;\n" ;
	print OUT "exit ;\n" ;
	close OUT ;

	RunSqlCommand ($CommandFile) ;

	open (IN, "<$VERSION_FILE") ;
	foreach my $line (<IN>) {
		if ($line =~ /Oracle/) {
			my $Version = (split (' ', $line))[0] ;
			if ($Version =~ /^Oracle$/) {
				$Version = (split (' ', $line))[0] . (split (' ', $line))[2] ;
#				$Version = Check10G();
			}
			close IN ;
			return $Version ;
		}
	}
	close IN ;
	return " " ;
}
#-----------------------------------------------------------------------------#
sub StartUpRAC($) {
	my $HOST = shift ;		chomp $HOST ;	# The Name of the DataBase Host

	my $mcmd = "/etc/init.d/init.crs start ; sleep 180 " ;
	my $ExitCode = RunProgram ($HOST, "$mcmd") ;
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
sub ShutDownRAC($) {
	my $HOST = shift ;		chomp $HOST ;	# The Name of the DataBase Host

	my $mcmd = "/etc/init.d/init.crs stop ; sleep 300 ; ps -ef | grep crsd.bin | grep -v grep | wc -l" ;
	my $ExitCode = RunProgram ($HOST, "$mcmd") ;
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# Set The TNS name                                                            #
#-----------------------------------------------------------------------------#
sub SetTNS($) {
	my $tns = shift ;		chomp $tns ;
	$TNS_Name = $tns ;
}
#-----------------------------------------------------------------------------#
# This function Return the TNS name !                                         #
#-----------------------------------------------------------------------------#
sub GetTNS() {	return $TNS_Name ;	}

#-----------------------------------------------------------------------------#
# This function Checks for Oracle 10G or 10G RAC						      #	
#-----------------------------------------------------------------------------#
# sub Check10G() {
	# my $CommandFile = "/tmp/GetOracle10gRAC.sql" ; 
	# my $OutPutFile = "/tmp/OracleRACValues.out" ; 
	# open (OUT,">$CommandFile") ; 
	 # print OUT "spool $OutPutFile \n" ;
     # print OUT "select value from v\$option where parameter='Real Application Clusters' ;\n" ;
     # print OUT "spool off \n" ;
     # print OUT "exit \n" ;
	# close OUT ;
	# RunSqlCommand ($CommandFile) ;

	# open (IN,"<$OutPutFile") || die ("Can not see if the Oracle is RAC enabled ") ;
	# foreach my $line (<IN>) {
		# if ($line =~ /FALSE/) {
			# # No RAC was found - manual defenition of Oracle Version
			# close IN ;
			# return "Oracle10G";
		# }
		# elsif ($line =~ /TRUE/) { 
			# close IN ;
			# return "Oracle" ; 
		# }
	# } 
#}

#-----------------------------------------------------------------------------#
# Running RMAN commands                                                       #
#-----------------------------------------------------------------------------#
sub RunRmanCommand($$) {
	my $CommandFile = shift ;	chomp $CommandFile ;
	my $Catalog = shift ;	chomp $Catalog ; 
	my $tns = GetTNS() ;
	my $full_command_file = "/tmp/oracle_command_file.$$" ;

	open (OUT,">$full_command_file") ;
	print OUT "set NLS_DATE_FORMAT='ddmmyyyy hh24:mi:ss' ;\n" ;
	print OUT "\@$CommandFile\n" ;
	close OUT ;
	
	my $CMD = "su - oraback -c \"rman target=/\@$tns catalog=$Catalog" ;
	$CMD .= " <<EOF >> /dev/null 2>&1\n" ;
	$CMD .= "\@$full_command_file\n" ;
	$CMD .= "EOF\" 1>/dev/null" ;
	print "The RMAN Command is : $CMD" ;
#	print "The RMAN Command is $CMD\n" ;
#	system ("cat $full_command_file ") ;
#	my $r=<STDIN> ;
	alarm(900);
	system ("$CMD") ;
	alarm(0);
	return $?
}


1;
 
