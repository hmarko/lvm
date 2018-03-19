#!/usr/bin/perl

use English '-no_match_vars';
use Getopt::Std ;
use Sys::Hostname;
use File::Basename;

use lib '../ReplicManDev';
use Pelephone::User ;
use Pelephone::Logger ;
use Pelephone::System ;
use Pelephone::Netapp;

use Pelephone::StepDriver ;

%WorkingFiles = () ;
%GParam = () ;
$OK = "Finished O.K." ;
$| = 1 ;

our $runserver =`hostname` ;


###############################################################################
#    Functions																  #
###############################################################################
sub ReadParamFile() {
#-----------------------------------------------------------------------------#
# Read the Parameters file and get only the Relevant Group information        #
#-----------------------------------------------------------------------------#
	my %Params = () ;
	sub GetSection($) {
		my $SectionName = shift ;	chomp $SectionName ;
		my $FLAG = 0 ;
		$Params{"GROUP_NAME"} = $SectionName ;
		open (INPUT,"<$ParamFile") || 
			die "Parameters File ($ParamFile) can not be open !" ;
		while (my $line = <INPUT>) {
			chomp $line ;
			if ($line =~ /<\/GROUP_NAME>/ && $FLAG == 1) { 
				close (INPUT) ;
				return %Params ;
			}
			if ($FLAG == 1) {
					my $var = (split (">", $line))[0] ;
					$var =~ s/\t<//g ;
					my $value = $line ;
					$value =~ s/\t<$var>//g;			$value =~ s/<\/$var>//g;
					if ($SectionName == /default/ )	{	$Params{$var} = $value ;	}
					elsif (exists $Params{$var})	{	$Params{$var} = $value ;	}
						else {	Exit("ERROR: Parameter $var is InValid !", 1) ;		}
			}
			if ( $line =~ /<GROUP_NAME value=\"$SectionName\">/ ) {	$FLAG = 1 ; }
		}
		close (INPUT) ;
		Exit("ERROR: No Group Named $GROUP_NAME In The prm File", 1) ;
	}

	%Param = GetSection ("default") ;
	%Param = GetSection ($GROUP_NAME) ;
	
	$CMD = "" ;
	return %Param ;
}

sub ReadGlobalParameters() {
#-----------------------------------------------------------------------------#
# add filename to the filenames list !                                        #
#-----------------------------------------------------------------------------#
	open (INPUT,"<$ConfigFile") || 
		die "Configuration File ($ConfigFile) can not be open !" ;
	while (my $line = <INPUT>) {
		chomp $line ;
		if (( $line !~ /^#/ ) && ( $line !~ /^;/ )){ 
			my ($Parameter, $Value) = (split ('=', $line))[0,1] ;
			$GParam{$Parameter} = $Value ;
		}
	}
	close (INPUT) ;
}

sub Opc_Message($$) {
#-----------------------------------------------------------------------------#
# Open-View Message To The ITO !                                              #
#-----------------------------------------------------------------------------#
	$OpcMsgCounter++ ;
	Info("OPC message counter is $OpcMsgCounter") ;
	`echo $OpcMsgCounter > $OpcCounterFile` ;
	
	if ( $OpcMsgCounter gt $opcMsgLimit ) {    #send OpcMsg only on continous errors
		my $Text_Message = shift ;		chomp $Text_Message ;
		my $sev = shift ;				chomp $sev ;
		my $OPCMSG = "/opt/OV/bin/OpC/opcmsg " ;
		my $PARAM = "" ;
		$PARAM .= "severity=$sev " ;
		$PARAM .= "application=ArchSeqCopy " ;
		$PARAM .= "object=$Hostname " ;
		$PARAM .= "msg_text=\"$Text_Message\" " ;
		$PARAM .= "msg_grp=ArchSeqCopy " ;
		###system ("$OPCMSG $PARAM") ;
	}
}

#-----------------------------------------------------------------------------#
# Display the Usage Command                                                   #
#-----------------------------------------------------------------------------#
sub HELP_MESSAGE() {
	system ("cat $HelpFile") ;
}

sub trap_signals {
#-----------------------------------------------------------------------------#
# Declare the SIG trap interrupt procedure !                                  #
#-----------------------------------------------------------------------------#
	$SIG{'HUP' } = 'interrupt';
	$SIG{'INT' } = 'interrupt';  
	$SIG{'QUIT'} = 'interrupt';
	$SIG{'TERM'} = 'interrupt';
	$SIG{'ALRM'} = 'timeout' ;
}

#-----------------------------------------------------------------------------#
# the exit procedure in case of interrupt !                                   #
#-----------------------------------------------------------------------------#
sub interrupt {
	Exit("The SnapCreator.pl was killed ! his PID was $$", 1);
}

#-----------------------------------------------------------------------------#
# the exit procedure in case of timeout !                                     #
#-----------------------------------------------------------------------------#
sub timeout {
		Exit("Command running for too long. exiting \n",1);
}

sub Exit_With_Opc($$) {
#-----------------------------------------------------------------------------#
# sends an OPC msg and exits 	                                              #
#-----------------------------------------------------------------------------#
    my $Msg = shift ;               chomp ($Msg) ;
	$Msg = $GROUP_NAME . ": " . $Msg ; 
    my $ExitCode = shift ;  chomp ($ExitCode) ;
	Opc_Message($Msg,$DefaultSeverity) ;
	system ("rm $Pelephone::StepDriver::LOCK_FILE") ;
	Exit($Msg,$ExitCode);
}

sub checkLock() {
	my $LockFile = $LogsDir . "/" .  $GROUP_NAME . ".lock";
	
	print "Checking $LockFile\n";
	# Check if LOCK exists
	if (-e $LockFile) { # File exists
		# Check if proccess is running
		open LOCKF , "<$LockFile" or die ("Cannot open LOCK file $LockFile");
		while (my $pid = <LOCKF>) {
			my $rt = 1;
			$pid =~ m/([0-9]+)/;
			$pid == $1; chomp $pid;
			print "Checking PID $pid\n";
			$rt = system("ps -e | grep -v grep | grep $pid | grep SnapCreator.pl");
			print "rt is $rt\n";
			chomp $rt;
			if ( $rt eq 0 ) { # Procces is running
				Exit ("PID $pid is Running - I have to exit", 1) ;
			}else{
				# Create Lock file
				close (LOCKF);
				open LOCKF , ">" , "$LockFile" or die ("Cannot open LOCK file $LockFile");
				print LOCKF $$;
				close (LOCKF);
			}
		}
	}
	else { #LOCK does not exists
		# Create Lock file
		open LOCKF , ">" , "$LockFile" or die ("Cannot open LOCK file $LockFile");
		print LOCKF $$;
		close (LOCKF);
	}
}

sub UpDB() {
	if ( $GroupParams{"UP_DB_COMMAND"} ne "no" ) { 
		my $mcmd = "$GroupParams{\"UP_DB_COMMAND\"}";
		Info ("Trying to Start DB with \"$mcmd\" on $GroupParams{\"TARGET_HOST\"}");
		if ( RunProgram($GroupParams{"TARGET_HOST"}, $mcmd) ne 0 ) {
			Exit("Error: Cannot start DB with $mcmd - I have to exit",1);
		}
	}
	else {
		Info ("No UP_DB_COMMAND configured for this group ");
	}
}

sub DownDB() {
	if ( $GroupParams{"DOWN_DB_COMMAND"} ne "no" ) { 
		my $mcmd = "$GroupParams{\"DOWN_DB_COMMAND\"}";
		Info ("Trying to Stop DB with \"$mcmd\" on $GroupParams{\"TARGET_HOST\"}");
		if ( RunProgram($GroupParams{"TARGET_HOST"}, $mcmd) ne 0 ) {
			Exit("Error: Cannot stop DB with $mcmd - I have to exit",1);
		}
	}
	else {
		Info ("No DOWN_DB_COMMAND configured for this group ");
	}
}

sub StartDGRecover() {
	if ( $GroupParams{"START_DG_COMMAND"} ne "no" ) { 
		my $mcmd = "$GroupParams{\"START_DG_COMMAND\"}";
		Info ("Trying to Start DG Recover with \"$mcmd\" on $GroupParams{\"TARGET_HOST\"}");
		if ( RunProgram($GroupParams{"TARGET_HOST"}, $mcmd) ne 0 ) {
			Exit("Error: Cannot Start DG recover with $mcmd - I have to exit",1);
		}
	}
	else {
		Info ("No START_DG_COMMAND configured for this group ");
	}
}

sub StopDGRecover() {
	if ( $GroupParams{"STOP_DG_COMMAND"} ne "no" ) { 
		my $mcmd = "$GroupParams{\"STOP_DG_COMMAND\"}";
		Info ("Trying to Stop DG Recover with \"$mcmd\" on $GroupParams{\"TARGET_HOST\"}");
		if ( RunProgram($GroupParams{"TARGET_HOST"}, $mcmd) ne 0 ) {
			Exit("Error: Cannot stop DG Recover with $mcmd - I have to exit",1);
		}
	}
	else {
		Info ("No STOP_DG_COMMAND configured for this group ");
	}
}

sub GenetalInfo() {
	Info ("SnapCreator");
}

#########################################
# XIV Parts
sub XivSnapCreate($$$) {
	my $xiv = shift;		chomp $xiv;
	my $src_volume = shift;	chomp $src_volume;
	my $tgt_volume = shift;	chomp $tgt_volume;
	
	Info ("Going to Create a Snapshot from \"$src_volume\" to \"$tgt_volume\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv snapshot_create vol=$src_volume name=$tgt_volume | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivSnapDuplicate($$$) {
	my $xiv = shift;		chomp $xiv;
	my $src_snap = shift;	chomp $src_snap;
	my $tgt_snap = shift;	chomp $tgt_snap;
	
	Info ("Going to Duplicate a Snapshot from \"$src_snap\" to \"$tgt_snap\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv snapshot_duplicate snapshot=$src_snap name=$tgt_snap | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivCgSnapCreate($$$) {
	my $xiv = shift;		chomp $xiv;
	my $src_cg = shift;	chomp $src_cg;
	my $tgt_cg = shift;	chomp $tgt_cg;
	
	Info ("Going to Create a CG Snapshot from \"$src_cg\" to \"$tgt_cg\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv cg_snapshots_create cg=$src_cg snap_group=$tgt_cg | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivCgSnapDuplicate($$$) {
	my $xiv = shift;		chomp $xiv;
	my $src_cg = shift;	chomp $src_cg;
	my $tgt_cg = shift;	chomp $tgt_cg;
	
	Info ("Going to Duplicate a CG Snapshot from \"$src_cg\" to \"$tgt_cg\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv snap_group_duplicate snap_group=$src_cg new_snap_group=$tgt_cg | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub CountVolSnapshots($$) {
	my $xiv = shift;		chomp $xiv;
	my $vol = shift;	chomp $vol;
	
	my $snapshots_number = `xcli -c $xiv snapshot_list vol=$vol -t name | grep _SnapC_ | wc -l ` ;
	chomp $snapshots_number;
	return $snapshots_number;
}

sub CountCGSnapshots($$) {
	my $xiv = shift;		chomp $xiv;
	my $cg = shift;	chomp $cg;
	
	my $snapshots_number = `xcli -c $xiv snap_group_list cg=$cg -t name | grep _SnapC_ | wc -l ` ;
	chomp $snapshots_number;
	return $snapshots_number;
}

sub GetLastVolSnapshot($$) {
	my $xiv = shift;		chomp $xiv;
	my $vol = shift;	chomp $vol;
	
	my $result = `xcli -c $xiv snapshot_list vol=$vol -t name | grep _SnapC_ | head -1` ;
	chomp $result;
	return $result;
}

sub GetLastCGSnapshot($$) {
	my $xiv = shift;		chomp $xiv;
	my $cg = shift;	chomp $cg;
	
	my $result = `xcli -c $xiv snap_group_list cg=$cg -t name | grep _SnapC_ |  head -1` ;
	chomp $result;
	return $result;
}

sub XivVolDelete($$) {
	my $xiv = shift ; 		chomp $xiv ;
	my $volume = shift ; 	chomp $volume ;
	
	Info ("Going to Delete the snapshot \"$volume\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv vol_delete vol=$volume -y | grep -e \"Command executed successfully\" -e \"Volume name does not exist\"" ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivSnapGroupDelete($$) {
	my $xiv = shift;		chomp $xiv;
	my $sg_name = shift;	chomp $sg_name;
	
	Info ("Going to Delete the Snapshot Group \"$sg_name\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv snap_group_delete snap_group=$sg_name | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;	
}

sub GetSvcStoppedCG($$) {
	my $svc = shift;		chomp $svc;
	my $all_cgs = shift;	chomp $all_cgs;
	
	my  $result = `ssh superuser\@$svc "lsfcconsistgrp -nohdr" | grep $all_cgs | grep stopped | head -1 | awk \'{print\$2}\'`;

	chomp $result;
	return $result;
}

sub StartSvcCG($$) {
	my $svc = shift;		chomp $svc;
	my $cg = shift;	chomp $cg;
	
	my  $result = `ssh superuser\@$svc startfcconsistgrp -prep $cg`;
	if ( $? == 0 ){ 
		chomp $result;
		return $result;
	} else {
		Exit("Error: Cannot start the cg $cg on $svc",1);
	}

}

sub StopSvcCG($$) {
	my $svc = shift;		chomp $svc;
	my $cg = shift;	chomp $cg;
	
	my  $result = `ssh superuser\@$svc stopfcconsistgrp $cg`;
	if ( $? == 0 ){ 
		chomp $result;
		return $result;
	} else {
		Exit("Error: Cannot stop the cg $cg on $svc",1);
	}

}

sub CheckSvcCGisCopying($$) {
	my $svc = shift;		chomp $svc;
	my $cg = shift;	chomp $cg;
	
	my  $result = `ssh superuser\@$svc "lsfcconsistgrp $cg" | grep -w ^status | grep copying | awk \'{print\$NF}\'`;
	chomp $result;
	if ( $result eq "copying" ) { 
		return 0;
	} else {
		return 1;
	}
}

sub CheckSvcCGisStopped($$) {
	my $svc = shift;		chomp $svc;
	my $cg = shift;	chomp $cg;
	
	my  $result = `ssh superuser\@$svc "lsfcconsistgrp $cg" | grep -w ^status | grep stopped | awk \'{print\$NF}\'`;
	chomp $result;
	if ( $result eq "stopped" ) { 
		return 0;
	} else {
		return 1;
	}
}

sub GetSvcCGLastSnap($$) {
	my $svc = shift;		chomp $svc;
	my $all_cgs = shift;	chomp $all_cgs;
	
	my  $result = `ssh superuser\@$svc "lsfcconsistgrp -nohdr" | grep $all_cgs | grep -w copying | awk \'{print \$NF\" \"\$2}\' | sort -n| head -1 | awk \'{print \$2}\'`;
	chomp $result;
	if ( $result eq "" ) { 
		Exit("Error: Cant find a cg to snapshot - Check if the CG in the group file is correct - I have to exit",1);
	} else {
		return $result;
	}
}


#########################################
sub CreateBackupPointXIV() {
	my $snapshot_to_delete;
	my $snapshot_count;
	
	if ( $GroupParams{XIV_CG} eq "no" ) { # Regular volume
		Info ("-- Single volumes config --");
		# Loop for All the volumes
		for my $i (0 .. $#xiv_src_volume) {
			my $TimeStamp = `date +%d_%m__%H_%M_%S`;
			my $NewSnapName = "$xiv_tgt_volume[$i]_SnapC_$TimeStamp";
			my $xiv_src_volume_last_repl;
			
			# Create the snapshot
			# Check if the snapshot is created on a regular volume (No XIV Mirror) or created to a XIV Mirror Destination volume
			if ( $GroupParams{SNAP_ON_DR} eq "yes" ) { # XIV Mirror Destination volume
				$xiv_src_volume_last_repl = "last-replicated-" . $xiv_src_volume[$i];
				Info ("Going to Duplicate snapshot $xiv_src_volume_last_repl to $NewSnapName");
				if ( XivSnapDuplicate($GroupParams{LOCAL_XIV}, $xiv_src_volume_last_repl, $NewSnapName) ne 0 ) {
					Exit("ERROR: Cannot duplicate snapshot $NewSnapName from \"$xiv_src_volume_last_repl\" on $GroupParams{LOCAL_XIV}", 1);
				}
			}
			else { #regular volume (No XIV Mirror)
				if ( XivSnapCreate($GroupParams{LOCAL_XIV}, $xiv_src_volume[$i], $NewSnapName) ne 0 ) {
					Exit("ERROR: Cannot create snapshot $NewSnapName from \"$xiv_src_volume[$i]\" on $GroupParams{LOCAL_XIV}", 1);
				}
			}
			
			# Delete Older
			$snapshot_count=CountVolSnapshots($GroupParams{LOCAL_XIV},$xiv_src_volume[$i]);
			while ( $snapshot_count > $GroupParams{SNAP_COUNT} ) {
				Info ("There are $snapshot_count snapshtos on volume \"$xiv_src_volume[$i]\"");
				$snapshot_to_delete=GetLastVolSnapshot($GroupParams{LOCAL_XIV},$xiv_src_volume[$i]);
				
				if ( XivVolDelete($GroupParams{LOCAL_XIV}, $snapshot_to_delete) ne 0 ) {
					Exit("ERROR: Cannot delete volume $snapshot_to_delete from $GroupParams{LOCAL_XIV}", 1);
				}
				
				$snapshot_count=CountVolSnapshots($GroupParams{LOCAL_XIV},$xiv_src_volume[$i]);
			}
		}

		
	} else { # CG - Only a single CG is allowed
		Info ("-- CG config --");
		# Loop for all the CG's
		for my $i (0 .. $#xiv_src_volume) {
			my $TimeStamp = `date +%d_%m__%H_%M_%S`;
			my $NewSnapName = "$xiv_tgt_volume[$i]_SnapC_$TimeStamp";
			my $xiv_src_volume_last_repl;
			
			# Create the snapshot
			# Check if the snapshot group is created on a regular CG (No XIV Mirror) or created to a XIV Mirror Destination CG
			if ( $GroupParams{SNAP_ON_DR} eq "yes" ) { # XIV Mirror Destination CG
				$xiv_src_volume_last_repl = "last-replicated-" . $xiv_src_volume[$i];
				Info ("Going to Duplicate snapshot group $xiv_src_volume_last_repl to $NewSnapName");
				if ( XivCgSnapDuplicate($GroupParams{LOCAL_XIV}, $xiv_src_volume_last_repl, $NewSnapName) ne 0 ) {
					Exit("ERROR: Cannot duplicate snapshot $NewSnapName from \"$xiv_src_volume_last_repl\" on $GroupParams{LOCAL_XIV}", 1);
				}
			}
			else {
				if ( XivCgSnapCreate($GroupParams{LOCAL_XIV}, $xiv_src_volume[$i], $NewSnapName) ne 0 ) {
					Exit("ERROR: Cannot create snapshot $NewSnapName from \"$xiv_src_volume[$i]\" on $GroupParams{LOCAL_XIV}", 1);
				}
			}
			
			# Delete Older CG snapshot
			$snapshot_count=CountCGSnapshots($GroupParams{LOCAL_XIV},$xiv_src_volume[$i]);
			Info("There are $snapshot_count on CG \"$xiv_src_volume[$i]\"");
			while ( $snapshot_count > $GroupParams{SNAP_COUNT} ) {
				Info ("There are $snapshot_count snapshtos on CG \"$xiv_src_volume[$i]\"");
				$snapshot_to_delete=GetLastCGSnapshot($GroupParams{LOCAL_XIV},$xiv_src_volume[$i]);
				
				if ( XivSnapGroupDelete($GroupParams{LOCAL_XIV}, $snapshot_to_delete) ne 0 ) {
					Exit("ERROR: Cannot delete volume $snapshot_to_delete from $GroupParams{LOCAL_XIV}", 1);
				}
				
				$snapshot_count=CountCGSnapshots($GroupParams{LOCAL_XIV},$xiv_src_volume[$i]);
			}
		}
	}
}

sub CreateBackupPointSVC() {

	if ( $GroupParams{SVC_CG} eq "no" ) { # Regular volume
	
	} elsif ( $GroupParams{SVC_CG} eq "yes" ) { # CG
		Info ("-- SVC CG config --");
		# Loop for all the CG's
		my $all_cg_names; #For all the grep commands
		for my $i (0 .. $#svc_disk) {
			Info ("CG Name is: $svc_disk[$i]");
			$all_cg_names = $all_cg_names ." -e $svc_disk[$i]";
		}
		
		# Check if there is a stopped  CG - So I can start it
		Info ("Checking if there is a stopped CG - So I can start it");
		my $stopped_cg = GetSvcStoppedCG($GroupParams{SVC_NAME}, $all_cg_names);
		if ( $stopped_cg eq "" ) { # Couldn't find any stopped CG
			Info ("None of the CG\'s are stopped - Moving on");
			# Get the last CG - sorted by time
			my $last_cg=GetSvcCGLastSnap($GroupParams{SVC_NAME},$all_cg_names);
			
			# Stop the last CG
			Info("Going to stop CG named $last_cg on $GroupParams{SVC_NAME}");
			StopSvcCG($GroupParams{SVC_NAME}, $last_cg);
			# Wait untill the group is stopped
			my $status_check_index = 0;
			while ( CheckSvcCGisStopped($GroupParams{SVC_NAME},$last_cg) != 0 ) {
				Info("The CG $last_cg is not in \"stopped\" state yet - I will wait a little bit...");
				sleep 20;
				
				if ($status_check_index > 10) {
					Exit("Error: The cg $last_cg did not changed to \"stopped\" state in the given time - I need to exit",1);
				}
				$status_check_index++;
			}
			Info("The CG named $last_cg on $GroupParams{SVC_NAME} is stopped now");
			
			# Start the CG
			Info("Going to start a CG named $last_cg on $GroupParams{SVC_NAME}");
			StartSvcCG($GroupParams{SVC_NAME},$last_cg);
			
			# Check untill the group changed to copying
			while ( CheckSvcCGisCopying($GroupParams{SVC_NAME},$last_cg) != 0 ) {
				Info("The CG $stopped_cg is not in \"copying\" state yet - I will wait a little bit...");
				sleep 20;
				
				if ($status_check_index > 10) {
					Exit("Error: The cg $stopped_cg did not changed to \"copying\" state in the given time - I need to exit",1);
				}
				$status_check_index++;
			}
			Info("The CG $stopped_cg is in copying state now");
		} else { # I have found a stopped CG 
			Info ("There is a stopped CG - I will start it");
			# Start the stopped CG
			Info("Going to start a CG named $stopped_cg on $GroupParams{SVC_NAME}");
			StartSvcCG($GroupParams{SVC_NAME}, $stopped_cg);
			# Wait untill cg status will become copying
			my $status_check_index = 0;
			while ( CheckSvcCGisCopying($GroupParams{SVC_NAME}, $stopped_cg) != 0 ) {
				Info("The CG $stopped_cg is not in \"copying\" state yet - I will wait a little bit...");
				sleep 20;
				
				if ($status_check_index > 10) {
					Exit("Error: The cg $stopped_cg did not changed to \"copying\" state in the given time - I need to exit",1);
				}
				$status_check_index++;
			}
			Info("The CG $stopped_cg is in copying state now");
		}	
	}
}

#-----------------------------------------------------------------------------#
# Create XIV sync map according to the GroupName !                         #
#-----------------------------------------------------------------------------#
sub CreateXivMap () {
	# XIV - build 2 arrays of the source vol and target vol
	my $line;
	my $index=0;
	
	# Open group file for netapp:volume list
	open (GrpFile, "$GroupsDir/$GROUP_NAME") || die "Cannot open Group file $GroupsDir/$GROUP_NAME\n";
	
	# Fill the 2 arrays with the source vol, and dest vol
	foreach $line (<GrpFile>) {
		chomp $line;
		if ( $line !~ /^#/ ) {
			$xiv_src_volume[$index] = (split (':', $line))[0];
			$xiv_tgt_volume[$index] = (split (':', $line))[1];
			$index += 1;
		}
	}
	
	close GrpFile;
}

#-----------------------------------------------------------------------------#
# Create SVC Array of all the Volumes or CG's
#-----------------------------------------------------------------------------#
sub CreateSVCMap () {
	# SVC - build an array of all the volumes / CG's
	my $line;
	my $index=0;
	
	# Open group file for netapp:volume list
	open (GrpFile, "$GroupsDir/$GROUP_NAME") || die "Cannot open Group file $GroupsDir/$GROUP_NAME\n";
	
	# Fill the array
	foreach $line (<GrpFile>) {
		chomp $line;
		if ( $line !~ /^#/ ) {
			$svc_disk[$index] = $line;
			$index += 1;
		}
	}
	
	close GrpFile;
}



###############################################################################
#    MAIN																	  #
###############################################################################
system ("clear") ;

trap_signals() ;

# Check if the user is root
MustRunAs("root") ;
MustRunOn($runserver) ;

#-----------------------------------------------------------------------------#
# Global Parameters															  #
#-----------------------------------------------------------------------------#
$DATE = `date +%d.%m.%Y-%H.%M` ;

# Must be define for the StepDriver
$COMMAND_LINE = "$0 @ARGV" ;
SetShellName (basename($0, ".pl")) ;
$RunnigHost = hostname() ;	chomp $RunnigHost ;

# Directory list
$BaseDir = "/usr/" . $RunnigHost . "/SnapCreator" ;
$GroupsDir = $BaseDir . "/var/Groups" ;
$LogsDir =  $BaseDir . "/logs" ;
# The Help file
$HelpFile = $BaseDir . "/" . GetShellName() . ".help" ;
# The Parameters file
$ParamFile = $BaseDir . "/var/" . GetShellName() . ".xml" ;
# The Configuration file
$ConfigFile = $BaseDir . "/var/" . GetShellName() . ".conf" ;

ReadGlobalParameters() ;
SetWorkDir($LogsDir) ;

%GroupParams = () ;

# Check if the parameters file exist !
if (! -f $ParamFile) {	
	Exit_With_Opc ("ERROR: The parameters file ($ParamFile) don't exist !!!", 1) ;
}

# Define StepDriver First and Last steps
SetFirstStep("10");
SetLastStep("80");

# Define initial From and To steps
SetFromStep(GetFirstStep()) ;
SetToStep(GetLastStep()) ;

getopt('g:f:t:hl', \%opts);
foreach $prm (keys %opts) {
	if ($prm eq "h") {		HELP_MESSAGE() ;	exit 0 ;	  }
	if ($prm eq "g") {		$GROUP_NAME = $opts{$prm} ;		  }
	if ($prm eq "f") {		SetFromStep("$opts{$prm}") ;	  }
	if ($prm eq "t") {		SetToStep("$opts{$prm}") ;		  }
}

# Configure to run SSH
if (SetSecureMode("y") eq 1) {
	Exit_With_Opc("ERROR: Cannot Change to SecureMode !!!\n", 1) ;
}

if ( $GROUP_NAME eq "" ) {	
	Exit_With_Opc ("ERROR: Enter Group_Name For The Scp Sequencial Copy Procedure !!", 1) ;
}

%GroupParams = ReadParamFile () ;

Info ("config file is: $ConfigFile" ) ;
Info ("param file is: $ParamFile" ) ;

SetCurrentStep(GetFromStep()) ;

# Create SHELL Lock file
print "Checking LOCK FILE\n";
checkLock();

# DEBUG
Info ("XIV_CG is $GroupParams{XIV_CG}");

AddStep("10", "GenetalInfo", "Welcome");
AddStep("80", "GenetalInfo", "Good Bye");

# Add steps
if ( $GroupParams{"STOP_DG_COMMAND"} ne "no" && $GroupParams{"START_DG_COMMAND"} && $GroupParams{"TARGET_HOST"} ne "NoHost") {
	AddStep("20", "StopDGRecover", "Stop the Dataguard Recover");
	AddStep("70", "StartDGRecover", "Start the Dataguard Recover");
} 
if ( $GroupParams{"DOWN_DB_COMMAND"} ne "no" && $GroupParams{"UP_DB_COMMAND"} ne "no" && $GroupParams{"TARGET_HOST"} ne "NoHost") {
	AddStep("30", "DownDB", "Shutdown the DB");
	AddStep("60", "UpDB", "Startup the DB");
}

if ( $GroupParams{"SVC_NAME"} eq "none" ) { # XIV Config
	# Fills the 2 arrays of XIV  src_vols and tgt_vols in data according the group file
	CreateXivMap () ;
	AddStep("40", "CreateBackupPointXIV", "Create the backup copy");
} else { # XIV Config
	# Fill the SVC array of all the volumes or CG's
	CreateSVCMap () ;
	AddStep("40", "CreateBackupPointSVC", "Create the backup copy");
}


# Running the actual steps
TS_Init("$GROUP_NAME") ;
exit 0;