package Pelephone::Storage;  

use strict;
use warnings;
use Pelephone::System ;

$| = 1 ;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw(&DGExist &GetBCV_Devices &Get_Master_Device_Group
					  &MoveDevices &GetDGStatus &GetDGStatusConsistent &GetDGDiffrence &GetDGTotalDiff
					  &GetDGStatusSyncinprog &GetDGSrdfMode &SetDGSrdfModeADC &SetDGStatusEnabled &GetDGStatusSplit
					  &SplitSrdfaDG &SplitSrdfsDG &SplitCloneDG &TerminateCloneDG &CreateCloneDG &ReCreateCloneDG
					  &EstSrdfDG &SetDGSrdfModeAsync &GetDGStatusCOW &GetDGStatusCreated &TerminateSnapDG &CreateSnapDG
					  &SplitSnapDG &GetDGStatusEnabled &SetDGStatusDisabled &SetDGSrdfModeSync);
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK   = qw($SYMDG $SYMLD $SYMRDF);
}

our @EXPORT_OK;

our $SYMDG ;
our $SYMLD ;
our $SYMRDF ;

our $SYMCLI_DIR ;

$SYMCLI_DIR = "/usr/symcli/bin" ;

$SYMDG  = $SYMCLI_DIR . "/symdg" ;
$SYMLD  = $SYMCLI_DIR . "/symld" ;
$SYMRDF = $SYMCLI_DIR . "/symrdf" ;

our %SymDGValidStatus ;

$SymDGValidStatus{"Split"} = 0 ;
$SymDGValidStatus{"SyncInProg"} = 0 ;
$SymDGValidStatus{"Synchronized"} = 0 ;

END { }       # module clean-up code here (global destructor)

#-----------------------------------------------------------------------------#
# This function accept DeviceGroupName & HostName, and check if the           #
# DeviceGroupName exist on the HostName.                                      #
#-----------------------------------------------------------------------------#
sub DGExist($$) {
	my $GroupName = shift ;		chomp $GroupName ;
	my $Host = shift ;			chomp $Host ;
	my $cmd = "$SYMDG list | grep  $GroupName > /dev/null 2>&1" ;
	RunProgram($Host, "$cmd") ;
	return $? ;
}
sub GetBCV_Devices($$) {
	my $Group = shift ;		chomp $Group ;
	my $Host = shift ;		chomp $Host ;
	my $cmd = "$SYMDG list | grep $Group | awk '{print \$7}'" ;
	RunProgram($Host, "$cmd") ;
	my @Result = GetCommandResult() ;
	return $Result[0] ;
}
sub Get_Master_Device_Group($$$) {
	my $Group = shift ;		chomp $Group ;
	my $Host = shift ;		chomp $Host ;
	my $Prefix = shift ;	chomp $Prefix ;
	my $cmd = "$SYMDG list | grep $Prefix | awk '{print \$1,\$5}' | grep  -v \" 0\" | awk '{print \$1}'" ;
	RunProgram($Host, "$cmd") ;
	my @Result = GetCommandResult() ;
	return $Result[0] ;
}
sub MoveDevices($$$) {
	my $FromGroup = shift ;		chomp $FromGroup ;
	my $ToGroup = shift ;		chomp $ToGroup ;
	my $Host = shift ;			chomp $Host ;
	my $cmd = "$SYMLD -g $FromGroup moveall $ToGroup" ;
	ReTry ($Host, "$cmd") ;
	return $? ;
}
sub GetDGStatus($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd query" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	my @Res = GetCommandResult() ;
	my $TotalDevs = 0 ;
	my $TotalPrecent = 0 ;
	$SymDGValidStatus{"Split"} = 0 ;
	$SymDGValidStatus{"SyncInProg"} = 0 ;
	$SymDGValidStatus{"Synchronized"} = 0 ;
	$SymDGValidStatus{"Copied"} = 0 ;
	$SymDGValidStatus{"PreCopy"} = 0 ;
	$SymDGValidStatus{"Recreated"} = 0 ;
	$SymDGValidStatus{"Consistent"} = 0 ;
	foreach my $line (@Res) {
		if ($line =~ /^N\/A/) {
			$TotalDevs ++ ;
			my ($data, $type) = (split ('\s+', $line))[-1,-2] ;
			if ( $GroupCmd =~ /symclone/ ) {
				$SymDGValidStatus{"$type"} ++ ;
				$TotalPrecent = $TotalPrecent + $data ;
			} else {
				if (exists $SymDGValidStatus{"$data"}) {
					$SymDGValidStatus{"$data"} ++ ;
				}else{
					print "There is problem with the group status !!!\n" ;
					exit 1 ;
				}
			}
		}
	}
	if ( $GroupCmd =~ /symclone/ ) {
		my $Prec = $TotalPrecent / $TotalDevs ;
		print "======= $Prec ====== $TotalDevs ====== $SymDGValidStatus{\"Copied\"} ======$SymDGValidStatus{\"PreCopy\"} ==\n" ;
		if ( $Prec == 100 ) {
			if ( $SymDGValidStatus{"Copied"} == $TotalDevs) { 
				return 1 ; # Split Mode
			}else{
				return 2 ; # Synchronized Mode
			}  
		}
		if ( $Prec > 95 )   {  return 2 ; }  # Synchronized Mode
		if ( $Prec < 95 )   {  return 3 ; }  # SyncInProg Mode
	} else { #SRDF
		if ($SymDGValidStatus{"Split"} == $TotalDevs){
			return 1 ; # Split Mode
		}
		if ($SymDGValidStatus{"Synchronized"} == $TotalDevs){
			return 2 ; # Synchronized Mode
		}
		if ($SymDGValidStatus{"Consistent"} == $TotalDevs){
			return 2; # ASYNC Synchronized Mode
		}
		if (($SymDGValidStatus{"SyncInProg"} + $SymDGValidStatus{"Synchronized"}) == $TotalDevs){
			return 3 ;# SyncInProg Mode
		}
		return 9 ;                                                                                                # Invalid Mode
	}
}
sub GetDGStatusConsistent($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd verify -consistent" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}
sub GetDGStatusSyncinprog($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd verify -syncinprog" ;
	my $ExitCode = RunProgramQuiet ($main::RunnigHost, "$cmd") ;
	# 27 - Some of the devices are in SyncInProg
	# 28 - NONE of the devices is in SyncInProg
	if ( $ExitCode == 27 ){
		return 0;
	}
	# If All of the devices in SyncInProg -> RT=0
	return $ExitCode;
}

sub GetDGStatusEnabled($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd verify -enabled" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub GetDGDiffrence($$) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $Diffrence = shift ; 		chomp $Diffrence ;
	my $cmd = $GroupCmd . " query | grep MB | awk \'{print\$2+\$3}\'| awk -F. \'{print\$1}\'" ;
	my $ExitCode = RunProgramQuiet ($main::RunnigHost, "$cmd") ;
	my @Res = GetCommandResult() ;
	
	foreach my $line (@Res) {
		chomp $line ;
		if ($line > $Diffrence) {
			print "There are still $line MBs to SYNC... Waiting untill $Diffrence MBs";
			# Check if Group continues to progress...
			
			return 1;
		}
		else {
			return 2; # Have to use Exit Code 2 for Successefull :(
		}
	}
	# Not supposed to get here...
	return 9;
}

# This function queries the SRDF group and sums the total Invalid tracks to sync in MBs
# The program returns the MBs left to syncronize
sub GetDGTotalDiff($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd = $GroupCmd . " query | grep MB | awk \'{print\$2+\$3}\'| awk -F. \'{print\$1}\'" ;
	my $ExitCode = RunProgramQuiet ($main::RunnigHost, "$cmd") ;
	my @Res = GetCommandResult() ;
	
	foreach my $line (@Res) {
		chomp $line ;
		return $line;
	}
}

# This function queries the SRDF group and check what MODE is configured
# The Possible values are: C = Adaptive Copy -> RT=1, A = Async -> RT=2, S = Sync -> RT 3.
sub GetDGSrdfMode($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd = $GroupCmd . " query | grep -e \^N\/A -e \^\/dev\/ | awk \'{print\$11}\' | head -1";
	my $ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	my @Res = GetCommandResult() ;
	
	foreach my $line (@Res) {
		chomp $line ;
		
		# Adaptive Copy SRDF
		if ($line =~ m/^C/) {
			return 1;
		}
		
		# Async SRDF
		if ($line =~ m/^A/) {
			return 2;
		}
		
		# Sync SRDF
		if ($line =~ m/^S/) {
			return 3
		}
	}
	# Not supposed to get here...
	return 9;
	
}

sub SetDGSrdfModeADC($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd set mode acp_disk -nop -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub SetDGSrdfModeAsync($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd set mode async -nop -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub SetDGSrdfModeSync($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd set mode sync -nop -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub SetDGStatusEnabled($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd enable -nop -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub SetDGStatusDisabled($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd disable -nop -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub GetDGStatusSplit($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd verify -split" ;
	my $ExitCode = RunProgramQuiet ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub GetDGStatusCOW($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd verify -copyonwrite" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub GetDGStatusCreated($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd verify -created" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub SplitSrdfaDG($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd split -force -nop -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub SplitSrdfsDG($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd split -nop -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}


sub SplitCloneDG($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd activate -noprompt -c 20 -i 180" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub SplitSnapDG($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd activate -noprompt -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub TerminateCloneDG($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd terminate -noprompt -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub TerminateSnapDG($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd terminate -noprompt -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub CreateCloneDG($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd create -differential -precopy -noprompt -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub CreateSnapDG($$) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $SVP = shift; chomp $SVP;
	my $cmd="$GroupCmd create -svp $SVP -noprompt -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub ReCreateCloneDG($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd recreate -precopy -noprompt -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub EstSrdfDG($) {
	my $GroupCmd = shift ;			chomp $GroupCmd ;
	my $cmd="$GroupCmd establish -noprompt -c 5 -i 120" ;
	my $ExitCode = RunProgram ($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

#-----------------------------------------------------------------------------#
# The Main package Section!
#

1;
 
