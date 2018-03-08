#!/usr/bin/perl

use English '-no_match_vars';
use Getopt::Std ;
use Sys::Hostname;
use File::Basename;
use Data::Dumper;

use Pelephone::User ;
use Pelephone::Logger ;
use Pelephone::Oracle ;
use Pelephone::System ;
use Pelephone::System::Debug;

use Pelephone::Storage ;
use Pelephone::Netapp ;
use Pelephone::XIV ;
use Pelephone::StepDriver ;
use Pelephone::SVC ;

$| = 1 ;

%WorkingFiles = () ;
%GParam = () ;
$OK = "Finished O.K." ;

our $runserver = `hostname`;

#-----------------------------------------------------------------------------#
# Open-View Message To The ITO !                                              #
#-----------------------------------------------------------------------------#
sub Opc_Message($$) {
	my $Text_Message = shift ;		chomp $Text_Message ;
	my $sev = shift ;				chomp $sev ;
	my $OPCMSG = "/opt/OV/bin/OpC/opcmsg " ;
	my $PARAM = "" ;
	$PARAM .= "severity=$sev " ;
	$PARAM .= "application=EMC " ;
	$PARAM .= "object=COPY " ;
	$PARAM .= "msg_text=\"$Text_Message\" " ;
	$PARAM .= "msg_grp=$GroupParams{\"MSGRP\"}" ;
#	system ("$OPCMSG $PARAM") ;
}
#-----------------------------------------------------------------------------#
# Declare the SIG trap interrupt procedure !                                  #
#-----------------------------------------------------------------------------#
sub trap_signals {
	$SIG{'HUP' } = 'interrupt';
	$SIG{'INT' } = 'interrupt';  
	$SIG{'QUIT'} = 'interrupt';
	$SIG{'TERM'} = 'interrupt';
	$SIG{'ALRM'} = 'timeout' ;
}
#-----------------------------------------------------------------------------#
# the exit procedure in case of timeout !                                     #
#-----------------------------------------------------------------------------#
sub timeout {
		Debug("timeout","Error: Command running for too long. exiting \n");
		Exit("Command running for too long. exiting \n",12);
}
#-----------------------------------------------------------------------------#
# the exit procedure in case of interrupt !                                   #
#-----------------------------------------------------------------------------#
sub interrupt {
	ClearTempFile() ;
	system ("rm $StepDriver::LOCK_FILE") ;
	Debug("interrupt","Error: The ReplicMan.pl was killed ! his PID was $$ \n");
	Exit("The ReplicMan.pl was killed ! his PID was $$", 1);
}
#-----------------------------------------------------------------------------#
# Display the Usage Command                                                   #
#-----------------------------------------------------------------------------#
sub HELP_MESSAGE() {
	system ("cat $HelpFile") ;
}
#-----------------------------------------------------------------------------#
# Read the Parameters file and get only the Relevant Group information        #
#-----------------------------------------------------------------------------#
sub ReadParamFile() {
	
	our %Params = () ;
	
	sub GetSection($) {
		my $SectionName = shift ;	chomp $SectionName ;
		my $FLAG = 0 ;
		$Params{"GROUP_NAME"} = $SectionName ;
		open (INPUT,"<$ParamFile") || 
			die "Parameters File ($ParamFile) can not be open !" ;
		while (my $line = <INPUT>) {
			chomp $line ;
			$line =~ s/\s*$//;
			if ($line =~ /<\/GROUP_NAME>/ && $FLAG == 1) { 
				close (INPUT) ;
				return %Params ;
			}
			if ($FLAG == 1) {
				my $var = (split (">", $line))[0] ;
				$var =~ s/\t<//g ;
				my $value = $line ;
				$value =~ s/\t<$var>//g;			
				$value =~ s/<\/$var>//g;
				if ($SectionName == /default/ )	{	
					$Params{$var} = $value ;	
				} elsif (exists $Params{$var}) {	
					$Params{$var} = $value ;	
				} else {	
					Exit("\nParameter $var is InValid !", 1) ;		
				}
			}
			if ( $line =~ /<GROUP_NAME value=\"$SectionName\">/ ) {	
				$FLAG = 1 ;
			}
		}
		close (INPUT) ;
		Debug("ReadParamFile","No Group named $GROUP_NAME in the prm file $ParamFile \n");
		Exit ("\nNo Group Named $GROUP_NAME In The prm File", 1) ;
	}

	%Param = GetSection ("default") ;
	%Param = GetSection ($GROUP_NAME) ;
	foreach $key (keys %Param) {
		Debug ("ReadParamFile", "$key=$Param{$key}".'aaa') ;
	}
	$CMD = "" ;
	if ($Param{"MSGRP"} eq "SRDF") {
		$CMD = $GParam{"CLIDIR"} ."/symrdf -RDFG " . $Param{"RA_GRP"};	
	}elsif ($Param{"MSGRP"} eq "TimeFinder") {	
		$CMD = $GParam{"CLIDIR"} ."/symmir" ;
	}elsif ($Param{"MSGRP"} eq "Clone") {
		$CMD = $GParam{"CLIDIR"} ."/symclone" ;
	}elsif ($Param{"MSGRP"} eq "FSCOPY") {
		$CMD = $GParam{"FsCopyCMD"} ;
	}elsif ($Param{"MSGRP"} eq "SYMSNAP") {
		$CMD = $GParam{"CLIDIR"} ."/symsnap" ;
	}elsif ($Param{"MSGRP"} eq "Netapp") {
		$CMD = "Netapp";
	}elsif ($Param{"MSGRP"} eq 'XIV|NetappSAN') {
		$CMD = "XIV for Step 30, NetappSAN for step 60";
	}elsif ($Param{"MSGRP"} eq 'SVC|NetappSAN') {
		$CMD = "SVC for Step 30, NetappSAN for step 60";
	}elsif ($Param{"MSGRP"} eq "NetappSAN") {
		$CMD = "NetappSAN";
	}elsif ($Param{"MSGRP"} eq "XIV") {
		$CMD = "XIV";
	}elsif ($Param{"MSGRP"} eq "SVC") {
		$CMD = "SVC";
	}else {
		Debug("ReadParamFile","The Parameter <MSGRP> can be TimeFinder , SRDF , Clone , SYMSNAP, Netapp, XIV, SVC Only \n");
		Exit ("\nThe Parameter <MSGRP> can be TimeFinder , SRDF , Clone , SYMSNAP, XIV, Netapp, NetappSAN, XIV|NetappSAN, SVC|NetappSAN Only !!",1) ;
	}
	Debug ("ReadParamFile", "The Command is : $CMD") ;

	return %Param ;
}
#-----------------------------------------------------------------------------#
# add filename to the filenames list !                                        #
#-----------------------------------------------------------------------------#
sub ReadGlobalParameters() {
	open (INPUT,"<$ConfigFile") || 
		die "Configuration File ($ConfigFile) can not be open !" ;
	my $line;
	while ($line = <INPUT>) {
		chomp $line ;
		if (( $line !~ /^#/ ) && ( $line !~ /^;/ )){ 
			my ($Parameter, $Value) = (split ('=', $line))[0,1] ;
			$GParam{$Parameter} = $Value if (defined $Parameter) ;
			Debug ("ReadGlobalParameters","The value of $Parameter is: $Value") if (defined $Parameter);
		}
	}
	close (INPUT) ;
}
#----------------------------------------------------------------------------#
#    Check Retern Codes !
#----------------------------------------------------------------------------#
sub Check_Exit($$$) {
	my $Code = shift ;				chomp $Code ;
	my $Subject = shift ;			chomp $Subject ;
	my $HOST = shift ;				chomp $HOST ;

	if ($Code == 0) {
		Info ("\n$Subject On $HOST Finished OK.") ;
	}elsif ($Code == 1) {
		Opc_Message ("$Subject On $HOST - Failed", "critical") ;
		Exit ("\n$Subject On $HOST - Failed Code=$Code!!", 1) ;
	}elsif ($Code == 2) {
		Info ("\n$Subject On $HOST - Failed - Not Critical !!") ;
	}elsif ($Code == 3) {
		Exit ("\n$Subject On $HOST - Failed After 3 Times !!", 1) ;
	}elsif ($Code == 4) {
		Opc_Message ("Problem In Shutting Down The DB On $HOST - Call DBA !!", "critical") ;
		Exit ("\n$Subject On $HOST Failed Code=$Code - Critical - Call The Dba !!", 1) ;
	}elsif ($Code == 100) {
		Info ("\n$Subject On $HOST Finished OK.. Code=$Code") ;
	}elsif ($Code == 127) {
		Exit ("\n$Subject On $HOST - Failed Code=$Code - No Such File Or Directory !!", 1) ;
	}elsif ($Code == 200) {
		Exit ("\n$Subject On $HOST Failed Code=$Code - Call The Dba !!", 1) ;
	}elsif ($Code == 300) {
		Info ("\nUP_LISTENER On $HOST - Failed Code=$Code , (Run UP_LISTENER And Check If It Is UP) !!") ;
		Opc_Message ("Run UP_LISTENER On $HOST NOW !!", "critical") ;
	}elsif ($Code == 400) {
		Exit ("\nSome Of The Arguments Are Send Wrong To UP_DB Script Call The System !! Code=$Code", 1) ;
	}elsif ($Code == 500) {
		Exit ("\nDB On $HOST Is Alredy UP Code=$Code !!", 1) ;
	}elsif ($Code == 600) {
		Exit ("\nUnable To Change Owner Of The Files That Were Copied Code=$Code Call The System !! Code=$Code", 1) ;
	}elsif ($Code == 601) {
		Exit ("\nThe Control File is Missing On $HOST !! Code=$Code", 1) ;
	}elsif ($Code == 602) {
		Exit ("\nThe SCN File is Missing On $HOST !! Code=$Code", 1) ;
	}elsif ($Code == 603) {
		Exit ("\nThe Archive Destination File Missing !! Code=$Code", 1) ;
	}elsif ($Code == 604) {
		Exit ("\nThe Control Destination File Missing !! Code=$Code", 1) ;
	}elsif ($Code == 605) {
		Exit ("\nThe Archive Files are Missing !! Code=$Code", 1) ;
	}elsif ($Code == 606) {
		Exit ("\nUnable To Copy Control File To Destination !! Code=$Code", 1) ;
	}elsif ($Code == 607) {
		Exit ("\nUnable To Copy Archive Files To Destination !! Code=$Code", 1) ;
	}elsif ($Code == 608) {
		Exit ("\nUnable To Recover DB On $HOST !! Code=$Code", 1) ;
	}elsif ($Code == 609) {
		Exit ("\nDwh init Failed on $HOST !! Code=$Code", 1) ;
	}else{
		Exit ("\n$Subject On $HOST Failed - Internal Error !! Code=$Code", 1) ;
	}
}
#-----------------------------------------------------------------------------#
# add filename to the filenames list !                                        #
#-----------------------------------------------------------------------------#
sub AddFile2List ($$) {
	my @Result = ();
	my $FileFrefix = shift ;		chomp ($FileFrefix) ;
	my $FileSerfix = shift ;		chomp ($FileSerfix) ;
	my $FileName = $FileFrefix . "_" . $GROUP_NAME . "." . $FileSerfix ;
	my $FullFileName = $SQLDir . "/" . $FileName ;
	$WorkingFiles{$FileFrefix} =  $FullFileName;
	Debug ("AddFile2List", "The file name is : $FullFileName") ;
}

sub GetInformixLinks() {
	Info ("Getting Informix links on $GroupParams{\"MASTER_HOST\"}") ;
	my $mcmd = "su - informix -c \"/usr/informix/bin/onstat -d\"" ;
	my $status = RunProgram  ("$GroupParams{\"MASTER_HOST\"}", $mcmd) ;
	if ( $status ne 0 ) {
		Debug("GetInformixLinks","Error: Cannot get link list from $GroupParams{\"MASTER_HOST\"} \n");
		Exit ("Can not Get link list from $GroupParams{\"MASTER_HOST\"}", 1) ;
	}

	my %LinkList ;

	my $LinkFileScript = CreateTempFile() ;
	open (OUT, ">$LinkFileScript") ;
	@Result = GetCommandResult() ;
	foreach $line (@Result) {	
		if ($line =~ "PO") {
			$ln = (split (' ',$line))[-1] ;
			print OUT "ls -l $ln | awk '{print \$9\" \"\$NF}'\n" ;
		}
	}
	close OUT ;

	my $SourceFile = $RunnigHost . ":" . $LinkFileScript ;
	my $TargetFile = $GroupParams{"MASTER_HOST"} . ":" . $LinkFileScript ;
	my $result = CopyFile($SourceFile, $TargetFile) ;
	if ( $result == 0 ) {
		my $status = RunProgram  ("$GroupParams{\"MASTER_HOST\"}", "/usr/bin/ksh $LinkFileScript") ;
		if ( $status ne 0 ) {
			Debug("GetInformixLinks","Error: Cannot run Informix link script $LinkFileScript \n");
			Exit ("Can not Get link list from $GroupParams{\"MASTER_HOST\"}", 1) ;
		}
	}

	@Result = GetCommandResult() ;
	foreach $LINE (@Result) {
		($mp,$ln) = (split (' ',$LINE))[0,1] ;
		$LinkList{$ln} = $mp ;
	}
	
	Info ("Getting Informix links on $GroupParams{\"MASTER_HOST\"} DONE !") ;

	return %LinkList ;
}
#-----------------------------------------------------------------------------#
# Create Globals parameters, Depend on the GroupName !                        #
#-----------------------------------------------------------------------------#
sub CreateGlobalParameterse() {

	AddFile2List ('SCN_NUM_BEFOR', 'log') ;
	AddFile2List ('HOT_SCN_AFTER', 'log') ;
	AddFile2List ('SEL_ARCH_LIST', 'log') ;
	AddFile2List ('HOT_SPLIT_STATUS_LOG', 'log') ;
	AddFile2List ('HOT_SPLIT_SQL_END_LOG', 'log') ;
	AddFile2List ('HOT_SPLIT_SQL_BEGIN_LOG', 'log') ;
	AddFile2List ('SEL_CONTROL_FILES', 'log') ;
	AddFile2List ('ALTER_CONTROL_FILE_LOG', 'log') ;
	AddFile2List ('VERSION_FILE', 'log') ;
	AddFile2List ('SWITCH_FILE_LOG', 'log') ;

	AddFile2List ('DB_MODE', 'sql') ;
	AddFile2List ('HOT_SPLIT_SCN', 'sql') ;
	AddFile2List ('HOT_SPLIT_SQL_BEGIN', 'sql') ;
	AddFile2List ('HOT_SPLIT_SQL_END', 'sql') ;
	AddFile2List ('HOT_SPLIT_CTL_PATH', 'sql') ;
	AddFile2List ('HOT_ARCH_LIST_ORACLE8I', 'sql') ;
	AddFile2List ('HOT_ARCH_LIST_ORACLE', 'sql') ;
	AddFile2List ('HOT_ARCH_LIST_ORACLE_RAC', 'sql') ;
	AddFile2List ('ALTER_CONTROL_FILE', 'sql') ;
	AddFile2List ('REPER_BACKUP_MODE', 'sql') ;
	AddFile2List ('ORACLE_VERSION_FILE', 'sql') ;
	AddFile2List ('ALTER_SWITCH_LOGFILE', 'sql') ;
	AddFile2List ('CTL', 'ctl')  ;
	AddFile2List ('REPER_BACKUP_MODE_ALTER', 'ltr')  ;
	AddFile2List ('ORACLE10_VERSION', 'sql') ;
	AddFile2List ('RAC_VALUE', 'log') ;
	
	if ($GroupParams{"DB_TYPE"} eq "ASM") {
		AddFile2List ('ASM_REBALANCE_STOP', 'sql') ;
		AddFile2List ('ASM_REBALANCE_START', 'sql') ;
		AddFile2List ('ASM_REBALANCE_STOP_LOG', 'log') ;
		AddFile2List ('ASM_REBALANCE_START_LOG', 'log') ;
	}
	
	$CommandPrefix = "$CMD -sid " . $GroupParams{"LOCAL_EMC"} . " -file " . $GroupsDir . "/" . $GROUP_NAME ;
}

#-----------------------------------------------------------------------------#
# Create netapp sync map according to the GroupName !                         #
#-----------------------------------------------------------------------------#
sub CreateNetappMap () {
	# Netapp - build 3 arrays of the netapp, source vol and target vol
	if ( $GroupParams{"MSGRP"} eq "Netapp" ) {
		my $line;
		my $index=0;
		
		# Open group file for netapp:volume list
		open (GrpFile, "$GroupsDir/$GROUP_NAME") || die "Cannot open Group file $GroupsDir/$GROUP_NAME\n";
		
		# Fill the 4 arrays with the netapp, vfiler, source vol, and dest vol
		foreach $line (<GrpFile>) {
			chomp $line;
			if ( $line !~ /^#/ ) {
				$netapps[$index] = (split (':', $line))[0];
				$vfilers[$index] = (split (':', $line))[1];
				$src_vols[$index] = (split (':', $line))[2];
				$tgt_vols[$index] = (split (':', $line))[3];
				$index += 1;
			}
		}
		
		close GrpFile;
	}
	
	# NetappSAN - build 6 arrays of the netapp to support lun paths
	if ( $GroupParams{"MSGRP"} eq "NetappSAN" or $MigrationPeriod) {
		my $line;
		my $index=0;
		

		# Open group file for netapp:volume list
		open (GrpFile, "$GroupsDir/$GROUP_NAME") || die "Cannot open Group file $GroupsDir/$GROUP_NAME\n";
		
		# Fill the 6 arrays with the following params:
		#when file-clone - srcsvm:dstsvm:srcvol[/srcqtree],dstvol->dstqtree  (src and dst svm and qtree should be equal)
		#when flex-clone - srcsvm:dstsvm:srcvol[/srcqtree],dstvol->dstflexclone  (need to have snapmirro from src to dst)
		foreach $line (<GrpFile>) {
			chomp $line;
			if ( $line !~ /^#/ ) {
				$netapps[$index] = (split (':', $line))[0];
				$netappd[$index] = (split (':', $line))[1];
				$src_vols[$index] = (split('/',(split (':', $line))[2]))[0];
				$src_path[$index] = (split('/',(split (':', $line))[2]))[1];
				$tgt_vols[$index] = (split('->',(split (':', $line))[3]))[0];
				$tgt_path[$index] = (split('->',(split (':', $line))[3]))[1];
				
				$index += 1;
			}
		}
		
		close GrpFile;
	}	
}

#-----------------------------------------------------------------------------#
# Create XIV sync map according to the GroupName !                         #
#-----------------------------------------------------------------------------#
sub CreateXivMap () {
	# XIV - build 2 arrays of the source vol and target vol
	if ( $GroupParams{"MSGRP"} =~ /XIV/ ) {
		my $line;
		my $index=0;
		
		#if this group been marked with XIV|NetappSAN
		if ($MigrationPeriod) {
			open (GrpFile, "$GroupsDir/$GROUP_NAME") || die "Cannot open Group file $GroupsDir/$GROUP_NAME\n";
		} else {
			open (GrpFile, "$GroupsDir/$GROUP_NAME".'.MigrationToNetapp') || die "Cannot open Group file $GroupsDir/$GROUP_NAME".'.MigrationToNetapp'."\n";
		}
		
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
}
#-----------------------------------------------------------------------------#
# Create SVC Flash-Copy Group Name					                          #
#-----------------------------------------------------------------------------#
sub CreateSVCMap () {
	# SVC
	if ( $GroupParams{"MSGRP"} =~ /SVC/ ) {
		my $line;
		my $index=0;

		#if this group been marked with SVC|NetappSAN
		if ($MigrationPeriod) {
			open (GrpFile, "$GroupsDir/$GROUP_NAME") || die "Cannot open Group file $GroupsDir/$GROUP_NAME\n";
		} else {
			open (GrpFile, "$GroupsDir/$GROUP_NAME".'.MigrationToNetapp') || die "Cannot open Group file $GroupsDir/$GROUP_NAME".'.MigrationToNetapp'."\n";
		}
		
		# Fill the array with FlashCopy Groups
		foreach $line (<GrpFile>) {
			chomp $line;
			if ( $line !~ /^#/ ) {
				$svc_fc_grp[$index] = $line;
				$index += 1;
			}
		}
		
		close GrpFile;
	}
}
#-----------------------------------------------------------------------------#
# Pre/Post Action command for Establish/Split !                               #
#-----------------------------------------------------------------------------#
sub Pre_Post_Command($$) {
	my $Mode1 = shift ; chomp $Mode1 ;
	my $Mode2 = shift ; chomp $Mode2 ;
	my $Param = $Mode1 . "_COND_" . $Mode2 ;
	if ($GroupParams{$Param} ne "") {
		Debug ("Pre_Post_Command", "running --- $GroupParams{$Param}") ;
		my @Commands = split ('&', $GroupParams{$Param}) ;
		foreach $Prog (@Commands) {
			my ($Job, $Host) = (split (':', $Prog))[0,1] ;
			Info ("Runnig $Job on $Host") ;
			my $ExitCode = RunProgram ($Host, $Job) ;
			if ($ExitCode) {
				Debug("Pre_Post_Command","Error: $Job on $Host FAILED - ExitCode = $ExitCode \n");
				Exit ("$Job on $Host FAILED - ExitCode = $ExitCode", $ExitCode) ;
			}
			Info ("Runnig $Job on $Host $OK") ;
		}
	}
}

#-----------------------------------------------------------------------------#
# This function open file for output !                                        #
#-----------------------------------------------------------------------------#
sub OpenFile ($) {
	my $FileName = shift ;  chomp $FileName ;
	Debug ("OpenFile", "Opening $FileName") ;
	open (OUT, ">$FileName") || die "Can not create $FileName\n" ;
}
#-----------------------------------------------------------------------------#
# This function return the currect OS related function !                      #
#-----------------------------------------------------------------------------#
sub BuildFunc($) {
	my $Func = shift ;		chomp $Func ;
	if (($GroupParams{"OS_VERSION"} eq "HP-UX") || ($GroupParams{"OS_VERSION"} eq "Linux")) {
		$Func = \& {"Pelephone::System::HPUX::" . $Func} ;
	} elsif ($GroupParams{"OS_VERSION"} eq "Solaris") {
		$Func = \& {"Pelephone::System::Solaris::" . $Func} ;
	} 
	return $Func ;
}
#-----------------------------------------------------------------------------#
# This function return hash of <MountPoints - FileSystem> list !              #
#-----------------------------------------------------------------------------#
sub GettingMP_List($$) {
	my $Host = shift ;		chomp $Host ; 
	my $FS = shift ;		chomp $FS ; 
	Info ("Getting list of FileSystem...") ;
	my $Func = BuildFunc("GetMPList") ;
	my %MP = &$Func ($Host, $FS); # $FS is actually the VG name
	Info ("Getting list of FileSystem -  $OK") ;
	return %MP ;
}
#-----------------------------------------------------------------------------#
# This function umounts the hash of <MountPoints - FileSystem> list           #
#-----------------------------------------------------------------------------#
sub UmountHost($) {
	my $HostType = shift ;		chomp $HostType ; # Can be TARGET or MASTER
	my $HOST = $HostType . "_HOST" ;
	my $FS = $HostType . "_FILESYSTEM" ;
	Info ("Un-mounting FileSystems on Host $GroupParams{\"$HOST\"}") ;
	my %MP = GettingMP_List($GroupParams{"$HOST"}, $GroupParams{"$FS"}) ;
	SetRetry(1) ;
	foreach $mp (sort {$b cmp $a} (sort {$b cmp $a} keys %MP)) {
		if (IsMount ($GroupParams{"$HOST"}, $mp) eq 0) {
			Info ("Going to UN-mount $mp ...") ;
			ForceUMount ($GroupParams{"$HOST"}, $mp) ;
			if (IsMount ($GroupParams{"$HOST"}, $mp) eq 0) {
				Debug("UmountHost","Error: Cannot Un-Mount $mp on $GroupParams{\"$HOST\"}");
				Exit ("Can not Un-Mount $mp on $GroupParams{\"$HOST\"}", 1) ;
			}
			Info ("$mp is Un-Mounted on $GroupParams{\"$HOST\"}") ;
		}else{
			Info ("$mp is Un-Mounted on $GroupParams{\"$HOST\"}") ;
		}
	}
	Info ("Un-mounting FileSystems on $HostType Host $OK") ;
	SetRetry(3) ;
}
#-----------------------------------------------------------------------------#
# This function umounts the hash of <MountPoints - FileSystem> list           #
# On all of the SERVERS_LIST servers										  #
#-----------------------------------------------------------------------------#
sub UmountNFSHosts($) {
	my $HostType = shift ;		chomp $HostType ; # Can be TARGET or MASTER
	my $FS = $HostType . "_FILESYSTEM" ;
	my @Servers_List = split (':', $GroupParams{"SERVERS_LIST"}) ;
	
	foreach $server (@Servers_List) {
		Info ("Un-mounting FileSystems on Host $server") ;
		my %MP = GettingMP_List($server, $GroupParams{"$FS"}) ;
		SetRetry(1) ;
		foreach $mp (sort {$b cmp $a} (sort {$b cmp $a} keys %MP)) {
			if (IsMount ($server, $mp) eq 0) {
				Info ("Going to UN-mount $mp ...") ;
				if (ForceUMount ($server, $mp) ne 0) {
					Debug("UmountHost","Error: Cannot Un-Mount $mp on $server");
					Exit ("Can not Un-Mount $mp on $server", 1) ;
				}
				if(IsMount ($server, $mp) eq 0){
					Exit("Error: Cannot umount $mp ... I have to exit !",1); 
				}
				Info ("$mp is Un-Mounted on $server") ;
			}else{
				Info ("$mp is Un-Mounted on $server") ;
			}
		Info ("Un-mounting FileSystems on Host $server $OK") ;
		}
	}
	SetRetry(3) ;
}

sub MountHost($) {
	my $HostType = shift ;		chomp $HostType ;  # MASTER / TARGET
	my $HOST = $HostType . "_HOST" ;
	my $FS = $HostType . "_FILESYSTEM" ;
	Info ("Mounting FileSystems on Host $GroupParams{\"$HOST\"}") ;
	my %MP = GettingMP_List($GroupParams{"$HOST"}, $GroupParams{"$FS"}) ;
	SetRetry(1) ;
	foreach $mp (sort {$a cmp $b} keys %MP) {
		if (IsMount ($GroupParams{"$HOST"}, $mp) ne 0) {
			Info ("Going to Mount $mp ...") ;
			my $res = ForceMount ($GroupParams{"$HOST"}, $MP{$mp}) ;
			if ($res ne 0) {
				Debug("MountHost","Error: Cannot mount $mp on $GroupParams{\"$HOST\"} \n");
				Exit ("Can not Mount $mp on $GroupParams{\"$HOST\"}", 1) ;
			}
			Info ("$mp is Mounted on $GroupParams{\"$HOST\"}") ;
		}else{
			Info ("$mp is Mounted on $GroupParams{\"$HOST\"}") ;
		}
	}
	Info ("Mounting FileSystems on Host $GroupParams{\"$HOST\"} $OK") ;
	SetRetry(3) ;
}
#-----------------------------------------------------------------------------#
sub MountTargetHost($) {
	my $HostType = shift ;		chomp $HostType ; # Can be TARGET or MASTER
	my $HOST = $HostType . "_HOST" ;
	my $FS = $HostType . "_FILESYSTEM" ;
	Info ("Mounting FileSystems on Host $GroupParams{\"$HOST\"}") ;
	my %MP = GettingMP_List($GroupParams{"$HOST"}, $GroupParams{"$FS"}) ;
	foreach $mp (sort {$a cmp $b} (sort {$a cmp $b} keys %MP)) {
		Info ("Checking $mp");
		if (IsMount ($GroupParams{"$HOST"}, $mp) ne 0) { # $mp is NOT mounted
			# If this is a Linux - Disable forced full fsck
			if (($GroupParams{"OS_VERSION"} eq "Linux") && ($GroupParams{"MSGRP"} ne "Netapp")) {
				Info ("Running tune2fs on $MP{$mp}");
				if ( Tune2FS($GroupParams{"$HOST"}, $MP{$mp}) ne 0 ) {
					Exit ("ERROR: Cannot tune2fs on $MP{$mp} - I have to exit...",1);
				}
			}
			
			# Run FSCK
			if ($GroupParams{"MSGRP"} ne "Netapp") {
				Info ("Running FSCK on $MP{$mp}");
				SetRetry(3) ;
				if ( FSCK($GroupParams{"$HOST"}, $MP{$mp}) ne 0 ) {
					Exit ("ERROR: FSCK failed on $MP{$mp} - I have to exit...",1);
				}
			}
			
			# Mount
			# This is set because mount command should be run only once
			SetRetry(1) ;
			Info ("Mounting $mp");
			if ( Mount($GroupParams{"$HOST"}, $mp) ne 0 ) {
				Exit ("ERROR: Mount failed on $mp - I have to exit...",1);
			}
		} else { #$mp is Already Mounted
			Info ("$mp is Already Mounted ");
		}
	}
	SetRetry(3) ;

	Info ("Mounting FileSystems on Host $GroupParams{\"$HOST\"} $OK") ;
}
#-----------------------------------------------------------------------------#
sub MountNFSHosts($) {
	my $HostType = shift ;		chomp $HostType ; # Can be TARGET or MASTER
	my $FS = $HostType . "_FILESYSTEM" ;
	my @Servers_List = split (':', $GroupParams{"SERVERS_LIST"}) ;
	
	foreach $server (@Servers_List) {
		Info ("Mounting FileSystems on Host $server") ;
		my %MP = GettingMP_List($server, $GroupParams{"$FS"}) ;
		SetRetry(1) ;
		foreach $mp (sort {$b cmp $a} (sort {$b cmp $a} keys %MP)) {
			Info ("Checking $mp");
			if (IsMount ($server, $mp) ne 0) { # $mp is NOT mounted
				# Mount
				Info ("Mounting $mp");
				if ( Mount($server, $mp) ne 0 ) {
					Exit ("ERROR: Cannot mount $mp on $server - I have to exit...",1);
				}
			} else { #$mp is Already Mounted
				Info ("$mp is Already Mounted on $server");
			}
		}
		Info ("Mounting FileSystems on Host $server $OK") ;
	}
	SetRetry(3) ;
}
#-----------------------------------------------------------------------------#
sub ShutDownDB($) {
	my $HostType = shift ;		chomp $HostType ;  # MASTER / TARGET
	my $HOST = $HostType . "_HOST" ;
	my $FS = $HostType . "_FILESYSTEM" ;
	if ( ($GroupParams{"$HOST"} eq "NoHost") || ($GroupParams{"DATABASE_NAME_MASTER"} eq "NoDb") ) {
		Info ("No Need to shutdown DB - $HostType have No DB !!!") ;
		return 0 ;
	}
	my $DB_Status = GetDBStatus ($GroupParams{"DATABASE_NAME_MASTER"}, $GroupParams{"$HOST"}) ;
	if ($DB_Status eq 0) {
		Info ("DB $GroupParams{\"DATABASE_NAME_MASTER\"} and Listener are Down !") ;
	}elsif ($DB_Status eq 2) {
		Exit ("DB $GroupParams{\"DATABASE_NAME_MASTER\"} is Down and Listener is UP !", 1) ;
	}else{
		Info ("DB $GroupParams{\"DATABASE_NAME_MASTER\"} is Up !") ;
		Info ("Shuting down DB $GroupParams{\"DATABASE_NAME_MASTER\"} on $GroupParams{\"$HOST\"}") ;
		if ($HostType eq "MASTER") {
			UpDownDB ($GroupParams{"$HOST"}, $GroupParams{"DATABASE_NAME_MASTER"}, "SHUT", " ") ;
			if ($GroupParams{"DB_TYPE"} eq "RAC") {
				ShutDownRAC ($GroupParams{"$HOST"}) ;
			}
		}else{
			UpDownDB ($GroupParams{"$HOST"}, $GroupParams{"DATABASE_NAME_MASTER"}, "ABORT", " ") ;
		}
		
		sleep (30) ;
		$DB_Status = GetDBStatus ($GroupParams{"DATABASE_NAME_MASTER"}, $GroupParams{"$HOST"}) ;
		if ($DB_Status eq 0) {
			Info ("Shuting Down DB $GroupParams{\"DATABASE_NAME_MASTER\"} on $GroupParams{\"$HOST\"} $OK") ;
			return 0 ;
		}else{
			Debug("ShutDownDB","Error: Shuting Down DB $GroupParams{\"DATABASE_NAME_MASTER\"} on $GroupParams{\"$HOST\"} FAILED");
			Exit ("Shuting Down DB $GroupParams{\"DATABASE_NAME_MASTER\"} on $GroupParams{\"$HOST\"} FAILED", 1) ;
		}
	}
	
	if ($GroupParams{"DB_TYPE"} eq "ASM") {
		SetTNS ($GroupParams{"ASM_TNSNAME"}) ;
		my $DB_Status = GetASMStatus ($GroupParams{"ASM_DATABASE_NAME_MASTER"}, $GroupParams{"$HOST"}) ;
		if ($DB_Status eq 0) {
			Info ("DB $GroupParams{\"ASM_DATABASE_NAME_MASTER\"} and Listener are Down !") ;
		} elsif ($DB_Status eq 2) {
			Exit ("DB $GroupParams{\"ASM_DATABASE_NAME_MASTER\"} is Down and Listener is UP !", 1) ;
		} else {
			Info ("DB $GroupParams{\"ASM_DATABASE_NAME_MASTER\"} is Up !") ;
			Info ("Shuting down DB $GroupParams{\"ASM_DATABASE_NAME_MASTER\"} on $GroupParams{\"$HOST\"}") ;
			UpDownDB ($GroupParams{"$HOST"}, $GroupParams{"ASM_DATABASE_NAME_MASTER"}, "SHUT", " ") ;
						
			sleep (30) ;
			$DB_Status = GetASMStatus ($GroupParams{"ASM_DATABASE_NAME_MASTER"}, $GroupParams{"$HOST"}) ;
			if ($DB_Status eq 0) {
				Info ("Shuting Down DB $GroupParams{\"ASM_DATABASE_NAME_MASTER\"} on $GroupParams{\"$HOST\"} $OK") ;
				SetTNS ($GroupParams{"TNS_NAME"}) ;
				return 0 ;
			} else {
				Debug("ShutDownDB","Error: Shuting Down ASM DB $GroupParams{\"ASM_DATABASE_NAME_MASTER\"} on $GroupParams{\"$HOST\"} FAILED");
				Exit ("Shuting Down DB $GroupParams{\"ASM_DATABASE_NAME_MASTER\"} on $GroupParams{\"$HOST\"} FAILED", 1) ;
			}
		}
		
		SetTNS ($GroupParams{"TNS_NAME"}) ;
	}
}
#-----------------------------------------------------------------------------#
sub UpDB($) {
	my $HostType = shift ;		chomp $HostType ;  # MASTER / TARGET
	my $HOST = $HostType . "_HOST" ;
	if ($HostType eq "MASTER") {
		if ($GroupParams{"DB_TYPE"} eq "RAC") {
			StartUpRAC ($GroupParams{"$HOST"}) ;
		}
		UpDownDB ($GroupParams{"$HOST"}, $GroupParams{"DATABASE_NAME_MASTER"}, "UP", "$GROUP_NAME") ;
	}else{
		UpDownDB ($GroupParams{"$HOST"}, $GroupParams{"DATABASE_NAME_MASTER"}, "UP", "$GROUP_NAME") ;
	}
	my $DB_Status = GetDBStatus ($GroupParams{"DATABASE_NAME_MASTER"}, $GroupParams{"$HOST"}) ;
	if ($DB_Status eq 0) {
		Exit ("DB $GroupParams{\"DATABASE_NAME_MASTER\"} and Listener are Down !", 1) ;
	}elsif ($DB_Status eq 2) {
		Exit ("DB $GroupParams{\"DATABASE_NAME_MASTER\"} is Down and Listener is UP !", 1) ;
	}else{
		Info ("DB $GroupParams{\"DATABASE_NAME_MASTER\"} is Up !") ;
		return 0 ;
	}
}
#-----------------------------------------------------------------------------#
# CheckVGDiff : Check For any diffrence between VG structure on Source&Target #
# 				If changes found - Returns "1" 								  #
#		Avishay M. 13.5.2009												  #
#		Ilia Gershenzon 27.10.2009											  #
#-----------------------------------------------------------------------------#
sub CheckVGDiff() {
	my $retval=0 ;
	my $mcmd = "";
	my $result = "";
	if (($GroupParams{"TARGET_HOST"} ne "NoHost") && ($GroupParams{"VG_LIST"} ne "" )) {
		Info("Checking VG Diffrences between source & target...") ;
		# Get VG list
		my @FullVGInfo = split (';', $GroupParams{"VG_LIST"}) ;
		foreach $vginfo (@FullVGInfo) {
			my $MasterVG = (split (':', $vginfo))[0] ;
			my $TargetVG = (split (':', $vginfo))[1] ;
			my $MinorNumber = (split (':', $vginfo))[2] ;
			
			Info ("Checking $MasterVG Vs. $TargetVG ") ;
			if ( GetFromStep() lt 30 ) {
				# This section runs on establish to compare vgdisplay outputs & save them to temporary files (for split)
				# Source server vgdisplay
				$mcmd = "/usr/sbin/vgdisplay -v $MasterVG | grep -e 'PV Name' -e 'LV Name' | grep -v -e Alternate | wc -l | tee /tmp/${MasterVG}_PVLVnum \n" ;
				$result = RunProgram ($GroupParams{"MASTER_HOST"}, "$mcmd") ;
				if ($result eq 0) {
					@SrcLVPVNum = GetCommandResult() ;
					Debug("CheckVGDiff","PV and LV number in VG $MasterVG, on master host is $SrcLVPVNum[0]") ;
				} else {
					Exit ("Failed to check VG $MasterVG on $GroupParams{\"MASTER_HOST\"}", 1) ;
				}
				# Target Server vgdisplay
				$mcmd = "/usr/sbin/vgdisplay -v $TargetVG | grep -e 'PV Name' -e 'LV Name' | grep -v -e Alternate | wc -l | tee /tmp/${TargetVG}_PVLVnum\n" ;
				$result = RunProgram ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
				if ($result eq 0) {
					@TrgtLVPVNum = GetCommandResult() ;
					Debug("CheckVGDiff","PV and LV number in VG $TargetVG, on target host is $TrgtLVPVNum[0]") ;
				} else {
					Exit ("Failed to check VG $TargetVG on $GroupParams{\"TARGET_HOST\"}", 1) ;
				}
				
			} else {
				
				# This section runs on split only to compare temporary files created during establish
				# Check Nu. of Pv's and LV's on Source server
				$mcmd = "cat /tmp/${MasterVG}_PVLVnum \n" ;
				$result = RunProgram ($GroupParams{"MASTER_HOST"}, "$mcmd") ;
				if ($result eq 0) {
					@SrcLVPVNum = GetCommandResult() ;
					Debug("CheckVGDiff","PV and LV number in VG $MasterVG, on master host is $SrcLVPVNum[0]") ;
				} else {
					Exit ("Failed to check VG $MasterVG on $GroupParams{\"MASTER_HOST\"}", 1) ;
				}
				# Check Nu. of Pv's and LV's on Taget Server
				$mcmd = "cat /tmp/${TargetVG}_PVLVnum \n" ;
				$result = RunProgram ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
				if ($result eq 0) {
					@TrgtLVPVNum = GetCommandResult() ;
					Debug("CheckVGDiff","PV and LV number in VG $TargetVG, on target host is $TrgtLVPVNum[0]") ;
				} else {
					Exit ("Failed to check VG $TargetVG on $GroupParams{\"TARGET_HOST\"}", 1) ;
				}
			}
						
			# Removing leading/trailing whitespaces 
			$SrcLVPVNum[0] =~ s/^\s+//;
			$SrcLVPVNum[0] =~ s/\s+$//;
			$TrgtLVPVNum[0] =~ s/^\s+//;
			$TrgtLVPVNum[0] =~ s/\s+$//;
			
			if ( $SrcLVPVNum[0] ne $TrgtLVPVNum[0] ) {
				#Difference between source and target found
				if ( $TrgtLVPVNum[0] eq 0 ) {
					Info("Cannot vgdisplay on Target VG\'s - I\'ll try to vgimport them later !");
					Debug("CheckVGDiff","Cannot vgdisplay on Target VG\'s");
					$retval = 1 ;
					return $retval;
				}
				Info("Found some diffrence on VG $MasterVG between master and target");
				Debug("CheckVGDiff","PV and LV number in VG $TargetVG is diffrent on source & target - $SrcLVPVNum[0] Vs. $TrgtLVPVNum[0] ") ;
				$retval = 1 ;
			} else {
				Info ("$MasterVG & $TargetVG are in the same structure - O.K.") ;
				Debug("CheckVGDiff","PV and LV number in VG $TargetVG are the same on source & target - $SrcLVPVNum[0] Vs. $TrgtLVPVNum[0] ") ;
			}
		}
	}
		
	return $retval ;
}
###############################################################################
# The Establish Proccess !!!                                                  #
###############################################################################
#-----------------------------------------------------------------------------#
# Step 05 : Check the Group status !                                          #
#-----------------------------------------------------------------------------#
sub CheckGroupStatus() {
	# XIV - Step 05
	if ($GroupParams{"MSGRP"} eq "XIV" ) {
		Info ("XIV Configuration");
		
		# If the replication is on LOCAL XIV
		if ($GroupParams{"XIV_FROM_MIRROR"} eq "no") { # This is a LOCAL copy
			if ($GroupParams{"XIV_CG"} eq "no" ) { # THIS IS a SINGLE volume
			
				#-# Check if Source Volume Exists - vol_list vol=<SRC>
				if ( isXivVolExists($GroupParams{"LOCAL_XIV"}, $xiv_src_volume[0]) ne 0 ) {
					Exit ("Error: The volume does NOT exists on the XIV - i have to exit",1);
				}
				#-# Check if Target Volume Exists - vol_list vol=<TGT>
				if ( isXivVolExists($GroupParams{"LOCAL_XIV"}, $xiv_tgt_volume[0]) ne 0 ) {
					Exit ("Error: The volume does NOT exists on the Target XIV - i have to exit",1);
				}
				#-# Print to screen the Source -> Target names
				Info ("Going to Snapshot a Volume from \"$xiv_src_volume[0]\" to \"$xiv_tgt_volume[0]\" on XIV \n");
				
			} else { # XIV Local Snap Group (From Consistency Group)
				#-# Check if Source CG Exists - cg_list cg=<CG>
				if ( isXivCgExists($GroupParams{"LOCAL_XIV"},$xiv_src_volume[0]) ne 0 ) {
					Exit ("Error: The Consistency Group does NOT exists on the XIV - i have to exit",1);
				}
				#-# Check if Target Snap Group Exists - snap_group_name_list snap_group=<SNAP_CG>
				if ( isXivSnapGroupExists($GroupParams{"LOCAL_XIV"},$xiv_tgt_volume[0]) ne 0 ) {
					Exit ("Error: The Snapshot Group does NOT exists on the XIV - i have to exit",1);
				}
				#-# Print to screen the Source CG -> Traget CG names
				Info ("Going to Snapshot a Consistency Group \"$xiv_src_volume[0]\" to \"$xiv_tgt_volume[0]\" on XIV \n");
			}
		}
		else { #replication is on REMOTE XIV machine
			# Check Volume Mirror Status
			if ( isXivVolMirrorExists($GroupParams{"LOCAL_XIV"},$xiv_src_volume[0]) ne 0 ) {
				Exit ("Error: The mirror relationship does NOT exists on the XIV - i have to exit",1);
			}
			
			if ($GroupParams{"XIV_CG"} eq "no" ) { # THIS IS a SINGLE volume - Mirror Snap
				if ( isXivVolExists($GroupParams{"LOCAL_XIV"}, $xiv_src_volume[0]) ne 0 ) {
					Exit ("Error: The volume does NOT exists on the XIV - i have to exit",1);
				}
				#if ( isXivVolExists($GroupParams{"REMOTE_XIV"}, $xiv_tgt_volume[0]) ne 0 ) {
				#	Exit ("Error: The volume does NOT exists on the Target XIV - i have to exit",1);
				#}
			
			} else { # XIV Mirror Snap Group (From a Consistency Group)
				# Check Consistency Group on Source
				if ( isXivCgExists($GroupParams{"LOCAL_XIV"},$GroupParams{"XIV_SRC_CG_NAME"}) ne 0 ) {
					Exit ("Error: The Consistency Group does NOT exists on the XIV - i have to exit",1);
				}
				# Check Snap Group on Source
				if ( isXivSnapGroupExists($GroupParams{"LOCAL_XIV"},$GroupParams{"XIV_DST_SG_NAME"}) ne 0 ) { 
					Exit ("Error: The Snapshot Group does NOT exists on the Source XIV - i have to exit",1);
				}
				# Check Snap Group on Target
				if ( isXivSnapGroupExists($GroupParams{"REMOTE_XIV"},$GroupParams{"XIV_DST_SG_NAME"}) ne 0 ) {
					Exit ("Error: The Snapshot Group does NOT exists on the Target XIV - i have to exit",1);
				}
			}
		}
	}
	
	# SVC - Step 05
	if ($GroupParams{"MSGRP"} eq "SVC" ) {
		Info ("SVC Configuration");
		if ( $GroupParams{"SVC_FC_CG"} eq "yes" ) {
			Info ("Checking if the Flash Copy Group Exists");
			for (my $index = 0; $index <= $#svc_fc_grp; $index++) {
				isSvcFcCgExists($GroupParams{"LOCAL_SVC"}, $svc_fc_grp[$index]);
			}
			
		}
	}
	
	# Netapp
	if ($GroupParams{"MSGRP"} eq "Netapp" ) {
		Info ("Netapp Configuration");
		Info ("Going to FlexClone the following Volumes:");
		# Print the volumes
		for (my $index = 0; $index <= $#netapps; $index++) {
			Info ("$netapps[$index]:$src_vols[$index] -> $tgt_vols[$index]");
		}
	}
	# NetappSAN
	if ($GroupParams{"MSGRP"} eq "NetappSAN" or $MigrationPeriod) {
		Info ("NetappSAN Configuration");
		for (my $index = 0; $index <= $#netapps; $index++) {
			#check with method been used for cloning, file-clone is being used only when src and dst are equal (SVM and Vol)
			$use_clone_type = 'flex-clone';
			if ($netapps[$index] eq $netappd[$index] and $src_vols[$index] eq $tgt_vols[$index]) {
				$use_clone_type = 'file-clone';
			}		
			
			if ($use_clone_type eq 'file-clone') {
				if ( $src_path[$index] eq $tgt_path[$index]) {
					Exit ("ERROR: when file-clone is used diffrent path should be provided for the destination",1);
				}
				
				$qtree = ''; $qtree = $src_path[$index] if $src_path[$index];
				
				@LUNs = getLunsCOT($netapps[$index],$src_vols[$index],$qtree,'');
				if ($#LUNs lt 0) {
					Exit ("ERROR: could not find LUNs on source path: $netapps[$index]:/vol/$src_vols[$index]/$src_path[$index]",1);
				} else {
					Info("List of LUNs on source path $netapps[$index]:/vol/$src_vols[$index]/$src_path[$index]");
					foreach $lun (@LUNs) {
						Info($lun);
					}
				}
			}
			if ($use_clone_type eq 'flex-clone') {
				Info ("Validating that src:\"$netapps[$index]:$src_vols[$index]\" is replicated to dst:\"$netappd[$index]:$tgt_vols[$index]\"");
				if (isVolSnapmirrorExistsCOT($netapps[$index],$src_vols[$index],$netappd[$index],$tgt_vols[$index])) {
					Exit ("ERROR: Snapmirror relation couldnot be found or it is not initialized",1);
				} else {
					Info ("Snapmirror relationship found - $OK");
				}
				
				Info ("Flex Clone name will be \"ReplicMan_$tgt_path[$index]\" - prefix been added for protection");
			}
		}
	}	
	# EMC Snap
	if ($GroupParams{"MSGRP"} eq "SYMSNAP" ) {
		Info ("Getting Group Status") ;
		# Check if group is in CopyOnWrite state
		if (GetDGStatusCOW("$CommandPrefix") eq 0) {
			Info ("You are in CopyOnWrite mode") ;
		}
		else { # Group is NOT in CopyOnWrite state
			# Check if the Group is in Created state
			if (GetDGStatusCreated("$CommandPrefix") eq 0) {
				Info("You are already in Created mode. Moving to Step 45...");
				SetCurrentStep("45");
			}
			else { # Group is NOT in Created state
				Debug ("CheckGroupStatus","Error: Snapshot disks are not in CopyOnWrite or Created mode") ;
				Exit ("Error::CheckGroupStatus: Snapshot disks are not in CopyOnWrite or Created mode",1) ;
			}
		}
	}
	
	#SRDF and Clone
	if (($GroupParams{"MSGRP"} eq "SRDF") || ($GroupParams{"MSGRP"} eq "Clone")) { 
		Info ("Getting DeviceGroup Status") ;
		my $ExitCode = GetDGStatus("$CommandPrefix") ;
		chomp $ExitCode ;
		if ($ExitCode eq 1) {
			Info ("You are in Split Mode") ;
		}elsif ($ExitCode eq 2) {
			Info ("$GROUP_NAME Is Already Syncronized. Moving to Step 45");
			SetCurrentStep("45");
		}elsif ($ExitCode eq 3) {
			Info ("The Establish Process For $GROUP_NAME Is In Progress. Moving to Step 35");
			SetCurrentStep("35");
		}else{
			Debug ("CheckGroupStatus","Error: There is a problem querying disks status !") ;
			Exit ("Error: There is problam with the group status !!!", 1) ;
		}
	}
}
#-----------------------------------------------------------------------------#
# Step 06 : Check For Running syncs with the same source devices			  #
#-----------------------------------------------------------------------------#
sub CheckRunningSyncs() {
	Info ("Checking for other running syncs ...");
	my ($DbName,$SrcName,$Trg) = (split ('_', $GROUP_NAME))[0,1,2];
	my $SRC = (join ('_',$DbName,$SrcName));
	my $result = system ("ls $LogsDir/*$SRC*.lock* | grep -v $Trg"); 
	if ($result eq 0 && ($GROUP_NAME ne "PRDOL1_PCUSTDBOL1_VEGAS" && $GROUP_NAME ne "PRDOL1_PCUSTDBOL1_AUX1DB")) {
		Info ( "A lock file exists...");
		Info ( `ls $LogsDir/*$SRC*.lock* | grep -v $Trg`);
		Exit ( "Check for running/failed sync : $SRC" ,1);
	}
}
#-----------------------------------------------------------------------------#
# Step 10 : Run Establish Pre Command !!!                                     #
#-----------------------------------------------------------------------------#
sub EstPreCommand() {
	Info ("Running PreEstablish Command") ;
	Pre_Post_Command ("PRE", "EST") ;
	Info ("Running PreEstablish Command $OK") ;
}
#-----------------------------------------------------------------------------#
# Step 15 : ShutDown the DB on the target host !!!                            #
#-----------------------------------------------------------------------------#
sub ShutDownTargetDB () {	ShutDownDB("TARGET") ;	}
#-----------------------------------------------------------------------------#
# Step 20 : umount filesystems on the target host !!!                         #
#-----------------------------------------------------------------------------#
sub UmountTargetFS() {
	if ($GroupParams{"SERVERS_LIST"} =~ /none/) {
		UmountHost("TARGET") ;	
	}
	else {
		Info("NFS Config");
		UmountNFSHosts("TARGET") ;
	}
}
#-----------------------------------------------------------------------------#
# Step 30 : Do the establish !!!                                              #
#-----------------------------------------------------------------------------#
sub DoTheEstablish() {
	# Clone
	if ( $CommandPrefix =~ /symclone/ ) {
		# Check if user asked for FULL sync
		if ( $FULL eq "-full" ) {
			# First terminate the current session
			Info("Full Clone - Terminating current connection");
			if ( TerminateCloneDG("$CommandPrefix") eq 0 ) {
				Info("Terminating the session Completed Successfuly") ;
			}
			else {
				Exit ("ERROR::DoTheEstablish: Terminating the session Failed - I have to exit",1);
			}
			
			# Now create the session again
			Info ("Creating a Clone session");
			if (CreateCloneDG("$CommandPrefix") eq 0) {
				Info ("Creating a Clone session Completed Successfuly");
			}
			else {
				Exit ("ERROR::DoTheEstablish: Creating a Clone session  Failed - i have to exit",1);
			}
		}
		# Re-create the session
		Info ("Re-Creating a Clone session");
		if ( ReCreateCloneDG("$CommandPrefix") eq 0 ) {
			Info ("Re-Creation of a Clone session Completed Successfuly");
		}
		else {
			Exit ("ERROR::DoTheEstablish: Re-Creation of a Clone session Failed - I have to exit",1);
		}
		Info ("You Can Run The Command  ( $CommandPrefix query ) To See the Establish Progress\n") ;
	}
	# Snap
	if ( $CommandPrefix =~ /symsnap/ ) {
		# First terminate the current CopyOnWrite snapshot:
		Info ("Terminating the Snap session");
		if (TerminateSnapDG("$CommandPrefix") eq 0) {
			Info ("The Snap Session is terminated") ;
		} else {
			Debug("DoSymSnapEstablish","Error: Failed to terminate the snapshot session");
			Exit ("Error: Failed to terminate the snapshot session", 1) ;
		}
		
		# Create the Snap session
		Info("Creating the Snap session");
		if (CreateSnapDG("$CommandPrefix","$GroupParams{\"SVP\"}") eq 0) {
			Info ("Create Snap session Completed Sucessfully") ;
		} else {
			Debug("DoSymSnapEstablish","Error: Failed to create snapshot session");
			Exit ("Error: Failed to create snapshot session", 1) ;
		}
		Info ("You Can Run The Command  ( $CommandPrefix query ) To See the Establish Progress\n") ;
	}
	# SRDF
	if ( $CommandPrefix =~ /symrdf/ ) {
		# Establish
		Info ("Establish the SRDF group");
		if ( EstSrdfDG("$CommandPrefix $Full") eq 0 ) {
			Info("Establish the SRDF group Completed Successfuly");
		}
		else {
			Exit ("ERROR::DoTheEstablish: Establish the SRDF group Failed - I have to exit",1);
		}
		Info ("You Can Run The Command  ( $CommandPrefix query ) To See the Establish Progress\n") ;
	}
	# NetApp - Step 30
	if ( $GroupParams{"MSGRP"} eq "Netapp" ) {
		# Run for every volume
		for (my $index = 0; $index <= $#netapps; $index++) {
			# Check if FlexVol (dest volume) exists - if so, delete it
			Info ("Checking if Target Volume \"$tgt_vols[$index]\" exists on \"$netapps[$index]\"");
			if ($GroupParams{"CLUSTER_DOT"} eq "yes" ) {
				if (isVolExistsCOT($netapps[$index], $tgt_vols[$index]) eq 0 ) {
					# Take volume offline
					Info ("Going to take offline previous FlexClone \"$netapps[$index]:$tgt_vols[$index]\"");
					if ( offlineVolCOT($netapps[$index], $tgt_vols[$index]) eq 0 ) {
						Info ("Volume taken offline successfully");
					}
					else {
						Exit ("ERROR: Cannot offline volume - I have to EXIT",1);
					}
					
					# Delete the Flexclone
					Info ("Going to delete previous FlexClone \"$netapps[$index]:$tgt_vols[$index]\"");
					if ( deleteVolCOT($netapps[$index], $tgt_vols[$index]) eq 0 ) {
						Info ("FlexClone deleted successfully");
					}
					else {
						Exit ("ERROR: Cannot Destroy volume - I have to EXIT",1);
					}
				}
				else {
					Info ("Volume \"$tgt_vols[$index]\" does NOT exists on \"$netapps[$index]\" Moving on");
				}
				
				# Check if the snapshot that the FlexClone is based upon exists - if so, delete it
				# Define a snapshot for the netapp group
				my $Uniq_Snapshot="ReplicMan_" . $GroupParams{"TARGET_HOST"};  chomp $Uniq_Snapshot;
				Info("Going to check if snapshot $Uniq_Snapshot exists on $netapps[$index] $src_vols[$index]");
				if (isSnapExistsCOT($netapps[$index], $src_vols[$index],$Uniq_Snapshot) eq 0 ) {
					# Delete the snapshot
					Info("Going to delete snapshot $Uniq_Snapshot from $netapps[$index]\:$src_vols[$index]");
					if (deleteSnapCOT($netapps[$index], $src_vols[$index],$Uniq_Snapshot) eq 0 ) {
						Info("The snapshot $Uniq_Snapshot in $netapps[$index]\:$src_vols[$index] was Deleted");
					}
					else {
						Exit("ERROR: Cannot delete snapshot - I have to EXIT",1);
					}
				}
			}
			else { # Regular 7-Mode
				if (isVolExists($netapps[$index], $tgt_vols[$index]) eq 0 ) {
					# Take volume offline
					Info ("Going to take offline previous FlexClone $netapps[$index]:$tgt_vols[$index]");
					offlineFlexClone($netapps[$index], $tgt_vols[$index]);
					Info ("Volume taken offline successfully");
					
					# Delete the Flexclone
					Info ("Going to delete previous FlexClone $netapps[$index]:$tgt_vols[$index]");
					deleteFlexClone($netapps[$index], $tgt_vols[$index]);
					Info ("FlexClone deleted successfully");
				}
				else {
					Info ("Volume $tgt_vols[$index] does not exists. I will create it later in Step 60 ... ");
				}
			}
		}
	}

	# NetApp SAN - Step 30
	
	if ( $GroupParams{"MSGRP"} eq "NetappSAN" ) {
		# Run for every volume
		for (my $index = 0; $index <= $#netapps; $index++) {
		
			Debug("DoTheEstablish","NetApp SAN data parsed: S:$netapps[$index] D:$netappd[$index] S:$src_vols[$index] P:$src_path[$index] T:$tgt_vols[$index] P:$tgt_path[$index]");
			#check with method been used for cloning, file-clone is being used only when src and dst are equal (SVM and Vol)
			$use_clone_type = 'flex-clone';
			if ($netapps[$index] eq $netappd[$index] and $src_vols[$index] eq $tgt_vols[$index]) {
				$use_clone_type = 'file-clone';
				if ( $src_path[$index] eq $tgt_path[$index]) {
					Exit ("ERROR: when file-clone is used diffrent path should be provided for the destination",1);
				}
			}

			
			#file clone been used to create the clone 
			if ($use_clone_type eq 'file-clone') {
				@LUNs = getLunsCOT($netappd[$index],$tgt_vols[$index],$tgt_path[$index],'ReplicManClone_');

				if ($#LUNs lt 0) {
					Info ("There are no LUN clones starting with ".$netappd[$index].":/vol/".$tgt_vols[$index]."/".$tgt_path[$index].'/ReplicManClone_');
				} else {
					foreach $lun (@LUNs) {
						Info ("Going to destroy LUN \"$netappd[$index]:$lun\"");
						if ( deleteLunCOT($netappd[$index], $lun) eq 0 ) {
							Info ("LUN destroyed successfully");
						} else {
							Exit ("ERROR: cannot destroy LUN:\"$netappd[$index]:$lun\"",1);
						}
					}
				}
			}
			
			#flex clone is used to create the clone 
			if ($use_clone_type eq 'flex-clone') {
				# Check if FlexVol exists - if so, delete it
				Info ("Checking if Target Flex Clone Volume \"ReplicManClone_$tgt_path[$index]\" exists on \"$netappd[$index]\"");
				if (isVolExistsCOT($netappd[$index], "ReplicManClone_".$tgt_path[$index]) eq 0 ) {
					#only destroy volumes with comment "Created by ReplicMan and can be destroyed by it"
					#Info ("Checking if Target Volume \"$tgt_vols[$index]\" contains comment:\"Created by ReplicMan and can be destroyed by it\"");
					#$comment = getVolCommentCOT($netappd[$index], $tgt_vols[$index]);
					#if (not $comment =~/Created by ReplicMan and can be destroyed by it/) {
					#	Exit ("ERROR: cannot destroy flex-clone that was not created by ReplicMan (comment was not found or diffrent)",1);
					#}
					#Info ("Volume comment validated");
					# Take volume offline
					Info ("Going to take offline previous FlexClone \"$netappd[$index]:ReplicManClone_$tgt_path[$index]\"");
					if ( offlineVolCOT($netapps[$index], 'ReplicManClone_'.$tgt_path[$index]) eq 0 ) {
						Info ("Volume taken offline successfully");
					}
					else {
						Exit ("ERROR: Cannot offline volume - I have to EXIT",1);
					}
					
					# Delete the Flexclone
					Info ("Going to delete previous FlexClone \"$netappd[$index]:ReplicManClone_$tgt_path[$index]\"");
					if ( deleteVolCOT($netappd[$index], 'ReplicManClone_'.$tgt_path[$index]) eq 0 ) {
						Info ("FlexClone deleted successfully");
					}
					else {
						Exit ("ERROR: Cannot Destroy volume - I have to EXIT",1);
					}
				}
				else {
					Info ("Volume \"$tgt_vols[$index]\" does NOT exists on \"$netapps[$index]\" Moving on");
				}
			}
			
			
			# Check if the snapshot that the Clone is based upon exists - if so, delete it
			# Define a snapshot for the netapp group
			my $Uniq_Snapshot="ReplicMan_" . $GroupParams{"TARGET_HOST"};  chomp $Uniq_Snapshot;
			Info("Going to check if snapshot $Uniq_Snapshot exists on $netapps[$index] $src_vols[$index]");
			if (isSnapExistsCOT($netapps[$index], $src_vols[$index],$Uniq_Snapshot) eq 0 ) {
				# Delete the snapshot
				Info("Going to delete snapshot $Uniq_Snapshot from $netapps[$index]\:$src_vols[$index]");
				if (deleteSnapIgnoreOwnertsCOT($netapps[$index], $src_vols[$index],$Uniq_Snapshot) eq 0 ) {
					Info("The snapshot $Uniq_Snapshot in $netapps[$index]\:$src_vols[$index] was Deleted");
				}
				else {
					Exit("ERROR: Cannot delete snapshot - I have to EXIT",1);
				}
			}
		}
	}


	
	# XIV - Step 30
	if ($GroupParams{"MSGRP"} eq "XIV" ) {
		# If the replication is on Remote XIV ( Nothing to do on Local Replication)
		if ($GroupParams{"XIV_FROM_MIRROR"} eq "yes") { # This is a REMOTE COPY
			if ($GroupParams{"XIV_CG"} eq "no" ) { # This is a SINGLE volume
				# Unmap Dest Volume from Target Host
				if ( XivUnMapFromHost($GroupParams{"REMOTE_XIV"},$xiv_tgt_volume[0], $GroupParams{"TARGET_HOST"}) ne 0 ) {
					Exit ("Error: Cannot Unmap the volume from the target host - i have to exit",1);
				}
				
				# Delete the source snapshot Volume on LOCAL XIV - The source name is eual to the target name
				if ( XivVolDelete($GroupParams{"LOCAL_XIV"}, $xiv_tgt_volume[0]) ne 0 ) {
					Exit ("Error: Cannot Delete the volume on the Local XIV - i have to exit",1);
				}
				# Delete the target Volume on Remote XIV
				if ( XivVolDelete($GroupParams{"REMOTE_XIV"}, $xiv_tgt_volume[0]) ne 0 ) {
					Exit ("Error: Cannot Delete the volume on the Remote XIV - i have to exit",1);
				}
			} else { #This is a CG
				# Unmap ALL the volumes from the Target Host
				for (my $index = 0; $index <= $#xiv_tgt_volume; $index++) {
					if ( XivUnMapFromHost($GroupParams{"REMOTE_XIV"}, $xiv_tgt_volume[$index], $GroupParams{"TARGET_HOST"}) ne 0 ) {
						Exit ("Error: Cannot Un-map the volume from the host - i have to exit",1);
					}
				}
			
				# Delete the Source Snap Group on Local XIV
				if ( XivSnapGroupDelete($GroupParams{"LOCAL_XIV"},$GroupParams{"XIV_SNAP_GROUP_NAME"}) ne 0 ) {
					Exit ("Error: Cannot Delete the Snapshot Group on the Local XIV - i have to exit",1);
				}
				# Delete the Target CG on Remote XIV
				if ( XivSnapGroupDelete($GroupParams{"REMOTE_XIV"},$GroupParams{"XIV_SNAP_GROUP_NAME"}) ne 0 ) {
					Exit ("Error: Cannot Delete the Snapshot Group on the Remote XIV - i have to exit",1);
				}
			}
		}
	}
	
	# SVC - Step 30
	if ($GroupParams{"MSGRP"} eq "SVC" ) {
		# Check if the SVC Config is with CG
		if ( $GroupParams{"SVC_FC_CG"} eq "yes" ) {
			for (my $index = 0; $index <= $#svc_fc_grp; $index++) {
				# Check if the group status is "Copying"
				if ( isSvcFcCgCopying($GroupParams{"LOCAL_SVC"}, $svc_fc_grp[$index]) eq 0 ) {
					# FC Map status if Copying - so, stop the copying
					if ( StopSvcFcCg($GroupParams{"LOCAL_SVC"}, $svc_fc_grp[$index]) ne 0 ) {
						Exit("ERROR: Cannot stop the FC Mapping - I have to exit", 1);
					}
				} else {
					# FC Map status is NOT copying - check if its already stopped
					if ( isSvcFcCgStopped($GroupParams{"LOCAL_SVC"}, $svc_fc_grp[$index]) eq 0 ) {
						# Move on ... already stopped
						Info ("FC Map group $svc_fc_grp[$index] is Stopped... I will continue");
					}
				}
			}
		}
	
	}
}
#-----------------------------------------------------------------------------#
# Step 35 : Check the group status After Establish & Befor Split !            #
#-----------------------------------------------------------------------------#
sub VerifyGroupStatus() {
	my $leftToSync = 123456789 ;
	# Define how much MBs is left before you change SRDF mode
	my $diff = 10000;
	my $srdfMode;
	
	# SRDF/A with Adaptive Copy
	if ($GroupParams{"SRDF_ASYNC"} eq "yes") {
		Info ("This is SRDF\A");
		# Check what is the Mode of operation of the SRDF Group
		Info ("Checking the MODE of the SRDF");
		$srdfMode = GetDGSrdfMode("$CommandPrefix");
		if ($srdfMode eq 1) { # Adaptive Copy
			Info ("This is Adaptive Copy MODE");
			Info ("Waiting untill there will be only $diff MB diffrence");
			$leftToSync = GetDGTotalDiff("$CommandPrefix");
			while ($leftToSync > $diff) {
				Info("There are still $leftToSync MBs to sync");
				# Check if Group continues to Sync
				if (GetDGStatusSyncinprog("$CommandPrefix") ne 0) {
					Debug("VerifyGroupStatus","there is a problem with the Group Status. I have to exit");
					Exit("Error: There is a problem with the Group Status. I have to exit",200);
				}
				sleep $GParam{"Interval"} ;
				$leftToSync = GetDGTotalDiff("$CommandPrefix");
			}
			# Change to Async mode
			Info ("Changing to Async mode");
			if ( SetDGSrdfModeAsync("$CommandPrefix") eq 0) {
				Info ("Changing to Async mode Completed Sucessfully");
			}
			else {
				Exit ("Changing to Async mode Failed - I have to exit",1);
			}
		}
		
		# Check if enabled - if not - change to enabled
		Info("Checking wheter the Consistency is Enabled");
		if ( GetDGStatusEnabled("$CommandPrefix") ne 0 ) {
			# Enable consistent mode
			Info ("Enabling Consistent mode");
			if ( SetDGStatusEnabled("$CommandPrefix") eq 0) {
				Info ("Enabling Consistent mode Completed Sucessfully");
			}
			else {
				Exit ("Enabling Consistent mode Failed - I have to exit",1);
			}
		}
		else {
			Info ("Consistency is already Enabled");
		}
		
		# Wait untill Pair is consistent
		Info ("Waiting for $GROUP_NAME to be Syncronized...") ;
		while (GetDGStatusConsistent("$CommandPrefix") ne 0) {
			# Checking if the group continues to sync
			my $rt = GetDGStatus("$CommandPrefix");
			if ( $rt != 2 && $rt != 3) {
				Exit ("Error: Group is not in a proper state - I have to exit",1);
			}
			Info("Waiting $GParam{\"Interval\"} Seconds before checking again");
			sleep $GParam{"Interval"} ;
		}
	}
	# Snap
	if ( $CommandPrefix =~ /symsnap/ ) {
		Info ("Waiting for $GROUP_NAME to switch to CREATED mode...") ;
		if (GetDGStatusCreated("$CommandPrefix") eq 0) {
			Info ("Snapshot is in CREATED mode") ;
		} else {
			Debug("VerifySymSnapStatus","Error: Snapshot failed to switch to CREATED");
			Exit ("Error: Snapshot failed to switch to CREATED mode !", 1) ;
		}	
	}
	# SRDF/S With Adaptive Copy
	if ( $CommandPrefix =~ /symrdf/ && $GroupParams{"SRDFS_AD"} eq "yes" ) {
		$diff = 8000;
		Info ("This is SRDF\S with Adaptive Copy configuration");
		# Check what is the Mode of operation of the SRDF Group
		Info ("Verifying the MODE of the SRDF");
		$srdfMode = GetDGSrdfMode("$CommandPrefix");
		if ($srdfMode eq 1) { # Adaptive Copy
			Info ("This is Adaptive Copy MODE");
			Info ("Waiting untill there will be only $diff MB diffrence");
			$leftToSync = GetDGTotalDiff("$CommandPrefix");
			while ($leftToSync > $diff) {
				Info("There are still $leftToSync MBs to sync");
				# Check if Group continues to Sync
				if (GetDGStatusSyncinprog("$CommandPrefix") ne 0) {
					Debug("VerifyGroupStatus","there is a problem with the Group Status. I have to exit");
					Exit("Error: There is a problem with the Group Status. I have to exit",200);
				}
				sleep $GParam{"Interval"} ;
				$leftToSync = GetDGTotalDiff("$CommandPrefix");
			}
			# Change to SRDF/S
			Info ("Changing to SRDF/S mode");
			if ( SetDGSrdfModeSync("$CommandPrefix") eq 0) {
				Info ("Changing to Sync mode Completed Sucessfully");
			}
			else {
				Exit ("Changing to Sync mode Failed - I have to exit",1);
			}
		}
	}
	
	# SRDF/S or a Clone
	if ( $CommandPrefix =~ /symclone/ || (  $CommandPrefix =~ /symrdf/ && $GroupParams{"SRDF_ASYNC"} eq "no" )) {
		Info ("This is a SRDF/S or a Clone");
		Info ("Waiting for $GROUP_NAME to be Syncronized...") ;
		while (GetDGStatus("$CommandPrefix") ne 2) {
			sleep $GParam{"Interval"} ;
		}
	}
	Info ("\n$GROUP_NAME Is Syncronized. You are ready for Split !!") ;
}
#-----------------------------------------------------------------------------#
# Step 40 : Run Establish Post Command !!                                     #
#-----------------------------------------------------------------------------#
sub EstPostCommand() {
	Info ("Running PostEstablish Command") ;
	Pre_Post_Command ("POST", "EST") ;
	Info ("Running PostEstablish Command $OK") ;
}
###############################################################################
# The Split Proccess !!!                                                      #
###############################################################################
#-----------------------------------------------------------------------------#
# Step 45 : Check the Group status !                                          #
#-----------------------------------------------------------------------------#
sub CheckSplitStatus() {

	Info ("Getting DeviceGroup Status") ;
	sleep 20;
	# Snap
	if ( $CommandPrefix =~ /symsnap/ ) {
		if ( GetDGStatusCreated("$CommandPrefix") eq 0 ) {
			Info ("$GROUP_NAME Is Syncronized.") ;
		}
	}
	# Clone / SRDF
	else {
		my $ExitCode = GetDGStatus("$CommandPrefix") ;
		chomp $ExitCode ;
		if ($ExitCode eq 1) {
			Debug("CheckSplitStatus","Error: You are in Split Mode, Consult Storage team to start from Step 60");
			Exit ("Error: You are in Split Mode,Consult Storage team to start from Step 60 ",1) ;
			
		}elsif ($ExitCode eq 2) {
			Info ("$GROUP_NAME Is Syncronized.") ;
		}elsif ($ExitCode eq 3) {
			Info ("The Establish Process For $GROUP_NAME Is In Progress !!") ;
			Info ("YOU ARE IN RESTART MODE") ;
			SetCurrentStep("30") ;  # Skip to the Establish Verify Proccess.
			Info("You Can Run The Command  ( $CommandPrefix query ) To See The Establish Progress") ;
		}else{
			Debug("CheckSplitStatus","Error: There is problam with the group status");
			Exit ("Error: There is problam with the group status !!!", 1) ;
		}
	}
}
#-----------------------------------------------------------------------------#
# Step 50 : Run Split Pre Command !!                                          #
#-----------------------------------------------------------------------------#
sub SplitPreCommand() {
	Info ("Running PreSplit Command") ;
	Pre_Post_Command ("PRE", "SPLIT") ;
	Info ("Running PreSplit Command $OK") ;
}
#-----------------------------------------------------------------------------#
# Step 55 : Prepare for Hot Split !                                           #
#-----------------------------------------------------------------------------#
sub PrepForHotSplit() {
	# move Old Sql Files !
	MoveOldSqlFiles() ;

	# Create Sql Files HOT !
	Create_sql_files() ;

	# Check Table-Space Status Hot / Cold !
	my $result = CheckHotStatusLog () ;
	if ($result ne 1) {		# You are in HotBackup mode and need to be in Regular Mode
		EndHotBackupMode() ;
	}

	# Select The First SCN !
	Select_Scn_Num ($WorkingFiles{"SCN_NUM_BEFOR"}) ;

	# Insert To Hot Backup Mode !
	Insert_Hot_backup() ;
	
	# Run Shell in background to check if DB is in HOT Backup mode - after 1 hour send OVO message
	my $tns=$GroupParams{"TNS_NAME"};
	Info ("Running /pub_tools/shells/check_hot_backup.sh $tns & ");
	my $mcmd="/pub_tools/shells/check_hot_backup.sh $tns &";
	RunProgram($runserver, $mcmd);

	# Sync All Data From The Memory To The Disks !
	if ($GroupParams{"DB_TYPE"} ne "ASM") {
		Info ("Syncing Data From Cache To Disk...") ;
		my $mcmd = "/usr/sbin/sync" ;
		my $ExitCode = RunProgram ($GroupParams{"MASTER_HOST"}, $mcmd) ;
		sleep 60 ;    # THIS IS EMC RECOMMENDATION !!
	}
}
#-----------------------------------------------------------------------------#
# Step 60 : Do the split !                                                    #
#-----------------------------------------------------------------------------#
sub DoTheSplit() {

	#will be used only during migration period from XIV to NetappSAN 
	$GroupParams{"MSGRP"} = "NetappSAN" if $MigrationPeriod;

	# SRDF (Both Sync and Async)
	if ( $CommandPrefix =~ /symrdf/ ) {
		# SRDF/A
		if ($GroupParams{"SRDF_ASYNC"} eq "yes") {
			# Check if Group is in Split State, If not -> Split it
			if ( GetDGStatusSplit("$CommandPrefix") ne 0 ) {
				# Split the group
				Info ("This is a Async SRDF, have to split with force option...");
				if ( SplitSrdfaDG("$CommandPrefix") eq 0 ){
					Info ("Split Command Completed Successfuly") ;
				}
				else {
					Exit ("ERROR::DoTheSplit: Cannot split - I have to exit",1);
				}
			}
			# The group is in Split state from here
			# Check if the group is already disabled (RT=40 -> None of the devices are enabled)
			if (GetDGStatusEnabled("$CommandPrefix") ne 40) {
				# Disable consistent mode
				Info ("Disabling Async Consistent mode");
				if (SetDGStatusDisabled("$CommandPrefix") eq 0) {
					Info ("Disabling Async Consistent mode Completed Successfuly");
				}
				else {
					Exit ("ERROR::DoTheSplit: Cannot Disable consistency - I have to exit",1);
				}
			}
			# The group is disabled
			# Change the mode to Adaptive Copy from Async (RT=2)
			if (GetDGSrdfMode("$CommandPrefix") eq 2) {
				# Change to ACP_Disk
				Info ("Changing SRDF mode to Adaptive-Copy");
				if (SetDGSrdfModeADC("$CommandPrefix") eq 0) {
					Info ("Changing SRDF mode to Adaptive-Copy Completed Successfuly");
				}
				else {
					Exit ("ERROR::DoTheSplit: Cannot change SRDF mode to acp_disk - I have to exit",1);
				}
			}
		}
		# SRDF/S
		else {
			# Check if Group is in Split State, If not -> Split it
			if ( GetDGStatusSplit("$CommandPrefix") ne 0 ) {
				Info ("This is a Sync SRDF - Running the split command");
				if (SplitSrdfsDG("$CommandPrefix") eq 0) {
					Info ("Split Command Completed Successfuly") ;
				}
				else {
					Exit ("ERROR::DoTheSplit: Cannot split - I have to exit",1);
				}
			}
			# If this is SRDF/S with Adaptive Copy - change to Adaptive Copy
			if ($GroupParams{"SRDFS_AD"} eq "yes") {
				# Check if the Mode is SRDF/S
				if (GetDGSrdfMode("$CommandPrefix") eq 3) {
					# Change to ACP_Disk
					Info ("Changing SRDF mode to Adaptive-Copy");
					if (SetDGSrdfModeADC("$CommandPrefix") eq 0) {
						Info ("Changing SRDF mode to Adaptive-Copy Completed Successfuly");
					}
					else {
						Exit ("ERROR::DoTheSplit: Cannot change SRDF mode to acp_disk - I have to exit",1);
					}
				}
				else{
					Info ("The group is in SRDF/S Mode");
				}
			}
		}
	}
	
	# EMC Clone
	if ( $CommandPrefix =~ /symclone/ ) {
		# This is a Clone
		Info ("This is a Clone - Running the activate \(split\) command");
		if (SplitCloneDG("$CommandPrefix") eq 0) {
			Info ("Activate Command Completed Successfuly") ;
		}
		else {
			Exit ("ERROR::DoTheSplit: Cannot Activate - I have to exit",1);
		}
	}
	
	# EMC Snap
	if ( $CommandPrefix =~ /symsnap/ ) {
		# Activate the Snap
		Info ("This is a Snap - Running the activate \(split\) command") ;
		if (SplitSnapDG("$CommandPrefix") eq 0) {
			Info ("Snapshot activation $OK ") ;
		} else {
			Debug("DoSymSnapSplit","Error: Snapshot activation failed !");
			Exit ("Error: Snapshot activation command failed !", 1) ;
		}
	}
	

	# NetappSAN
	if ( $GroupParams{"MSGRP"} eq "NetappSAN" ) {
		# Run for every volume
		for (my $index = 0; $index <= $#netapps; $index++) {
			# Define a snapshot for the netapp group
			my $Uniq_Snapshot="ReplicMan_" . $GroupParams{"TARGET_HOST"};  chomp $Uniq_Snapshot;
			
			# Confirm that the snapshot doesnt exists
			if (isSnapExistsCOT($netapps[$index], $src_vols[$index],$Uniq_Snapshot) eq 0 ) {
				Exit ("ERROR: The Snapshot $Uniq_Snapshot still exists in $netapps[$index]:$src_vols[$index] ! Please go back to Step 30 !",1);
			} else {
				Info ("Going to create a snapshot named \"$Uniq_Snapshot\" on \"$src_vols[$index]\" - Netapp \"$netapps[$index]\"");
				if ( createNetappSnapCOT($netapps[$index], $src_vols[$index], $Uniq_Snapshot) eq 0 ) {
					Info ("Snapshot Creation $OK");
				}
				else {
					Exit ("ERROR: Could NOT create the Snapshot \"$Uniq_Snapshot\" on \"$tgt_vols[$index]\" - Please try to Re-Run this step",1);
				}				
			}
						
			#check which method need to be used used for cloning, file-clone is being used only when src and dst are equal (SVM and Vol)
			$use_clone_type = 'flex-clone';
			if ($netapps[$index] eq $netappd[$index] and $src_vols[$index] eq $tgt_vols[$index]) {
				$use_clone_type = 'file-clone';
				if ( $src_path[$index] eq $tgt_path[$index]) {
					Exit ("ERROR: when file-clone is used diffrent path should be provided for the destination",1);
				}
			}

			#file clone need to be used used to create the clone 
			if ($use_clone_type eq 'file-clone') {
				#confirm that there are no cloned luns
				@LUNs = getLunsCOT($netappd[$index],$tgt_vols[$index],$tgt_path[$index],'ReplicManClone_');

				if ($#LUNs ge 0) {
					Exit ("ERROR: There are still LUN clones starting with ".$netappd[$index].":/vol/".$tgt_vols[$index]."/".$tgt_path[$index].'/ReplicManClone_ ! Go back to step 30!',1);
				} 	

				#confirm that there are source luns
				@LUNs = getLunsCOT($netapps[$index],$src_vols[$index],$src_path[$index],'');
				if ($#LUNs ge 0) {
					#creating qtree 
					Info ("Going to create a qtee  named \"$tgt_path[$index]\" on volume \"$tgt_vols[$index]\" - Netapp \"$netappd[$index]\"");					
					if (createNetappQtreeCOT($netappd[$index],$tgt_vols[$index],$tgt_path[$index])) {
						Exit ("ERROR: cannot create qtree",1);
					} else {
						Info ("Qtree created - $OK");
					}
					foreach $lun (@LUNs) {
						#create the lun file-clones
						$lun =~ /(.+)\/(\w+)$/;
						$lunclone = '/vol/'.$tgt_vols[$index].'/'.$tgt_path[$index].'/ReplicManClone_'.$2;
						
						Info ("Going to create a lun file-clone named \"$lunclone\" from lun \"$lun\" based on snap: \"$Uniq_Snapshot\" - Netapp \"$netappd[$index]\"");
						if ( createNetappLunCloneCOT($netappd[$index], $lun, $lunclone, $Uniq_Snapshot) eq 0 ) {
							Info ("Lun file-clone created - $OK");
						}
						else {
							Exit ("ERROR: Could NOT create the lun file-clone - Please try to Re-Run this step",1);
						}

						Info ("Going to map lun \"$lunclone\" to host \"".$GroupParams{"TARGET_HOST"}."\"");
						if ( mapNetappLunCOT($netappd[$index],$lunclone, $GroupParams{"TARGET_HOST"}) eq 0 ) {
							Info ("Lun mapped - $OK");
						}
						else {
							Exit ("ERROR: Could NOT map the lun - Please try to Re-Run this step",1);
						}
						
					}
				} else {
					Exit ("ERROR: No LUNs on ".$netapps[$index].":/vol/".$src_vols[$index]."/".$src_path[$index].' check your config !',1);
				}
			}

			#flex-clone need to be used used to create the clone 
			if ($use_clone_type eq 'flex-clone') {			
				# Confirm that the flexclone doesnt exists
				if ( isVolExistsCOT($netappd[$index], 'ReplicManClone_'.$tgt_path[$index]) eq 0 ) {
					Exit ("ERROR: The Volume \"$netappd[$index]:ReplicManClone_$tgt_path[$index]\" still exists ! Please go back to Step 30 !",1);
				}
				
				
				Info("Starting Snapmirror update from src:\"$netapps[$index]:$src_vols[$index]\" to dst:\"$netappd[$index]:$tgt_vols[$index]\"");
				if (not snapmirrorUpdateDOT($netapps[$index],$src_vols[$index],$netappd[$index],$tgt_vols[$index])){
					Info("Snapmirror update - $OK ");
				} else {
					Exit ("ERROR: Snapmirror update failed",1);
				}
				
				if (createFlexCloneNoJunctionCOT($netappd[$index],$tgt_vols[$index],'ReplicManClone_'.$tgt_path[$index],$Uniq_Snapshot)) {
					Exit ("ERROR: Could not create FlexClone:\"$netappd[$index]:ReplicManClone_$tgt_path[$index]\"! Please go back to Step 30 !",1);
				}

				#mapping the luns
				@LUNs = getLunsCOT($netapps[$index],$src_vols[$index],$src_path[$index],'');
				if ($#LUNs ge 0) {
					foreach $lun (@LUNs) {
						#create the lun file-clones
						$lun =~ /(.+)\/(\w+)$/;
						$lunclone = '/vol/ReplicManClone_'.$tgt_path[$index].'/'.$src_path[$index].'/'.$2 if $src_path[$index];
						$lunclone = '/vol/ReplicManClone_'.$tgt_path[$index].'/'.$2 if not $src_path[$index];
						Info ("Going to map lun \"$lunclone\" to host \"".$GroupParams{"TARGET_HOST"}."\"");
						if ( mapNetappLunCOT($netappd[$index],$lunclone, $GroupParams{"TARGET_HOST"}) eq 0 ) {
							Info ("Lun mapped - $OK");
						}
						else {
							Exit ("ERROR: Could NOT map the lun - Please try to Re-Run this step",1);
						}						
					}
				}
				
				#rescan for new disks
				if ($GroupParams{"OS_VERSION"} eq "Linux") {
					Info("Scanning the target host:\"".$GroupParams{"TARGET_HOST"}."\" for new devices");
					ReTry ($GroupParams{"TARGET_HOST"}, 'multipath -F -B');
					ReTry ($GroupParams{"TARGET_HOST"}, 'iscsiadm -m session --rescan');
					ReTry ($GroupParams{"TARGET_HOST"}, 'multipath -r -B');
					sleep 5;				
				}
			}
		}
	}
	
	# Netapp NAS
	if ( $GroupParams{"MSGRP"} eq "Netapp" ) {
		
		# Run for every volume
		for (my $index = 0; $index <= $#netapps; $index++) {
			# Check if this is a cluster configuration
			if ($GroupParams{"CLUSTER_DOT"} eq "yes" ) {
				Info ("-Cluster ONTAP MODE-");
				# Define a snapshot for the netapp group
				my $Uniq_Snapshot="ReplicMan_" . $GroupParams{"TARGET_HOST"};  chomp $Uniq_Snapshot;
				# Confirm that the flexclone doesnt exists
				if ( isVolExistsCOT($netapps[$index], $tgt_vols[$index]) eq 0 ) {
					Exit ("ERROR: The Volume $netapps[$index]:$tgt_vols[$index] still exists ! Please go back to Step 30 !",1);
				}
				# Confirm that the snapshot doesnt exists
				if (isSnapExistsCOT($netapps[$index], $src_vols[$index],$Uniq_Snapshot) eq 0 ) {
					Exit ("ERROR: The Snapshot $Uniq_Snapshot still exists in $netapps[$index]:$src_vols[$index] ! Please go back to Step 30 !",1);
				}
				
			
				# Confirm that the source volume exists
				Info ("Checking if the Source volume \"$src_vols[$index]\" exists on \"$netapps[$index]\"");
				if ( isVolExistsCOT($netapps[$index], $src_vols[$index]) eq 0 ) {
					Info ("Source volume \"$src_vols[$index]\" exists on \"$netapps[$index]\" $OK");
					
					# Check if this group is a SnapVault Destination Group
					if ($GroupParams{"S_VAULT_DEST"} eq "yes" ) {
						Info ("-SnapVault Config-");
						# Check what is the latest snapshot - with a snapmirror label
						Info("Getting the latest snapshot of volume \"$src_vols[$index]\" on \"$netapps[$index]\"");
						my $SV_Snapshot = getNetappLastSnapCOT($netapps[$index], $src_vols[$index], "ReplMan");
						if ($SV_Snapshot !~ /^[A-Z]/ && $SV_Snapshot !~ /^[a-z]/) {
							Exit ("ERROR: Could NOT get the latest snapshot of \"$tgt_vols[$index]\" - Please try to Re-Run this step",1);
						}
						Info("The latest snapshto name is \"$SV_Snapshot\"");
						
						# Create FlexClone
						Info ("Going to create a FlexClone named \"$tgt_vols[$index]\" from snapshot \"$SV_Snapshot\" from Volume \"$src_vols[$index]\" - Netapp \"$netapps[$index]\"");
						if ( createFlexCloneCOT($netapps[$index], $src_vols[$index], $tgt_vols[$index], $SV_Snapshot) eq 0 ) {
							Info ("FlexClone Creation $OK");
						}
						else {
							Exit ("ERROR: Could NOT create the FlexClone \"$tgt_vols[$index]\" - Please try to Re-Run this step",1);
						}
					}
					else { # Regular Group - Not a SnapVault destination
						Info ("Going to create a snapshot named \"$Uniq_Snapshot\" on \"$src_vols[$index]\" - Netapp \"$netapps[$index]\"");
						if ( createNetappSnapCOT($netapps[$index], $src_vols[$index], $Uniq_Snapshot) eq 0 ) {
							Info ("Snapshot Creation $OK");
						}
						else {
							Exit ("ERROR: Could NOT create the Snapshot \"$Uniq_Snapshot\" on \"$tgt_vols[$index]\" - Please try to Re-Run this step",1);
						}
						
						# Create FlexClone
						Info ("Going to create a FlexClone named \"$tgt_vols[$index]\" from snapshot \"$Uniq_Snapshot\" from Volume \"$src_vols[$index]\" - Netapp \"$netapps[$index]\"");
						if ( createFlexCloneCOT($netapps[$index], $src_vols[$index], $tgt_vols[$index], $Uniq_Snapshot) eq 0 ) {
							Info ("FlexClone Creation $OK");
						}
						else {
							Exit ("ERROR: Could NOT create the FlexClone \"$tgt_vols[$index]\" - Please try to Re-Run this step",1);
						}
					}
					
					# Assign volume to a export Policy
					Info ("Going to modify Volume \"$tgt_vols[$index]\" Policy to \"$GroupParams{\"CLUSTER_POLICY\"}\"");
					if ( exportNetappVolCOT($netapps[$index], $tgt_vols[$index], $GroupParams{"CLUSTER_POLICY"}) eq 0 ) {
						Info ("Volume modify - Assign to export policy $OK");
					}
					else {
						Exit ("ERROR: Could NOT modify volume export policy - Please try to Re-Run this step",1);
					}
					
					# DELETE ALL NON USED SNAPSHOTS
				
				}
				else {
					Exit ("ERROR: The Volume \"$src_vols[$index]\" on \"$netapps[$index]\" Does NOT exists !",1);
				}
			}
			else { # Regular 7-Mode
				# Confirm that the flexclone doesnt exists - if so, delete it
				if ( isVolExists($netapps[$index], $tgt_vols[$index]) eq 0 ) {
					Exit ("ERROR: The Volume $netapps[$index]:$tgt_vols[$index] still exists ! Please go back to Step 30 !",1);
				}
				
				# Confirm that the source volume exists
				Info ("Checking if the Source volume $src_vols[$index] exists on $netapps[$index]");
				if ( isVolExists($netapps[$index], $src_vols[$index]) eq 0 ) {
					# Create snapvault schedule
					Info ("Creating SnapVault schedule for ReplicMan");
					createSvSched($netapps[$index], $src_vols[$index], $tgt_vols[$index]);
					Info ("SnapVault schedule was created successfully");
					
					# Create the snapshot
					Info ("Going to create a snapshot on $netapps[$index]:$src_vols[$index]");
					createNetappSnap($netapps[$index], $src_vols[$index], $tgt_vols[$index]);
					Info ("Snapshot was created successfully");
					
					# If this is a QSM Dest volume - I have to update the snapmirror (Netapp bug)
					if ($GroupParams{"QSM_DEST"} =~ /yes/) {
						# Check if SM is Idle
						if ( checkSmIdle($netapps[$index], $src_vols[$index]) ne 0 ) {
							Exit ("ERROR: The Volume $netapps[$index]:$src_vols[$index] SnapMirror is not Idle - I have to exit...",1);
						}
						# Update the QSM volume
						Info ("Updating the SnapMirror Dest Volume $netapps[$index]:$src_vols[$index]");
						if ( updateSM ($netapps[$index], $src_vols[$index]) ne 0 ) {
							Exit ("ERROR: Cannot update SM Volume $netapps[$index]:$src_vols[$index] - I have to exit...",1);
						}
						
						# Wait untill update is DONE
						Info ("Waiting for the Snapmirror seassion to be Idle");
						while ( checkSmIdle($netapps[$index], $src_vols[$index]) ne 0 ) {
							Info ("Snapmirror seassion is not idle yet- Waiting 60 seconds ...");
							sleep 60;
						}
					}
					
					# Create the flexclone
					Info ("Going to create the FlexClone $netapps[$index]:$tgt_vols[$index]");
					if ( createFlexClone($netapps[$index], $src_vols[$index],$tgt_vols[$index]) ne 0 ) {
						Exit ("ERROR: Cannot create FlexClone $netapps[$index]:$tgt_vols[$index] - I have to exit...",1);
					}else {
						Info ("FlexClone was created successfully");
					}
					
					# Add the FlexClone to the vfiler unit - Only if netapp name differs the vfiler name
					if ( $netapps[$index] !~ $vfilers[$index] ) { 
						# Add FlexClone to the vfiler
						Info ("Adding the FlexClone to Vfiler $vfilers[$index]");
						addVol2Vfiler($netapps[$index], $vfilers[$index], $tgt_vols[$index]);
						Info ("Adding the FlexClone to Vfiler finished successfully");
						
						# Export on the Vfiler to the target Host
						Info ("Going to export FlexClone to host: $GroupParams{\"SERVERS_LIST\"}");
						if ( exportNetappVol($vfilers[$index],$tgt_vols[$index], $GroupParams{"SERVERS_LIST"}) ne 0 ) {
							Exit ("ERROR: Cannot export FlexClone $tgt_vols[$index] - I have to exit...",1);
						}else {
							Info ("FlexClone exported successfully");
						}
					}
					else { # There is NO vfiler - Only export on the Physical machine
						# Export the FlexClone to the Target Host
						Info ("Going to export FlexClone to host: $GroupParams{\"SERVERS_LIST\"}");
						if ( exportNetappVol($netapps[$index],$tgt_vols[$index], $GroupParams{"SERVERS_LIST"}) ne 0 ) {
							Exit ("ERROR: Cannot export FlexClone $tgt_vols[$index] - I have to exit...",1);
						}else {
							Info ("FlexClone exported successfully");
						}
					}
				}
				else {
					Exit ("Error: Source volume $src_vols[$index] does NOT exists on $netapps[$index] - i have to exit",1);
				}
			}
		}
	}
	
	# XIV - Step 60
	if ($GroupParams{"MSGRP"} eq "XIV" ) {
		# If the replication is on LOCAL XIV
		if ($GroupParams{"XIV_FROM_MIRROR"} eq "no") { # This is a LOCAL copy
			if ($GroupParams{"XIV_CG"} eq "no" ) { # THIS IS a SINGLE volume
				if ( XivSnapCreate($GroupParams{"LOCAL_XIV"},$xiv_src_volume[0],$xiv_tgt_volume[0]) ne 0 ) {
					Exit ("Error: Cannot create snapshot - i have to exit",1);
			}
			
			} else { #This is a LOCAL CG
				if ( XivCgSnapCreate($GroupParams{"LOCAL_XIV"},$xiv_src_volume[0],$xiv_tgt_volume[0]) ne 0 ) {
					Exit ("Error: Cannot create Consistency Group Snapshot - i have to exit",1);
				}
			}
		} else { # This is a REMOTE COPY
			if ($GroupParams{"XIV_CG"} eq "no" ) { # THIS IS a SINGLE volume - Mirror Snap
				if ( XivMirrorSnapVolume($GroupParams{"LOCAL_XIV"}, $xiv_src_volume[0],$xiv_tgt_volume[0]) ne 0 ) {
					Exit ("Error: Cannot create a Mirror Snapshot - i have to exit",1);
				}
				
				#-# Wait untill the Target have recieved the snapshot
				my $counter = 0;
				# Sleep 30 Sec before first check
				sleep 30;
				while ( isXivVolExists($GroupParams{"REMOTE_XIV"},$xiv_tgt_volume[0]) ne 0 ) {
					Info ("Volume \"$xiv_tgt_volume[0]\" does NOT exists yet on Target XIV, Waiting 60 Sec ...\n");
					sleep 60;
					$counter++;
					if ( $counter gt 10 ) {
						Info ("Snapshot Volume \"$xiv_tgt_volume[0]\" does NOT exists on Target XIV, even after 10 Min \n");
						Exit ("Error: Waited too long for the target Snapshot volume. Please check the XIV Mirror status and try again", 1);
					}
				}
				#-# Unlcok the Target Snapshot Volume
				if ( XivUnlcokVol($GroupParams{"REMOTE_XIV"}, $xiv_tgt_volume[0]) ne 0 ) {
					Exit ("Error: Cannot unlcok the Snapshot - i have to exit",1);
				}
				
				#-# Map the Target Snapshot Volume
				if ( XivMapVolToHost($GroupParams{"REMOTE_XIV"}, $xiv_tgt_volume[0], $GroupParams{"TARGET_HOST"}) ne 0 ) {
					Exit ("Error: Cannot map the volume to the host - i have to exit",1);
				}
				
			} else { # XIV Mirror Snap Group (From a Consistency Group)
				if ( XivMirrorSnapGroup($GroupParams{"LOCAL_XIV"},$GroupParams{"XIV_SRC_CG_NAME"}, $GroupParams{"XIV_DST_SG_NAME"}) ne 0 ) {
					Exit ("Error: Cannot create the Mirrored Snapshot Group - i have to exit",1);
				}
				
				#-# Wait untill the Target have recieved the snapshot Group
				my $counter = 0;
				# Sleep 30 Sec before first check
				sleep 30;
				while ( isXivSnapGroupExists($GroupParams{"REMOTE_XIV"},$GroupParams{"XIV_DST_SG_NAME"}) ne 0 ) {
					Info ("Snap Group \"$GroupParams{\"XIV_DST_SG_NAME\"}\" does NOT exists yet on Target XIV, Waiting 60 Sec ...\n");
					sleep 60;
					$counter++;
					if ( $counter gt 10 ) {
						Info ("Snapshot Group \"$GroupParams{\"XIV_DST_SG_NAME\"}\" does NOT exists on Target XIV, even after 10 Min \n");
						Exit ("Error: Waited too long for the target Snapshot Group. Please check the XIV Mirror status and try again", 1);
					}
				}
				
				#-# Unlcok the Target Snapshot Group
				if ( XivUnlcokSg($GroupParams{"REMOTE_XIV"},$GroupParams{"XIV_DST_SG_NAME"}) ne 0 ) {
					Exit ("Error: Cannot unlcok the Snapshot Group - i have to exit",1);
				}
				
				#-# Map all the Target Volumes
				for (my $index = 0; $index <= $#xiv_tgt_volume; $index++) {
					if ( XivMapVolToHost($GroupParams{"REMOTE_XIV"}, $xiv_tgt_volume[$index], $GroupParams{"TARGET_HOST"}) ne 0 ) {
						Exit ("Error: Cannot map the volume to the host - i have to exit",1);
					}
				}
			}
		}
	}
	# SVC - Step 60
	if ($GroupParams{"MSGRP"} eq "SVC" ) {
		# Check if the SVC Config is with CG
		if ( $GroupParams{"SVC_FC_CG"} eq "yes" ) {
			for (my $index = 0; $index <= $#svc_fc_grp; $index++) {
				# Make sure that the FC group is stopped
				my $timeout_counter=0; 
				my $max_timeout_counter=20; # 20 minutes to wait MAX
				while ( isSvcFcCgStopped($GroupParams{"LOCAL_SVC"}, $svc_fc_grp[$index]) ne 0 ) {
					sleep 60;
					Info("The FC MAP did not stopped yet ... I will wait another minute before I check again...");
					$timeout_counter+=1;
					if ( $timeout_counter > $max_timeout_counter ) {
						Exit("ERROR: FC MAP is NOT stopped after the 20 minutes ... Please contact Storage team",1);
					}
				}
				Info("FC MAP \"$svc_fc_grp[$index]\" has stopped. Starting it again - creating point in time");
				
				# Start the FC Map again
				if ( StartSvcFcCg ($GroupParams{"LOCAL_SVC"}, $svc_fc_grp[$index]) ne 0 ) {
					# Cant start the FC MAP
					Exit("ERROR: Cannot start the FC map again ... Please check why - I have to exit",1);
				}
				
				# Wait for the group to start - copying
				$timeout_counter=0;
				while ( isSvcFcCgCopying($GroupParams{"LOCAL_SVC"}, $svc_fc_grp[$index]) ne 0 ) {
					sleep 60;
					Info("The FC Map did not started yet ... I will wait another minute before I check again...");
					$timeout_counter+=1;
					if ( $timeout_counter > $max_timeout_counter ) {
						Exit("ERROR: FC MAP is NOT copying after the 20 minutes ... Please contact Storage team",1);
					}
				}
			}
		}
	}
}
#-----------------------------------------------------------------------------#
sub GetMasterVGDisks($) {
	my $VG = shift ;
	chomp $VG ;
	my $mcmd = "/usr/sbin/vgdisplay -v $VG | grep \"PV Name\" | grep -v \"Alternate Link\"" ;
	my $status = RunProgram  ($GroupParams{"MASTER_HOST"}, "$mcmd") ;
	my @Result = GetCommandResult() ;
	my @res ;
	foreach my $line (@Result) {
		chomp $line ;
		my $dsk = (split ('\s+', $line))[-1] ;
		push @res, $dsk ;
	}
	return @res ;
}
#-----------------------------------------------------------------------------#
sub GetMasterDisksID(@) {
	my @Disks = @_ ;
	my $ID = substr ($GroupParams{"LOCAL_EMC"},2,2) ;
	my $mcmd = "/usr/symcli/bin/syminq  | awk ' /EMC/ && \$(NF-1) ~ /^$ID/ ' " ;
	my $status = RunProgram  ($GroupParams{"MASTER_HOST"}, "$mcmd") ;
	my @Result = GetCommandResult() ;
	my @res ;
	foreach my $dsk (@Disks) {
			chomp $dsk ;
			my $DSK = (split ('/', $dsk))[-1] ;
			foreach my $line (@Result) {
				if ($line =~ /$DSK/) {
					my $inq = substr ((split ('\s+', $line))[-2], 3, 4) ;
					push @res, $inq ;
				}
			}
	}
	return @res ;
}
#-----------------------------------------------------------------------------#
sub GetTargetDisksID(@) {
	my @Disks = @_ ;
	my @res ;
	foreach my $inq (@Disks) {
			chomp $inq ;
			open (INP, "<$GroupsDir/$GROUP_NAME") ;
			foreach my $line (<INP>) {
				if ($line =~ /$inq/) {
					my $dsk = (split ('\s+', $line))[1] ;
					push @res, $dsk ;
				}
			}
	}
	return @res ;
}
#-----------------------------------------------------------------------------#
sub GetTargetDisksDev(@) {
	my @INQS = @_ ;
	my $ID = $GroupParams{"REMOTE_EMC"} ;
	# 25.05.2010 - Ilia G. Added 'grep disk' for HPUX 11v3 (The only place its used)
	my $mcmd = "/usr/symcli/bin/syminq -pdevfile | awk '  \$1 ~ /$ID/ ' | sort -u -k3 | grep disk" ;
	my $status = RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
	my @Result = GetCommandResult() ;
	my @res ;
	foreach my $inq (@INQS) {
			chomp $inq ;
			foreach my $line (@Result) {
				if ((split('\s+', $line))[2] =~ m/$inq/) {
					my $dsk = (split ('\s+', $line))[1] ;
					push @res, $dsk ;
				}
			}
	}
	return @res ;
}
#-----------------------------------------------------------------------------#
sub VGChgIDCmd(@) {
	my @Disks = @_ ;
	Info ("Changing VGID on disks : @Disks") ;
	my $mcmd = "/usr/sbin/vgchgid @Disks" ;
	my $status = RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
	if ($status ne 0) {
		Debug("VGChgIDCmd","Error: Cannot change VGID on @Disks \n");
		Exit ("Cannot change VG ID", 1) ;
	}
}
#-----------------------------------------------------------------------------#
sub GetVGMaps() {
	my $mcmd = "" ;
	my $status = "";
	Info ("Getting VG's maps") ;

	my $file = "" ;
	my $SourceFile = "" ;
	my $TargetFile = "" ;
	my @FullVGInfo = split (';', $GroupParams{"VG_LIST"}) ;


	foreach $vginfo (@FullVGInfo) {

		my $MasterVG = (split (':', $vginfo))[0] ;
		my $TargetVG = (split (':', $vginfo))[1] ;
		my $MinorNumber = (split (':', $vginfo))[2] ;

		$file = "/tmp/" . $TargetVG . ".map" ;
		$SourceFile = "$GroupParams{\"MASTER_HOST\"}" . ":" . $file ;
        $TargetFile = "$GroupParams{\"TARGET_HOST\"}" . ":" . $file ;

		$mcmd = "/usr/sbin/vgexport -v -s -p -m $file /dev/$MasterVG" ;
		$status = RunProgram  ($GroupParams{"MASTER_HOST"}, "$mcmd") ;
		if ($status ne 0) {
			Debug("GetVGMaps","Error: Cannot vgexport $vg on $GroupParams{\"MASTER_HOST\"}");
			Exit ("Error: Cannot vgexport $vg on $GroupParams{\"MASTER_HOST\"}", 1) ;
		}
        my $result = CopyFile($SourceFile, $TargetFile) ;
		if ($result ne 0) {
			Debug("GetVGMaps","Error:Cannot copy mapfile of $vg from $GroupParams{\"MASTER_HOST\"} to $GroupParams{\"TARGET_HOST\"}");
			Exit ("Error: Cannot copy mapfile of $vg from $GroupParams{\"MASTER_HOST\"} to $GroupParams{\"TARGET_HOST\"}", 1) ;
		}

		ExportVG ($TargetVG) ;

		CreateDeviceFile ($TargetVG, $MinorNumber) ;

		# If its HP-UX 11v3 (11.31) need to add -N for agile disks import
		if ( GetOSVerRemote($GroupParams{"TARGET_HOST"}) eq "B.11.31" ) {
			$mcmd = "/usr/sbin/vgimport -N -v -s -m $file /dev/$TargetVG" ;
		}else{
			$mcmd = "/usr/sbin/vgimport -v -s -m $file /dev/$TargetVG" ;
		}
		$status = RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
		if ($status ne 0) {
			Debug("GetVGMaps","Error: Cannot import $TargetVG on $GroupParams{\"TARGET_HOST\"}");
			Exit ("Error: Cannot import $TargetVG on $GroupParams{\"TARGET_HOST\"}", 1) ;
		}
	}
}
#-----------------------------------------------------------------------------#

sub ReCreateInformixLinks () {
	my $status = "";
	%LinkList = GetInformixLinks() ;
	$LinkFileScript = CreateTempFile() ;
	my @FullVGInfo = split (';', $GroupParams{"VG_LIST"}) ;

	Info ("Create 'Build Links file' on $GroupParams{\"TARGET_HOST\"}") ;
	open (OUT, ">$LinkFileScript") ;

	
	foreach $vginfo (@FullVGInfo) {

		my $MasterVG = (split (':', $vginfo))[0] ;
		my $TargetVG = (split (':', $vginfo))[1] ;
		$VGMaps{$MasterVG} = $TargetVG ;
	}


	foreach $link (keys %LinkList) {
		$mp = $LinkList{$link} ;
		@MP = split ('/', $mp) ;
		$MP[-1] = "" ;
		$mp1 = join ('/' , @MP) ;

		foreach $key (keys %VGMaps) {
			$link =~ s/$key/$VGMaps{$key}/g ;
		}

		print OUT "/bin/rm $mp\n" ;
		print OUT "/bin/mkdir -p $mp1\n" ;
		print OUT "/bin/ln -s $link $mp\n" ;
	}

	close OUT ;

	my $SourceFile = $RunnigHost . ":" . $LinkFileScript ;
	my $TargetFile = $GroupParams{"TARGET_HOST"} . ":" . $LinkFileScript ;
	my $result = CopyFile($SourceFile, $TargetFile) ;
	if ( $result == 0 ) {
		Info ("Create Links on $GroupParams{\"TARGET_HOST\"}") ;
		$status = RunProgram  ("$GroupParams{\"TARGET_HOST\"}", "/usr/bin/ksh $LinkFileScript") ;
		if ( $status ne 0 ) {
			Exit ("Can not Create link on $GroupParams{\"TARGET_HOST\"}", 1) ;
		}
	}
	foreach $key (keys %VGMaps) {
		Info ("Change Mod of links ($VGMaps{$key}) on $GroupParams{\"TARGET_HOST\"}") ;
		$mcmd = "/bin/chmod 660 /dev/$VGMaps{$key}/rlvol\*" ;
		$status = RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
		if ($status ne 0) {
			Exit ("Cannot change mode of rlvols $GroupParams{\"TARGET_HOST\"}", 1) ;
		}
		Info ("Change own to 'informix:informix' on $GroupParams{\"TARGET_HOST\"}") ;
		$mcmd = "/bin/chown informix:informix /dev/$VGMaps{$key}/rlvol\*" ;
		$status = RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
		if ($status ne 0) {
			Exit ("Cannot change own of rlvols $GroupParams{\"TARGET_HOST\"}", 1) ;
		}
	}
}
#-----------------------------------------------------------------------------#
sub CreateDeviceFile ($$) {
	my $VG_Name = shift ;
	my $Minor = shift ;
	my $mcmd = "";
	my $status = "";

	Info ("Creating Dir : /dev/$VG_Name") ;
	$mcmd = "/bin/mkdir /dev/$VG_Name" ;
	$status = RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
	if ($status ne 0) {
		Debug("CreateDeviceFile","Cannot Create /dev/$VG_Name \n");
		Exit ("Cannot Create /dev/$VG_Name", 1) ;
	}
	
	Info ("Creating Devicefile : /dev/$VG_Name/group") ;
	$mcmd = "/usr/sbin/mknod /dev/$VG_Name/group c 64 $Minor" ;
	$status = RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
	if ($status ne 0) {
		Debug("CreateDeviceFile","Error: Cannot Create /dev/$VG_Name/group \n");
		Exit ("Error: Cannot Create /dev/$VG_Name/group", 1) ;
	}

}
#-----------------------------------------------------------------------------#
sub BuildVG($$$@) {
	my $VG_Name = shift ;
	my $Minor = shift ;
	my $MapFile = shift ;
	my @Disks = @_ ;
	$Ind = 0 ;
	foreach $r (@Disks) {
		$Disks[$Ind] =~ s/rdsk/dsk/g ;
		$Disks[$Ind] =~ s|/rdisk/|/disk/|;
		$Ind++ ;
	}
	Info ("Creating new vg : $VG_Name whith Minor Number : $Minor , Map file $MapFile and Disks : @Disks") ;
	
	CreateDeviceFile ($VG_Name, $Minor) ;
	
	Info ("Importing VG") ;
	my $mcmd = "/usr/sbin/vgimport -m $MapFile /dev/$VG_Name @Disks" ;
	my $status = RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
	if ($status ne 0) {
		Debug("BuildVG","Error: Cannot import VG $VG_Name with the command $mcmd");
		Exit ("Error: Cannot Import VG $VG_Name with the command $mcmd", 1) ;
	}
}
#-----------------------------------------------------------------------------#
sub ExportVG($) {
	my $VG_Name = shift ;
	my $mcmd;
	my $status;
	
	Info ("Exporting VG : $VG_Name") ;
	$mcmd = "/usr/sbin/vgexport /dev/$VG_Name" ;
	$status = RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
	if ($status ne 0) {
		if ( GetOSTypeRemote($GroupParams{"TARGET_HOST"}) eq "HP-UX" ){
			Info("This is HP-UX machine");
			$mcmd = "/bin/strings /etc/lvmtab | /bin/grep -w $VG_Name" ;
			$status = RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
			if ($status eq 1) { # VG does NOT exists in lvmtab
				Info("Couldnt vgexport $VG_Name and its not in lvmtab, so deleting dir /dev/$VG_Name...");
				$mcmd = "/bin/rm -r /dev/$VG_Name 2>/dev/null";
				RunProgram  ($GroupParams{"TARGET_HOST"}, "$mcmd") ;
			} else { # VG exists in lvmtab
				Debug("ExportVG","Error: Cannot Export VG $VG_Name with the command $mcmd \n");
				Exit ("Error: Cannot Export VG $VG_Name with the command $mcmd", 1) ;
			}
		}
		else {
		Debug("ExportVG","Error: Cannot Export VG $VG_Name with the command $mcmd - NOT HP-UX\n");
		Exit ("Error: Cannot Export VG $VG_Name with the command $mcmd - NOT HP-UX", 1) ;
		}
	}
}

#-----------------------------------------------------------------------------#
sub VgChgID() {
	Info ("Getting all target VG's") ;
	foreach my $grp (split (';', $GroupParams{"VG_LIST"})) {
		my @data = split (':', $grp) ;
		ExportVG ($data[1]) ;
		my @VG_Disks = GetMasterVGDisks($data[0]) ;
		Info ("Master Host VG - $data[0].\nFound his device files: @VG_Disks\n") ;
		my @SRC_INQ  = GetMasterDisksID(@VG_Disks) ;
		Info ("Master Host VG - $data[0].\nFound his SYMMETRIX IDs: @SRC_INQ\n") ;
		my @TRG_INQ  = GetTargetDisksID(@SRC_INQ) ;
		Info ("Target Host VG - $data[1].\nFound his SYMMETRIX IDs: @TRG_INQ\n") ;
		my @TRG_DSK  = GetTargetDisksDev(@TRG_INQ) ;
		Info ("Target Host VG - $data[1].\nFound his device files: @TRG_DSK\n") ;
		VGChgIDCmd(@TRG_DSK) ;
		
		Info ("Getting VG's maps") ;
		my $MapSrcFile = "/tmp/" . $data[0] . ".map" ;
		my $MapDstFile = "/tmp/" . $data[1] . ".map" ;
		my $SourceFile = "$GroupParams{\"MASTER_HOST\"}" . ":" . $MapSrcFile ;
        my $TargetFile = "$GroupParams{\"TARGET_HOST\"}" . ":" . $MapDstFile ;

		$mcmd = "/usr/sbin/vgexport -v -s -p -m $MapSrcFile /dev/$data[0]" ;
		$status = RunProgram  ($GroupParams{"MASTER_HOST"}, "$mcmd") ;
		if ($status ne 0) {
			Debug("VgChgID","Error: Cannot vgexport (to map file) $data[0] on $GroupParams{\"MASTER_HOST\"}");
			Exit ("Error: Cannot vgexport (to map file) $data[0] on $GroupParams{\"MASTER_HOST\"}", 1) ;
		}
        my $result = CopyFile($SourceFile, $TargetFile) ;
		if ($result ne 0) {
			Debug("VgChgID","Error:Cannot copy mapfile of $data[0] from $GroupParams{\"MASTER_HOST\"} to $GroupParams{\"TARGET_HOST\"}");
			Exit ("Error: Cannot copy mapfile of $data[0] from $GroupParams{\"MASTER_HOST\"} to $GroupParams{\"TARGET_HOST\"}", 1) ;
		}
		BuildVG ($data[1] , $data[2] , $MapDstFile , @TRG_DSK) ;
	}
} 
#-----------------------------------------------------------------------------#
# Step 65 : After Hot Split !                                                 #
#-----------------------------------------------------------------------------#
sub AfterHotSplit() {
	# MainSQL File needs to be run again to cerate dynamicly ACTIVE tablespaces
	Create_sql_files() ;
	
	# Return to Regular Mode
	EndHotBackupMode() ;

	# Check Table-Space Status Hot / Cold !
	my $result = CheckHotStatusLog () ;
	if ($result ne 1) {		# You are in HotBackup mode
		EndHotBackupMode() ;
	}

	# Create Control File !
	CreateControlFile() ;

	# Alter System Switch Logfile !
	SwitchLogfile() ;
	sleep 60 ;

	# Select The Last SCN
	Select_Scn_Num ($WorkingFiles{"HOT_SCN_AFTER"}) ;
	
	if ( $GroupParams{"DB_TYPE"} eq "ASM" ){
		# Alter System Switch Logfile again
		SwitchLogfile() ;
	}

	# Select Control File Path !
	SelectControlFile() ;

	# Select The Archive List To Copy  !
	CreateArchiveList() ;
}
#-----------------------------------------------------------------------------#
# Step 75 : mount filesystems on the target host !                            #
#-----------------------------------------------------------------------------#
sub MountTargetFS() {
	if ($GroupParams{"SERVERS_LIST"} =~ /none/) {
		MountTargetHost("TARGET") ;	
	}
	else {
		Info("NFS Config");
		MountNFSHosts("TARGET") ;
	}
}
#-----------------------------------------------------------------------------#
# Step 77 : copy files to the target host !!!                                 #
#-----------------------------------------------------------------------------#
sub CopyFiles2Target() {
	Info ("Copying file to target host !") ;

	my %FileList = () ;
	$FileList{"HOT_SCN_AFTER"} = $WorkingFiles{"HOT_SCN_AFTER"} ;
	$FileList{"SEL_CONTROL_FILES"} = $WorkingFiles{"SEL_CONTROL_FILES"} ;
	$FileList{"SEL_ARCH_LIST"} = $WorkingFiles{"SEL_ARCH_LIST"} ;
	$FileList{"CTL"} = $WorkingFiles{"CTL"} ;

	foreach my $file (values %FileList) {
		Info ("Copying $file ...") ;
		my $SourceFile = $RunnigHost . ":" . $file ;
		my $BaseFileName = (split ('/', $file))[-1] ;
		my $TargetFile = $CopyTarget . ":" . $GroupParams{"CP_TARGET_DIR"} . "/" . $BaseFileName ;
		my $result = CopyFile($SourceFile, $TargetFile) ; 
		Info("$SourceFile ===> $TargetFile\n") ;
		if ($result ne 0) {
			Debug("CopyFiles2Target","Error: Cannot copy $RunnigHost to $TargetFile");
			Exit ("Error: Can not copy the $file from $RunnigHost to $TargetFile", 1) ;
		}
	}
	Info ("Copying file to target host $OK") ;
	
	# Oracle ASM - dont need to copy archives
	if ( $GroupParams{"DB_TYPE"} eq "ASM" ) {
		return;
	}
	
   	my $VERSION = GetOracleVersion($WorkingFiles{"VERSION_FILE"}) ;
	Info ("The Oracle VERSION Is $VERSION.") ;
	# Select The Archive List To Copy  !
	Info ("Sleeping for 300 sec. ") ;
	sleep 300 ;  # this is because of Oracle Dictionary update
	CreateArchiveList() ; 

	Info ("Copying Archives files from MasterHost to TargetHost") ;
	open (ARC,"<$WorkingFiles{\"SEL_ARCH_LIST\"}") || warn "Can not open Archive File list !!" ;
	foreach my $file (<ARC>) {
		chomp $file ;
		$file =~ s/ //g ;
		Info ("Copying $file ...") ;
		my $SourceFile = $GroupParams{"MASTER_HOST"} . ":" . $file ;
		my $BaseFileName = (split ('/', $file))[-1] ;
		my $TargetFile = $CopyTarget . ":" . $GroupParams{"CP_TARGET_DIR"} . "/" . $BaseFileName ;
		my $result = CopyFile($SourceFile, $TargetFile) ; 
		if ($result ne 0) {
			Info ("Can not copy $file , trying to copy Compressed file") ;
			$SourceFile = $GroupParams{"MASTER_HOST"} . ":" . $file . ".Z";
			$TargetFile = $CopyTarget . ":" . $GroupParams{"CP_TARGET_DIR"} . "/" . $BaseFileName . "\.Z";
			$result = CopyFile($SourceFile, $TargetFile) ; 
			if ($result ne 0) {
				Info ("Can not copy Compressed file , trying to copy ZIP file") ;
				$SourceFile = $GroupParams{"MASTER_HOST"} . ":" . $file . ".gz";
				$TargetFile = $CopyTarget . ":" . $GroupParams{"CP_TARGET_DIR"} . "/" . $BaseFileName . "\.gz";
				$result = CopyFile($SourceFile, $TargetFile) ; 
				if ($result ne 0) {
					Debug("CopyFiles2Target","Error: Cannot copy any type of archive $file \n");
					Exit ("Error: Can not copy any type of Archive file <$file> !!!", 1) ;
				}else{
					my $mcmd = "/usr/bin/gunzip " . $GroupParams{"CP_TARGET_DIR"} . "/" . $BaseFileName . "\.gz" ;
					my $status = RunProgram  ($CopyTarget, "$mcmd") ;
					if ($status ne 0) {
						Debug("CopyFiles2Target","Error: Cannot gunzip $file on $CopyTarget \n");
						Exit ("Error: Can not gunzip $file on $CopyTarget",1) ;
					}else{
						Info ("Unzip the file :<$file> $OK") ;
					}
				}				
			}else{
				Info ("Uncompress the file :<$BaseFileName>") ;
				my $mcmd = "/bin/uncompress " . $GroupParams{"CP_TARGET_DIR"} . "/" . $BaseFileName ;
				my $status = RunProgram  ($CopyTarget, "$mcmd") ;
				if ($status ne 0) {
					Debug("CopyFiles2Target","Error: Cannot uncompress file $file on $CopyTarget \n");
					Exit ("Error: Can not Uncompress $file on $CopyTarget",1) ;
				}else{
					Info ("Uncompress the file :<$file> $OK") ;
				}
			}
		}
	}
	close ARC ;
	Info ("Copying Archives files from MasterHost to TargetHost $OK") ;
}
#-----------------------------------------------------------------------------#
# Step 80 : Up the DB on the target host !!!                                  #
#-----------------------------------------------------------------------------#
sub UpTargetDB () {
	if ($GroupParams{"UP_TARGET"} eq "true") {
		Info ("Starting Up the DB on the target Host !") ;
		UpDB("TARGET") ;
	}else{
		Info ("No Need to up the target DB") ;
	}
}
#-----------------------------------------------------------------------------#
# Step 85 : Run Split Post Command !!                                         #
#-----------------------------------------------------------------------------#
sub SplitPostCommand() {
	Info ("Running PostSplit Command") ;
	Pre_Post_Command ("POST", "SPLIT") ;
	Info ("Running PostSplit Command $OK") ;
}
###############################################################################
#                                                                             #
#          Cold Split Steps                                                   #
#                                                                             #
###############################################################################
#-----------------------------------------------------------------------------#
# Step  : ShutDown the DB on the master host !!!                              #
#-----------------------------------------------------------------------------#
sub ShutDownMasterDB ()	{	ShutDownDB("MASTER") ;}
#-----------------------------------------------------------------------------#
# Step  : umount filesystems on the master host !!!                           #
#-----------------------------------------------------------------------------#
sub UmountMasterFS()	{	UmountHost("MASTER") ;}
#-----------------------------------------------------------------------------#
# Step  : Mount filesystems on the master host !!!                            #
#-----------------------------------------------------------------------------#
sub MountMasterFS()		{	MountHost("MASTER") ;}
#-----------------------------------------------------------------------------#
# Step 70 : Up the DB on the master host !!!                                  #
#-----------------------------------------------------------------------------#
sub UpMasterDB ()		{	UpDB("MASTER") ;}
#-----------------------------------------------------------------------------#
# Step 55 : Prepare for Cold Split !                                          #
#-----------------------------------------------------------------------------#
sub PrepForColdSplit() {
	if ($GroupParams{"SERVICE_GAURD"} eq "yes") {
		Info ("Halting PKG $GroupParams{\"PKG_NAME\"} on $GroupParams{\"MASTER_HOST\"} !") ;
		my $mcmd = "/usr/sbin/cmhaltpkg -v " . $GroupParams{"PKG_NAME"} ; 
		my $status = RunProgram  ($GroupParams{"MASTER_HOST"}, "$mcmd") ;
		Check_Exit ($status, "Halt PKG - $GroupParams{\"PKG_NAME\"} ", $GroupParams{"MASTER_HOST"}) ;
	}elsif($GroupParams{"RH_CLUSTER"} eq "yes") {
		Info ("Stopping PKG $GroupParams{\"PKG_NAME\"} on $GroupParams{\"MASTER_HOST\"}");
		my $mcmd = "clusvcadm -d " . $GroupParams{"PKG_NAME"} ;
		my $ExitCode = RunProgram($GroupParams{"MASTER_HOST"}, "$mcmd") ;
		if ( $ExitCode ne 0 ) {
			Exit ("Error: Cannot Stop PKG $GroupParams{\"PKG_NAME\"} on $GroupParams{\"MASTER_HOST\"}",1);
		}
	}else{
		ShutDownMasterDB() ;
		UmountMasterFS() ;
		VGChangeAfterUmountM() ;
	}
}
#-----------------------------------------------------------------------------#
# Step 65 : After Cold Split !                                                #
#-----------------------------------------------------------------------------#
sub AfterColdSplit() {
	my $mcmd = "";
	my $status = "";
	if ($GroupParams{"SERVICE_GAURD"} eq "yes") {
		Info ("Running PKG $GroupParams{\"PKG_NAME\"} on $GroupParams{\"MASTER_HOST\"} !") ;
		$mcmd = "/usr/sbin/cmrunpkg -v " . $GroupParams{"PKG_NAME"} ; 
		$status = RunProgram  ($GroupParams{"MASTER_HOST"}, "$mcmd") ;
		Check_Exit ($status, "Run PKG - $GroupParams{\"PKG_NAME\"} On", $GroupParams{"MASTER_HOST"}) ;
		$mcmd = "/usr/sbin/cmmodpkg -e " . $GroupParams{"PKG_NAME"} ; 
		$status = RunProgram  ($GroupParams{"MASTER_HOST"}, "$mcmd") ;
		Check_Exit ($status, "Enable PKG - $GroupParams{\"PKG_NAME\"} On", $GroupParams{"MASTER_HOST"}) ;
	}elsif($GroupParams{"RH_CLUSTER"} eq "yes") {
		Info("Starting PKG $GroupParams{\"PKG_NAME\"} on $GroupParams{\"MASTER_HOST\"}");
		my $mcmd = "clusvcadm -e " . $GroupParams{"PKG_NAME"} ;
		my $ExitCode = RunProgram($GroupParams{"MASTER_HOST"}, "$mcmd") ;
		if ( $ExitCode ne 0 ) {
			Exit ("Error: Cannot Start PKG $GroupParams{\"PKG_NAME\"} on $GroupParams{\"MASTER_HOST\"}",1);
		}
	}else{
		VGChangeBeforMountM() ;
		MountMasterFS() ;
		UpMasterDB() ;
	}
}
sub VGChangeAfterUmountM() {
	# Build target VG List
	Info ("Getting Master VG List") ;
	my @allVglist = split (';', $GroupParams{"VG_LIST"}) ;
	my @MasterVGs ;
	foreach my $value (@allVglist) {
		my $VG = (split (':', $value))[0] ;
		push (@MasterVGs, $VG) ;
	}
	Debug ("VGChangeAfterUmount", "the Master vg's are : @MasterVGs") ;
	Info ("Getting Master VG List - Done.") ;

	foreach my $vg (@MasterVGs) {
		#added by Haim 	
		Info ("Running : vgchange -a n $vg") ;
		my $mcmd = "/usr/sbin/vgchange -a n $vg" ;
		my $ExitCode = ReTry ($GroupParams{"MASTER_HOST"}, $mcmd) ;
		if ($ExitCode ne 0) {
			Debug("VGChangeAfterUmountM","Error: Cannot vgchange $vg with $mcmd on $GroupParams{\"MASTER_HOST\"}");
			Exit ("Error: Cannot vgchange $vg with $mcmd on $GroupParams{\"MASTER_HOST\"}", 1) ;
		}
		Info ("vgchange -a n $vg - $OK") ;
		#added by Haim 
	}
}
sub VGChangeBeforMountM() {
	# Build target VG List
	Info ("Getting Master VG List") ;
	my @allVglist = split (';', $GroupParams{"VG_LIST"}) ;
	my @MasterVGs ;
	foreach my $value (@allVglist) {
		my $VG = (split (':', $value))[0] ;
		push (@MasterVGs, $VG) ;
	}
	Debug ("VGChangeBeforMountM", "the Master vg's are : @MasterVGs") ;
	Info ("Getting Master VG List - Done.") ;

	foreach my $vg (@MasterVGs) {
		Info ("Running : vgchange -a y $vg") ;
		my $mcmd = "/usr/sbin/vgchange -a y $vg" ;
		my $ExitCode = ReTry ($GroupParams{"MASTER_HOST"}, $mcmd) ;
		if ($ExitCode ne 0) {
			Debug("VGChangeBeforMountM","Error: Cannot vgchange $vg with $mcmd on $GroupParams{\"MASTER_HOST\"}");
			Exit ("Error: Cannot vgchange $vg with $mcmd on $GroupParams{\"MASTER_HOST\"}", 1) ;
		}
		Info ("vgchange -a y $vg - $OK") ;
	}
}
###############################################################################
#                                                                             #
#          Informix Steps Section common                                      #
#                                                                             #
###############################################################################
#-----------------------------------------------------------------------------#
# Step 55 : Insert the informix on the master to HotBackup Mode !!           #
#-----------------------------------------------------------------------------#
sub InformixHotSplit() {
	my $mcmd = "";
	my $ExitCode;
	#Added by Itai Weisman - DB fake backup - by Galit's request, November 8th, 2006
	Info ("applying fake backup") ;
	$mcmd = "su - informix -c \"$GParam{\"OnBar\"} -b -F\" >/dev/null 2>&1" ;
	$ExitCode = RunProgram ($GroupParams{"MASTER_HOST"}, $mcmd) ;
	if ($ExitCode ne 0) {
		Exit ("Informix fake backup - Failed !!!", 1) ;
	}
	Info ("Informix Fake  Backup $OK") ;
	# End of section added on November 8th, 2006
	Info ("Inserting Informix to HotBackup Mode") ;
	$mcmd = "su - informix -c \"$GParam{\"OnMode\"} -l\" >/dev/null 2>&1" ;
	$ExitCode = RunProgram ($GroupParams{"MASTER_HOST"}, $mcmd) ;
	sleep 60 ;
	$mcmd = "su - informix -c \"$GParam{\"OnMode\"} -c block\" >/dev/null 2>&1" ;
	$ExitCode = RunProgram ($GroupParams{"MASTER_HOST"}, $mcmd) ;
	if ($ExitCode ne 0) {
		Debug("InformixHotSplit","Error: Insert Informix to HotBackup Mode - Failed");
		Exit ("Error: Insert Informix to HotBackup Mode - Failed !!!", 1) ;
	}
	Info ("Inserting Informix to HotBackup Mode $OK") ;
}
#-----------------------------------------------------------------------------#
# Step 65 : Return the informix on the master to Regular Mode !!              #
#-----------------------------------------------------------------------------#
sub InformixRegMode() {
	Info ("Return Informix to Regular Mode") ;
	my $mcmd = "su - informix -c \"$GParam{\"OnMode\"} -c unblock\" >/dev/null 2>&1" ;
	my $ExitCode = RunProgram ($GroupParams{"MASTER_HOST"}, $mcmd) ;
	if ($ExitCode ne 0) {
		Debug("InformixRegMode","Error: Return Informix to Regular Mode - Failed. The command $mcmd");
		Exit ("Error: Return Informix to Regular Mode - Failed !!!. The command $mcmd", 1) ;
	}
	Info ("Return Informix to Regular Mode $OK") ;
}
###############################################################################
#                                                                             #
#          HP-UX Steps Section common                                         #
#                                                                             #
###############################################################################
#-----------------------------------------------------------------------------#
# Step 25 : VgChange after umount on the target !                             #
#-----------------------------------------------------------------------------#
sub VGChangeAfterUmount() {
	# Build target VG List
	Info ("Getting Target VG List") ;
	my @allVglist = split (';', $GroupParams{"VG_LIST"}) ;
	my @TargetVGs ;
	foreach my $value (@allVglist) {
		my $VG = (split (':', $value))[1] ;
		push (@TargetVGs, $VG) ;
	}
	Debug ("VGChangeAfterUmount", "The target vg's are : @TargetVGs") ;
	Info ("Getting Target VG List - Done.") ;
	
	foreach my $vg (@TargetVGs) {
		# Disable cluster attribute on Linux
		if ($GroupParams{"OS_VERSION"} eq "Linux") {
			Info ("Running : vgchange -c n $vg --config 'global {locking_type = 0}'") ;
			my $mcmd = "/usr/sbin/vgchange -c n $vg --config 'global {locking_type = 0}'" ;
			my $ExitCode = ReTry ($GroupParams{"TARGET_HOST"}, $mcmd) ;
			if ($ExitCode ne 0 && $ExitCode ne 5) {
				Debug("VGChangeAfterUmount","Error: Cannot vgchange $vg on $GroupParams{\"TARGET_HOST\"}. Command: $mcmd");
				Exit ("Error: Cannot vgchange $vg on $GroupParams{\"TARGET_HOST\"}. Command: $mcmd", 1) ;
			}
			Info ("Disable Cluster Attribute - $OK") ;
		}
	}

	foreach my $vg (@TargetVGs) {
		Info ("Running : vgchange -a n $vg") ;
		my $mcmd = "/usr/sbin/vgchange -a n $vg" ;
		my $ExitCode = ReTry ($GroupParams{"TARGET_HOST"}, $mcmd) ;
		if ($ExitCode ne 0) {
			Debug("VGChangeAfterUmount","Error: Cannot vgchange $vg on $GroupParams{\"TARGET_HOST\"}");
			#Exit ("Error: Can not vgchange $vg on $GroupParams{\"TARGET_HOST\"}", 1) ;
		}
		Info ("vgchange -a n $vg - $OK") ;
	}
}
#-----------------------------------------------------------------------------#
# Step 70 : VgChange Before Mount on the target !                             #
#-----------------------------------------------------------------------------#
sub VGChangeBeforMmount() {
	# Build target VG List
	# VGIM = 1 -> vgimport
	Info ("Checking if I need to vgchangeid or vgimport (VGIM = $VGIM)");
	if ($VGIM && $GroupParams{OS_VERSION} ne "Linux") {
		if ($GroupParams{"MAP_FILL"} eq "1" ) {
			GetVGMaps () ;
		}else {
			VgChgID() ;
		}
	}

	if ($GroupParams{"DATABASE_NAME_MASTER"} eq "INFORMIX") {
		&ReCreateInformixLinks() ;
	}

	Info ("Getting Target VG List") ;
	my @allVglist = split (';', $GroupParams{"VG_LIST"}) ;
	my @TargetVGs ;
	foreach my $value (@allVglist) {
		my $VG = (split (':', $value))[1] ;
		push (@TargetVGs, $VG) ;
	}
	Debug ("VGChangeAfterUmount", "The target vg's are : @TargetVGs") ;
	Info ("Getting Target VG List - Done.") ;

	foreach my $vg (@TargetVGs) {
		if ($GroupParams{"SERVICE_GAURD"} eq "yes") {
			Info ("Running : vgchange -c n $vg") ;
			my $mcmd = "/usr/sbin/vgchange -c n $vg" ;
			my $ExitCode = ReTry ($GroupParams{"TARGET_HOST"}, $mcmd) ;
			if ($ExitCode ne 0) {
				Debug("VGChangeBeforMmount","Error: Cannot vgchange $vg on $GroupParams{\"TARGET_HOST\"}. Command: $mcmd");
				Exit ("Error: Cannot vgchange $vg on $GroupParams{\"TARGET_HOST\"}. Command: $mcmd", 1) ;
			}
			Info ("vgchange -c n $vg - $OK") ;
		}
		
		# Disable cluster attribute on Linux
		if ($GroupParams{"OS_VERSION"} eq "Linux") {
			Info ("Running : vgchange -c n $vg --config 'global {locking_type = 0}'") ;
			my $mcmd = "/usr/sbin/vgchange -c n $vg --config 'global {locking_type = 0}'" ;
			my $ExitCode = ReTry ($GroupParams{"TARGET_HOST"}, $mcmd) ;
			if ($ExitCode ne 0 && $ExitCode ne 5) {
				Debug("VGChangeBeforMmount","Error: Cannot vgchange $vg on $GroupParams{\"TARGET_HOST\"}. Command: $mcmd");
				Exit ("Error: Cannot vgchange $vg on $GroupParams{\"TARGET_HOST\"}. Command: $mcmd", 1) ;
			}
			Info ("Disable Cluster Attribute - $OK") ;
		}
		
		Info ("Running : vgchange -a y $vg") ;
		my $mcmd = "/usr/sbin/vgchange -a y $vg" ;
		my $ExitCode = ReTry ($GroupParams{"TARGET_HOST"}, $mcmd) ;
		if ($ExitCode ne 0) {
			Debug("VGChangeBeforMmount","Error: Cannot vgchange $vg on $GroupParams{\"TARGET_HOST\"}. Command: $mcmd");
			Exit ("Error: Cannot vgchange $vg on $GroupParams{\"TARGET_HOST\"}. Command: $mcmd", 1) ;
		}
		Info ("vgchange -a y $vg - $OK") ;
	}
}
###############################################################################
#                                                                             #
#          SUN Steps Section common                                           #
#                                                                             #
###############################################################################
#-----------------------------------------------------------------------------#
# Step 25 : Delete the Metaset on the target host !                           #
#-----------------------------------------------------------------------------#
sub DeleteMetaSet() {
	my @MetaSets = split ('\|', $GroupParams{"TARGET_FILESYSTEM"}) ;
	Info ("The MetaSets are : @MetaSets") ;
	foreach my $metaset (@MetaSets) {
		$metaset =~ s/\///g ;
		Info ("Release $metaset on $GroupParams{\"TARGET_HOST\"}") ;
		my $res = ReleasDG ($GroupParams{"TARGET_HOST"}, $metaset) ;
		if ($res ne 0) {
			Debug("DeleteMetaSet","Error: Cannot release MetaSet $metaset on $GroupParams{\"TARGET_HOST\"}");
			Exit ("Error: Cannot release MetaSet $metaset on $GroupParams{\"TARGET_HOST\"}", 1) ;
		}else{
			Info ("Release $metaset on $GroupParams{\"TARGET_HOST\"} $OK") ;
		}
		Info ("Delete $metaset on $GroupParams{\"TARGET_HOST\"}") ;
		$res = DeleteDG ($GroupParams{"TARGET_HOST"}, $metaset) ;
		if ($res ne 0) {
			Debug("DeleteMetaSet","Error: Cannot delete MetaSet $metaset on $GroupParams{\"TARGET_HOST\"}");
			Exit ("Error: Cannot delete MetaSet $metaset on $GroupParams{\"TARGET_HOST\"}", 1) ;
		}else{
			Info ("Delete $metaset on $GroupParams{\"TARGET_HOST\"} $OK") ;
		}
	}
}

#-----------------------------------------------------------------------------#
# Move The Old Sql Files To The Backup Dir !                                  #
#-----------------------------------------------------------------------------#
sub MoveOldSqlFiles() {
	Info ("Moving Old SQL Files.....") ;
	foreach $file (keys %WorkingFiles) {
		my $savefile = `basename $file` ;
		Info ("Saving $file") ;
		my $res = RunProgram ("local", "ls $file >/dev/null 2>&1") ;
		if ( $res eq 0 ) {
			my $TargetFile = $SaveDir ."/" . $savefile . "." . $DATE ;
			Info (" Moving $file to $TargetFile") ;
			$res = RunProgram ("local", "/bin/mv $file $TargetFile") ;
			Check_Exit ($res, " Move $savefile to $SaveDir", "LocalHost") ;
		}
	}
	Info ("Moving Old SQL Files $OK") ;
}
#-----------------------------------------------------------------------------#
# create Sql's For The  Hot-Split Proccess !                                   #
#-----------------------------------------------------------------------------#
sub Create_sql_files() {
	my $r;
	Info ("Creating SQL Files") ;
	Info ("Building The Main SQL File") ;
	my $VERSION = GetOracleVersion($WorkingFiles{"VERSION_FILE"}) ;
	our $MainSQL_File = CreateTempFile() ;
	Debug ("Create_sql_files", "Opening $MainSQL_File") ;
	open (MainSQL, ">$MainSQL_File") || die "Can not create $MainSQL_File\n" ;
	print MainSQL "spool $WorkingFiles{\"HOT_SPLIT_SQL_BEGIN\"} ;\n" ;
	print MainSQL "select 'spool $WorkingFiles{\"HOT_SPLIT_SQL_BEGIN_LOG\"}' from dual ;\n" ;
	print MainSQL "select 'whenever sqlerror  exit 1' from dual ;\n" ;
	if ( $VERSION eq "Oracle11g" ) {
		print MainSQL "select 'alter system archive log current ;' from dual ;\n" ;
		print MainSQL "select 'alter database begin backup ;' from dual ;\n" ;
	} else {
		print MainSQL "select 'alter system switch logfile ;' from dual ;\n" ;
		print MainSQL "select 'alter tablespace ' || TABLESPACE_NAME || ' begin backup ;'\n" ;
		print MainSQL "from dba_tablespaces\n" ;
		print MainSQL "where tablespace_name in (select tablespace_name\n" ;
		print MainSQL "from dba_data_files\n" ;
		print MainSQL "where dba_tablespaces.tablespace_name = dba_data_files.tablespace_name);\n" ;
	}
	print MainSQL "select 'spool off' from dual;\n" ;
	print MainSQL "spool $WorkingFiles{\"HOT_SPLIT_SQL_END\"} ;\n" ;
	print MainSQL "select 'spool $WorkingFiles{\"HOT_SPLIT_SQL_END_LOG\"}' from dual;\n" ;
	print MainSQL "select 'whenever sqlerror  exit 1' from dual;\n" ;
	if ( $VERSION eq "Oracle11g" ) {
		print MainSQL "select 'alter database end backup ;' from dual ;\n" ;
	} else {
		print MainSQL "select 'alter tablespace ' || TABLESPACE_NAME || ' end backup;'\n" ;
		print MainSQL "from dba_tablespaces\n" ;
		print MainSQL "where tablespace_name in (select tablespace_name\n" ;
		print MainSQL "from dba_data_files\n" ;
		print MainSQL "where file_id in (select file# from v\$backup where status='ACTIVE'));\n" ;
	}
	print MainSQL "select 'spool off' from dual;\n" ;
	print MainSQL "spool off\n" ;
	close MainSQL ;
	Debug ("Create_sql_files", "$MainSQL_File Created !!!") ;
	Debug ("Create_sql_files", "Running $MainSQL_File") ;
	Info ("Running The Main SQL File") ;

	$r = RunSqlCommand ($MainSQL_File) ;
	if ($r eq 0) {
		Info ("The Main SQL File run Successfuly") ;
	}else{
		system ("cp $MainSQL_File $SQLDir/Main_SQL.$$") ;
		Debug("Create_sql_files","Error: There is problem Running The Main SQL File $MainSQL_File");
		Exit ("Error: There is problem Running The Main SQL File $MainSQL_File", 1) ;
	}
	Debug ("Create_sql_files", "The Exit Code is $r") ;

	if ($GroupParams{"DB_TYPE"} eq "ASM") {

		# Creating ASM rebalance SQL scripts
		Info ("Building ASM rebalance SQL scripts") ;
		my $ASMSQL_File = CreateTempFile() ;
		Debug ("Create_sql_files", "Opening $ASMSQL_File") ;
		open (ASMSQL, ">$ASMSQL_File") || die "Can not create $ASMSQL_File\n" ;
		print ASMSQL "spool $WorkingFiles{\"ASM_REBALANCE_STOP\"} ;\n" ;
		print ASMSQL "select 'spool $WorkingFiles{\"ASM_REBALANCE_STOP_LOG\"}' from dual ;\n" ;
		print ASMSQL "select 'whenever sqlerror  exit 1' from dual ;\n" ;
		print ASMSQL "select 'alter diskgroup '||name||' rebalance power 0 ;'\n" ;
		print ASMSQL "from v\$asm_diskgroup\n" ;
		print ASMSQL "where name like '%DATA%';\n" ;
		print ASMSQL "select 'spool off' from dual;\n" ;
		print ASMSQL "spool $WorkingFiles{\"ASM_REBALANCE_START\"}\n" ;
		print ASMSQL "select 'spool $WorkingFiles{\"ASM_REBALANCE_START_LOG\"}' from dual;\n" ;
		print ASMSQL "select 'whenever sqlerror  exit 1' from dual;\n" ;
		print ASMSQL "select 'alter diskgroup '||name||' rebalance power $RebalancePower ;'\n" ;
		print ASMSQL "from v\$asm_diskgroup\n" ;
		print ASMSQL "where name like '%DATA%';\n" ;
		print ASMSQL "select 'spool off' from dual;\n" ;
		print ASMSQL "spool off\n" ;
		close ASMSQL ;
		Debug ("Create_sql_files", "$ASMSQL_File Created !!!") ;
		Debug ("Create_sql_files", "Running $ASMSQL_File") ;
		Info ("Running The Main SQL File") ;

		SetTNS ($GroupParams{"ASM_TNSNAME"}) ;
		$r = RunASMCommand ($ASMSQL_File) ;
		if ($r eq 0) {
			Info ("The ASM SQL File run Successfuly") ;
		}else{
			system ("cp $ASMSQL_File $SQLDir/ASM_SQL.$$") ;
			Debug("Create_sql_files","Error: There is problem Running The ASM SQL File $ASMSQL_File");
			Exit ("Error: There is problem Running The ASM SQL File $ASMSQL_File", 1) ;
		}
		Debug ("Create_sql_files", "The Exit Code is $r") ;
		SetTNS ($GroupParams{"TNS_NAME"}) ;
		
		
	}

	# Backup Control File !
	# There is a Special Case for ASM (11g)
	if ($GroupParams{"DB_TYPE"} eq "ASM") {
		OpenFile ($WorkingFiles{"ALTER_CONTROL_FILE"}) ;
		print OUT "spool $WorkingFiles{\"ALTER_CONTROL_FILE_LOG\"}\n" ;
		print OUT "whenever sqlerror  exit 1;\n" ;
		print OUT "alter database backup controlfile to '$GroupParams{\"ASM_CF_DISK\"}';\n" ;
		print OUT "spool off\n" ;
		print OUT "exit\n" ;
		close OUT ;
	} else { # NOT ASM
		OpenFile ($WorkingFiles{"ALTER_CONTROL_FILE"}) ;
		my $control_file_name = "/tmp/" . $GROUP_NAME . ".ctl" ;
		print OUT "spool $WorkingFiles{\"ALTER_CONTROL_FILE_LOG\"}\n" ;
		print OUT "whenever sqlerror  exit 1;\n" ;
		print OUT "alter database backup controlfile to '$control_file_name';\n" ;
		print OUT "spool off\n" ;
		print OUT "exit\n" ;
		close OUT ;
	}

	
	# DB Status (Regular / HotBackup Mode) !
	OpenFile ($WorkingFiles{"DB_MODE"}) ;
	print OUT "spool $WorkingFiles{\"HOT_SPLIT_STATUS_LOG\"}\n" ;
	print OUT "select status from v\$backup;\n" ;
	print OUT "spool off\n" ;
	print OUT "exit\n" ;
	close OUT ;

	# Switch Log File !
	OpenFile ($WorkingFiles{"ALTER_SWITCH_LOGFILE"}) ;
	print OUT "spool $WorkingFiles{\"SWITCH_FILE_LOG\"}\n" ;
	print OUT "whenever sqlerror  exit 1;\n" ;
	if ( $VERSION eq "Oracle11g" ) {
		print OUT "alter system archive log current;\n" ;
	} else {
		print OUT "alter system switch logfile;\n" ;
	}
	print OUT "spool off\n" ;
	print OUT "exit\n" ;
	close OUT ;

	# Select Oracle8i archive List !
	OpenFile ($WorkingFiles{"HOT_ARCH_LIST_ORACLE8I"}) ;
	print OUT "spool $WorkingFiles{\"SEL_ARCH_LIST\"}\n" ;
	print OUT "whenever sqlerror exit 1;\n" ;
	print OUT "select name from v\$archived_log where first_change# between &1 and &2;\n" ;
	print OUT "spool off\n" ;
	print OUT "exit\n" ;
	close OUT ;

	# Select Oracle archive List !
	OpenFile ($WorkingFiles{"HOT_ARCH_LIST_ORACLE"}) ;
	print OUT "spool $WorkingFiles{\"SEL_ARCH_LIST\"}\n" ;
	print OUT "whenever sqlerror exit 1;\n" ;
	print OUT "select name from v\$archived_log where first_change# between &1 and &2 and dest_id=1;\n" ;
	print OUT "spool off\n" ;
	print OUT "exit\n" ;
	close OUT ;

	# Select Oracle RAC archive List !
	OpenFile ($WorkingFiles{"HOT_ARCH_LIST_ORACLE_RAC"}) ;
	print OUT "spool $WorkingFiles{\"SEL_ARCH_LIST\"}\n" ;
	print OUT "whenever sqlerror exit 1;\n" ;
	print OUT "select name from v\$archived_log where first_change# between &1 and &2;\n" ;
	print OUT "spool off\n" ;
	print OUT "exit\n" ;
	close OUT ;

	OpenFile ($WorkingFiles{"HOT_SPLIT_SCN"}) ;
	print OUT "spool &1\n" ;
	print OUT "whenever sqlerror  exit 1;\n" ;
	print OUT "col max(FIRST_CHANGE#) format 9999999999999999\n" ;
	print OUT "select max(FIRST_CHANGE#) from v\$log where status='CURRENT';\n" ;
	print OUT "spool off\n" ;
	print OUT "exit\n" ;
	close OUT ;

	OpenFile ($WorkingFiles{"HOT_SPLIT_CTL_PATH"}) ;
	print OUT "spool $WorkingFiles{\"SEL_CONTROL_FILES\"}\n" ;
	print OUT "whenever sqlerror  exit 1;\n" ;
	print OUT "select name from v\$controlfile;\n" ;
	print OUT "spool off\n" ;
	print OUT "exit\n" ;
	close OUT ;

	OpenFile ($WorkingFiles{"REPER_BACKUP_MODE"}) ;
	print OUT "spool $WorkingFiles{\"REPER_BACKUP_MODE_ALTER\"}\n" ;
	print OUT "whenever sqlerror  exit 1;\n" ;
	print OUT "select 'alter tablespace ' || tablespace_name || ' end backup ;'\n" ;
	print OUT "from  v\$backup,dba_data_files\n" ;
	print OUT "where v\$backup.status='ACTIVE'\n" ;
	print OUT "and file#=file_id\n" ;
	print OUT "and  file# in (select min(file_id)\n" ;
	print OUT "from dba_data_files\n" ;
	print OUT "group by TABLESPACE_NAME);\n" ;
	print OUT "spool off\n" ;
	print OUT "exit\n" ;
	close OUT ;

	# Get Oracle10G RAC Value 
	OpenFile ($WorkingFiles{"ORACLE10_VERSION"}) ;
	print OUT "spool $WorkingFiles{\"RAC_VALUE\"}\n" ;
	print OUT "select value from v\$option where parameter='Real Application Clusters'" ; 
	print OUT "spool off\n" ;
	print OUT "exit\n" ;
	close OUT;

	if ($GroupParams{"DB_TYPE"} eq "ASM") {
		system ("rm $ASMSQL_File") ;
	}
	
	return $? ;
}
#-----------------------------------------------------------------------------#
#  Check Hot Status DB Mode !                                                 #
#-----------------------------------------------------------------------------#
sub CheckHotStatusLog() {
	Info ("Getting DB Status (Regular / HotBackup)") ;
	my $result = RunSqlCommand($WorkingFiles{"DB_MODE"}) ;
	if ($result ne 0) {
		Debug("CheckHotStatusLog","Error: Cannot check DB Status with $WorkingFiles{\"DB_MODE\"}");
		Exit ("Error: Cannot check DB Status with $WorkingFiles{\"DB_MODE\"}", 1) ;
	}else{
		Info ("Getting DB Status (Regular / HotBackup) $OK") ;
	}

	my $NUMBER_OF_TABLE_SPACE = `cat $WorkingFiles{"HOT_SPLIT_STATUS_LOG"} | wc -l` ;
	Info ("The Number of Table Space is : $NUMBER_OF_TABLE_SPACE") ;
	my $NUMBER_OF_TABLE_SPACE_ACTIVE = `cat $WorkingFiles{"HOT_SPLIT_STATUS_LOG"} | grep ^ACTIVE | wc -l` ;
	Info ("The Number of Active Table Space is : $NUMBER_OF_TABLE_SPACE_ACTIVE") ;

	if ($NUMBER_OF_TABLE_SPACE_ACTIVE == $NUMBER_OF_TABLE_SPACE) {
		Info ("You Are In HotBackup Mode !!\n") ;
		return 0 ;
	}

	if ($NUMBER_OF_TABLE_SPACE_ACTIVE == 0) {
		Info ("You Are In Regular Mode !!") ;
		return 1 ;
	}

	Info ("Some Of The Tablespaces Are In \"ACTIVE\" Mode And Some Are In \"NOT ACTIVE\" Mode");
	return 2;
}
#-----------------------------------------------------------------------------#
#  End Hot Backup Mode !                                                      #
#-----------------------------------------------------------------------------#
sub EndHotBackupMode() {
	# Needed to create Dynamicly end backup file

	
	
	Info ("Starting End HotBackup Mode") ;
	my $result = RunSqlCommand($WorkingFiles{"HOT_SPLIT_SQL_END"}) ;
	if ($result ne 0) {
		Info("Error: Could not END HOT backup mode with $WorkingFiles{\"HOT_SPLIT_SQL_END\"}");
		Debug("EndHotBackupMode","Error: Could not END HOT backup mode when running sql file: $WorkingFiles{\"HOT_SPLIT_SQL_END\"}");
	}else{
		Info("Return DB to Regular Mode $OK") ;
	}

	Info ("Cheking DB Status Again !") ;
	$result = CheckHotStatusLog () ;
	if ($result != 1) {		# You are in HotBackup mode and need to be in Regular Mode
		Debug("EndHotBackupMode","Error: Cannot return to Regular Mode");
		Exit ("Error: Cannot return to Regulat Mode", 1) ;
	}
	
	if ($GroupParams{"DB_TYPE"} eq "ASM") {
		Info ("Enabling ASM Rebalancing") ;
		SetTNS ($GroupParams{"ASM_TNSNAME"}) ;
		my $result = RunASMCommand($WorkingFiles{"ASM_REBALANCE_START"}) ;
		if ($result eq 0) {
			Info ("Enabling ASM Rebalancing $OK") ;
		}else{
			Debug("EndHotBackupMode","Error: Cannot enable ASM Rebalancing");
			Exit ("Error: Cannot enable ASM Rebalancing", 1) ;
		}
		SetTNS ($GroupParams{"TNS_NAME"}) ;
	}
}
#-----------------------------------------------------------------------------#
#   Select The Last SCN For Recovery Of The Target                            #
#-----------------------------------------------------------------------------#
sub Select_Scn_Num($) {
	my $File_Name = shift ;		chomp $File_Name ;
	Info ("Gettin The \"$File_Name\" SCN Number") ;
	my $result = RunSqlCommand("$WorkingFiles{\"HOT_SPLIT_SCN\"} $File_Name") ;
	if ($result ne 0) {
		Debug("Select_Scn_Num","Error: Cannot get The \"$File_Name\" SCN Number");
		Exit ("Error: Cannot get The \"$File_Name\" SCN Number", 1) ;
	}else{
		Info ("Get the \"$File_Name\" SCN Number $OK") ;
	}
	return $? ;
}
#-----------------------------------------------------------------------------#
#     Insert To Hot Backup Mode !                                             #
#-----------------------------------------------------------------------------#
sub Insert_Hot_backup() {
	if ($GroupParams{"DB_TYPE"} eq "ASM") {
		Info ("Disabling ASM Rebalancing") ;
		SetTNS ($GroupParams{"ASM_TNSNAME"}) ;
		my $result = RunASMCommand($WorkingFiles{"ASM_REBALANCE_STOP"}) ;
		if ($result eq 0) {
			Info ("Disabling ASM Rebalancing $OK") ;
		}else{
			Debug("Insert_Hot_backup","Error: Cannot Disable ASM Rebalancing");
			Exit ("Error: Cannot Disable ASM Rebalancing", 1) ;
		}
		SetTNS ($GroupParams{"TNS_NAME"}) ;
	}
	
	Info ("Insert To Hot Backup Mode") ;
	my $result = RunSqlCommand($WorkingFiles{"HOT_SPLIT_SQL_BEGIN"}) ;
	if ($result ne 0) {
		Debug("Insert_Hot_backup","Error: Cannot Insert To Hot Backup Mode with $WorkingFiles{\"HOT_SPLIT_SQL_BEGIN\"}");
		Exit ("Error: Cannot Insert To Hot Backup Mode with $WorkingFiles{\"HOT_SPLIT_SQL_BEGIN\"}", 1) ;
	}else{
		Info ("Insert To Hot Backup Mode $OK") ;
	}
	
	Info ("Cheking DB Status Again !") ;
	$result = CheckHotStatusLog () ;
	if ($result == 1) {		# You are in Regular mode and need to be in HotBackup Mode
		Debug("Insert_Hot_backup","Error: Cannot Insert To Hot Backup Mode");
		Exit ("Error: Cannot Insert To Hot Backup Mode", 1) ;
	}
}
#-----------------------------------------------------------------------------#
#  Create Control File !                                                      #
#-----------------------------------------------------------------------------#
sub CreateControlFile() {

	Info ("Create Control File") ;
	my $ControlFileName = "/tmp/" . $GROUP_NAME . ".ctl" ;
	if (IsExist($GroupParams{"MASTER_HOST"}, $ControlFileName) eq 0) {
		Info("The control file exist, deleting it...") ;
		my $mcmd = "/bin/rm " . $ControlFileName ;
		my $result = RunProgram ($GroupParams{"MASTER_HOST"}, "$mcmd") ;
		if ($result ne 0) {
			Debug("CreateControlFile","Error: Cannot delete old trace control file with $mcmd on $GroupParams{\"MASTER_HOST\"}");
			Exit ("Error: Cannot delete old trace control file with $mcmd on $GroupParams{\"MASTER_HOST\"}", 1) ;
		}
	}

	Info ($WorkingFiles{"ALTER_CONTROL_FILE"});
	$result = RunSqlCommand($WorkingFiles{"ALTER_CONTROL_FILE"}) ;
	system ("cat $WorkingFiles{\"ALTER_CONTROL_FILE\"}") ;
	if ($result ne 0) {
		Debug("CreateControlFile","Error: Can not Create Control File with $WorkingFiles{\"ALTER_CONTROL_FILE\"}");
		Exit ("Error: Can not Create Control File with $WorkingFiles{\"ALTER_CONTROL_FILE\"}", 1) ;
	}elsif ( $GroupParams{"DB_TYPE"} ne "ASM") {
		my $SourceFile = $GroupParams{"MASTER_HOST"} . ":" . $ControlFileName ;
		my $TargetFile = $WorkingFiles{"CTL"} ;
		print "source file = $SourceFile ------------\n" ;
		print "target file = $TargetFile ------------\n" ;
		$result = CopyFile ($SourceFile, $TargetFile) ;
		if ($result ne 0) {
			Debug("CreateControlFile","Error: Cannot copy the ControlFile from $SourceFile to $TargetFile");
			Exit ("Error: Cannot copy the ControlFile from $SourceFile to $TargetFile", 1) ;
		}
		system ("chmod 666 $WorkingFiles{\"CTL\"}") ;
		Info ("Create Control File $OK") ;

	}
	return $? ;
}
#-----------------------------------------------------------------------------#
#  Switch LogFile !                                                           #
#-----------------------------------------------------------------------------#
sub SwitchLogfile() {

	Info ("Switch Log file") ;
	my $result = RunSqlCommand($WorkingFiles{"ALTER_SWITCH_LOGFILE"}) ;
	if ($result ne 0) {
		Debug("SwitchLogfile","Error: Cannot switch log file with $WorkingFiles{\"ALTER_SWITCH_LOGFILE\"}");
		Exit ("Error: Cannot switch log file with $WorkingFiles{\"ALTER_SWITCH_LOGFILE\"}", 1) ;
	}else{
		Info ("Switch Log file $OK") ;
	}
	return $? ;
}
#-----------------------------------------------------------------------------#
# Select Control Files Path's                                                 #
#-----------------------------------------------------------------------------#
sub SelectControlFile() {
	Info ("Select Control Files Path ") ;
	my $result = RunSqlCommand($WorkingFiles{"HOT_SPLIT_CTL_PATH"}) ;
	if ($result ne 0) {
		Debug("SelectControlFile","Error: Cannot select control file path with $WorkingFiles{\"HOT_SPLIT_CTL_PATH\"}");
		Exit ("Error: Cannot select control file path with $WorkingFiles{\"HOT_SPLIT_CTL_PATH\"}", 1) ;
	}else{
		Info ("Select Control Files Path $OK") ;
	}
	return $? ;
}
#-----------------------------------------------------------------------------#
#   Select and create Archive List  !                                         #
#-----------------------------------------------------------------------------#
sub CreateArchiveList() {
	Info ("Select and create Archive List") ;

	my $first_num = `cat $WorkingFiles{"SCN_NUM_BEFOR"}| sort -n | head -n 1` ;
	chomp $first_num ;
	$first_num =~ s/ //g ;

	my $last_num = `cat $WorkingFiles{"HOT_SCN_AFTER"} | sort -n | tail -n 1` ;
	chomp $last_num ;
	$last_num =~ s/ //g ;

	Info ("Checking The Oracle VERSION.") ;
	my $VERSION = GetOracleVersion($WorkingFiles{"VERSION_FILE"}) ;
	Info ("The Oracle VERSION Is $VERSION.") ;

	my $String = "" ;
	if ($VERSION eq "Oracle8i") {
		$String = "$WorkingFiles{\"HOT_ARCH_LIST_ORACLE8I\"} " ;
	} elsif ($GroupParams{"DB_TYPE"} eq "RAC" || $VERSION eq "" ) {
		# This will run with Oracle 10G RAC
		sleep 900 ;  # this is becaus of Oracle Dictionary update
		$String = "$WorkingFiles{\"HOT_ARCH_LIST_ORACLE_RAC\"} " ;
	} else {
		$String = "$WorkingFiles{\"HOT_ARCH_LIST_ORACLE\"} " ;
	}

	$String = $String . " $first_num $last_num" ;
	Info ("Running : $String !!!") ;
	my $result = RunSqlCommand("$String") ;
	if ($result ne 0) {
		Debug("CreateArchiveList","Error: Cannot select and create archive list with $String");
		Exit ("Error: Cannot select and create archive list with $String", 1) ;
	}else{
		Info ("Select and create Archive List $OK") ;
	}
	return $? ;
}
###############################################################################
#                                                                             #
#          Section common to all shells with steps begins here.               #
#                                                                             #
###############################################################################
#-----------------------------------------------------------------------------#
#   Check Symetrix Retern Codes !                                             $
#-----------------------------------------------------------------------------#
sub Check_Symapi_Exit($$) {
	my $Code = shift ;		chomp $Code ;
	my $Subject = shift ;	chomp $Subject ;

	if ($Code == 0) {
		Info ("$Subject Finished OK..") ;
	}elsif ($Code == 1) {
		Exit ("$Subject Failed <CLI_C_FAIL> !! Code=$Code !", 1) ;
	}elsif ($Code == 2) {
		my $TIME = $GParam{"lock_wait"} / 60 ;
		Info ("There A Symmetrix Internal Lock During $Subject <CLI_C_DB_FILE_IS_LOCKED> !") ;
		Info ("Waiting $TIME Min For The Symmetrix To Unlocked !") ;
		sleep $GParam{"lock_wait"} ;
	}elsif ($Code == 3) {
		my $TIME = $GParam{"lock_wait"} / 60 ;
		Info ("There A Symmetrix Internal Lock During $Subject") ;
		Info ("Waiting $TIME Min For The Symmetrix To Unlocked !") ;
		sleep $GParam{"lock_wait"} ;
	}elsif ($Code == 19) {
		Exit ("$Subject Failed - CLI_C_GK_IS_LOCKED !", 1) ;
	}elsif ($Code == 49) {
		Exit ("There is A device Lock During $Subject Call The System !!", 1) ;
	}else {
		Exit ("Internal $Subject Failed Code=$Code!!", 1) ;
	}
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
$BaseDir = "/usr/" . $RunnigHost . "/ReplicMan" ;
$GroupsDir = $BaseDir . "/var/Groups" ;
$SQLDir = $BaseDir ."/SqlFiles" ;
$LogsDir =  $BaseDir . "/logs" ;
$SaveDir = $SQLDir . ".save" ;

# The Help file
$HelpFile = $BaseDir . "/" . GetShellName() . ".help" ;

# The Parameters file
$ParamFile = $BaseDir . "/var/" . GetShellName() . ".xml" ;

# The Configuration file
$ConfigFile = $BaseDir . "/var/" . GetShellName() . ".conf" ;

# ASM Rebalance power in regular mode
$RebalancePower = 1 ;

SetWorkDir($LogsDir) ;

#-----------------------------------------------------------------------------#
# XML & command-line Parameter settings										  #
#-----------------------------------------------------------------------------#

getopt('d:g:f:lt:y:', \%opts);

ReadGlobalParameters() ;

# Set SYMCLI Parameters
$ENV{"SYMCLI_MODE"} = $GParam{"SYMCLI_MODE"} ;
$ENV{"SYMCLI_CTL_ACCESS"} = $GParam{"SYMCLI_CTL_ACCESS"} ;

%GroupParams = () ;
my @netapps = ();
my @vfilers = ();
my @src_vols = ();
my @tgt_vols = ();
my @xiv_src_volume = ();
my @xiv_tgt_volume = ();
my @svc_fc_grp = ();

# Check if the parameters file exist !
if (! -f $ParamFile) {	
	Exit ("\n\tThe parameters file ($ParamFile) does not exists", 1) ;
}

# Initialize Default parameters
$Full = "" ;           # Wheter its a Full backup
$Force = "" ;
$VGIM = 0 ;            # Wheter VGexport & VGimport - The default value is false !
$COLD = 0 ;            # Wheter its a COLD backup   - The default value is false !
$CopyTarget = "" ;

# Define StepDriver First and Last steps
SetFirstStep("05")  ;
SetLastStep("85")   ;

# Define initial From and To steps
SetFromStep(GetFirstStep()) ;
SetToStep(GetLastStep()) ;

# Default use of Secure shell (SSH)
if (SetSecureMode("y") eq 1) {
	Exit ("\nCannot Change to SecureMode - SSH !!!\n", 1) ;
}

# Reading Command-Line Parameters
foreach $prm (keys %opts) {
	Debug ("ReadParams", "Param = $prm") ;
	if ($prm eq "h") {		HELP_MESSAGE() ;	exit 0 ;	  }
	if ($prm eq "F") {		$Full = "-full" ;				  }
	if ($prm eq "C") {
		$COLD = 1 ;
		AddStep("55", "PrepForColdSplit", "Prepare Master DB for ColdSplit") ;
		AddStep("65", "AfterColdSplit", "Up the Master DB After ColdSplit") ; }
	if ($prm eq "p") {		$Force = "-force" ;				  }
	if ($prm eq "v") {		$VGIM = 1 ;						  }
	if ($prm eq "l") {		list_steps() ;	   exit 0 ;  	  }
	if ($prm eq "d") {		SetWorkDir("$opts{$prm}") ;		  }
	if ($prm eq "g") {		$GROUP_NAME = $opts{$prm} ;		  }
	if ($prm eq "f") {		SetFromStep("$opts{$prm}"); 	  }
	if ($prm eq "t") {		SetToStep("$opts{$prm}")  ;		  }
	if ($prm eq "y") {		SetLogDate("$opts{$prm}") ;		  }
	if ($prm eq "H") {		$CopyTarget = $opts{$prm} ;		  }
	if ($prm eq "D") {
		if (SetDebugMode("y") eq 1) {
			Exit ("\nCannot Change to Debug-Mode !!!\n", 1) ;
		}
		Info ("\nThis script is running on Debug Mode") ;
	}
	if ($prm eq "R") {
		if (SetSecureMode("n") eq 1) {
			Exit ("\nCannot Change to NON-Secure Mode !!!\n", 1) ;
		}
		Info ("\nThis script is running on Non-Secure Mode !!!") ;
	}
}

if ( $GROUP_NAME eq "" ) {	
	Exit ("\nEnter Group_Name with -g for the Establish/Split procedure !!", 1) ;
}

if ( ! -f  "$GroupsDir/$GROUP_NAME" ) {
	Exit ("\nThere is no Group file $GROUP_NAME in $GroupsDir On ${RunnigHost}", 1) ;
}

%GroupParams = ReadParamFile () ;
CreateGlobalParameterse () ;

#this will be used during the migration from XIV to NetApp 
our $MigrationPeriod = 0;
if ($GroupParams{"MSGRP"} =~/XIV\|NetappSAN/) {
	$MigrationPeriod = 1;
	$GroupParams{"MSGRP"} = 'XIV';
} elsif ($GroupParams{"MSGRP"} =~/SVC\|NetappSAN/) {
	$MigrationPeriod = 1;
	$GroupParams{"MSGRP"} = 'SVC';
}

if ($MigrationPeriod and $GroupParams{"OS_VERSION"} eq "Linux") {
	Info("When in MigrationPeriod from XIV to NetappSAN tring to validate if VGs are located on NetApp or XIV");
	my @vgs = split(':',$GroupParams{"VG_LIST"});
	my $cmd = "multipath -ll";
	my $ExitCode = RunProgramQuiet($GroupParams{"TARGET_HOST"}, "$cmd") ;
	my @mpll = GetCommandResult();
	my %NetappDevices = ();
	foreach my $line (@mpll) {
		chomp $line;
		if ($line=~/(\S+)\s+\(\S+\)\s+(\S+).+NETAPP.+/) {
			$NetappDevices{$1} = 'NetappLUN';
			Info("Identified device \"/dev/mapper/$1\" as Netapp LUN");
		}
		if ($line=~/(\S+)\s+(\S+).+NETAPP.+/) {
			$NetappDevices{$1} = 'NetappLUN';
			Info("Identified device \"/dev/mapper/$1\" as Netapp LUN");
		}		
	}
	$cmd = "pvs";
	$ExitCode = RunProgramQuiet($GroupParams{"TARGET_HOST"}, "$cmd") ;
	my @pvs = GetCommandResult();
	my $onnetapp = 1;
	foreach my $vg (@vgs) {
		foreach my $line (@pvs) {
			chomp $line;
			if ($line =~ /^\s*\/dev\/mapper\/(\S+)\s+$vg/) {
				if (not exists $NetappDevices{$1}) {
					$onnetapp = 0;
					Info("Device:$1 is part of vg:$vg but it is not on Netapp LUN :-(");
				} else {
					Info("Device:$1 is part of vg:$vg and is on Netapp LUN :-)");
				}
			}
		}
	}
	if ($onnetapp) {
		Info("Setting MSGRP as NetappSAN becuase of all VGs are on Netapp");
		$GroupParams{"MSGRP"} = "NetappSAN";
	}
}

# Fills the array for Netapp and NetappSAN 
CreateNetappMap () ;
# Fills the 2 arrays of XIV  src_vols and tgt_vols in data according the group file
CreateXivMap () ;
# Fill the array for SVC svc_fc_grp
CreateSVCMap ();

SetTNS ($GroupParams{"TNS_NAME"}) ;

# If there is a Target HOST
if ($GroupParams{"TARGET_HOST"} ne "NoHost") {
	# If the Source is Diffrent from the Target - Shutdown DB on target
	if ($GroupParams{"TARGET_HOST"} ne $GroupParams{"MASTER_HOST"}) {
		AddStep("15", "ShutDownTargetDB", "ShutDown DataBase on the target host") ;
		AddStep("80", "UpTargetDB", "Up the DB on the target host") ;
	}
	# Add Umount and Mount
	AddStep("20", "UmountTargetFS", "Umount FileSystems on the target host") ;
	AddStep("75", "MountTargetFS", "Mount filesystems on the target hos") ;
	# If this is a Hot DB backup - Copy the archvies after the split
	if ($GroupParams{"DATABASE_NAME_MASTER"} ne "NoDb" && $COLD != 1 && $GroupParams{"DATABASE_NAME_MASTER"} ne "INFORMIX" ) {
		# Configure to which host I should copy the archives ...
		if ($CopyTarget ne "") {
			Exit ("There is conflict in the parameter -H !!!", 1) ;
		}else{
			$CopyTarget = $GroupParams{"TARGET_HOST"} ;
		}
		AddStep("77", "CopyFiles2Target", "Copy Files to target host") ;
	}
	
	if ( $GroupParams{"OS_VERSION"} eq "HP-UX" || $GroupParams{"OS_VERSION"} eq "Linux" ) {
		require Pelephone::System::HPUX ;
		
		if ($GroupParams{"VG_LIST"} ne "") {
			AddStep("25", "VGChangeAfterUmount", "VgChange after umount on the target") ;
			AddStep("70", "VGChangeBeforMmount", "VgChange Befor Mount on the target") ;
		}
	}
	if ($GroupParams{"DATABASE_NAME_MASTER"} eq "INFORMIX") {
		AddStep("55", "InformixHotSplit", "Intesrt the informix on the master to HotBackup Mode") ;
		AddStep("65", "InformixRegMode", "Return the informix on the master to Regular Mode") ;
	}
}
if ($GroupParams{"DATABASE_NAME_MASTER"} eq "INFORMIX") {
	AddStep("55", "InformixHotSplit", "Intesrt the informix on the master to HotBackup Mode") ;
	AddStep("65", "InformixRegMode", "Return the informix on the master to Regular Mode") ;
}
# If this is a Hot DB backup
if ($GroupParams{"MASTER_HOST"} ne "NoHost" && $GroupParams{"DATABASE_NAME_MASTER"} ne "NoDb" && $COLD != 1 && $GroupParams{"DATABASE_NAME_MASTER"} ne "INFORMIX") {
		AddStep("55", "PrepForHotSplit", "Insert Master DB to HotBackup Mode") ;
		AddStep("65", "AfterHotSplit", "Return Master DB to Regular Mode") ;
}

# Storage related Steps
# Netapp Storage
if ($GroupParams{"MSGRP"} eq "Netapp" ) {
	# This section is NEEDED for Maof DEV Appl !
	if (($GROUP_NAME eq "VOL_MAOF_UNASSIGN_JDEV") ||  ($GROUP_NAME eq "VOL_MAOF_JDEV_JDEV2") || ($GROUP_NAME eq "VOL_MAOF_JDEV_JDEVR12")) {
		#Update $GroupParams{TARGET_FILESYSTEM} in Group file content
		Info ("Loading Maof DEV appl from Group File...");
		my $GRP_FileName = $GroupsDir . "/" . $GROUP_NAME;
		open (GRP_FILE,"<$GRP_FileName") || die "Cannot open Group File $GRP_FileName for reading !";
		foreach my $line (<GRP_FILE>) {
			$GroupParams{"TARGET_FILESYSTEM"} = (split(':',$line))[3];
		}
		close(GRP_FILE);
	}
	
	# Establish Proccess
	AddStep("05", "CheckGroupStatus", "Check the group status Before the Establish") ;
	AddStep("06", "CheckRunningSyncs", "Check for running syncs from the same source") ;  
	AddStep("10", "EstPreCommand", "Pre Establish Command") ;
	AddStep("30", "DoTheEstablish", "Do The Establish") ;
	AddStep("40", "EstPostCommand", "Post Establish Command") ;
	
	# Split Proccess
	AddStep("50", "SplitPreCommand", "Pre Split Command") ;
	AddStep("60", "DoTheSplit", "Split The Group") ;
	AddStep("85", "SplitPostCommand", "Post Split Command") ;	
}
elsif ($GroupParams{"MSGRP"} eq "NetappSAN") {

	# Establish Proccess
	AddStep("05", "CheckGroupStatus", "Check the group status Before the Establish") ;
	AddStep("06", "CheckRunningSyncs", "Check for running syncs from the same source") ; 
	AddStep("10", "EstPreCommand", "Pre Establish Command") ;
	AddStep("30", "DoTheEstablish", "Delete Target LUNs") ;
	AddStep("40", "EstPostCommand", "Post Establish Command") ;	
	# Split Process
	AddStep("50", "SplitPreCommand", "Pre Split Command") ;
	AddStep("60", "DoTheSplit", "Split The Group") ;
	AddStep("85", "SplitPostCommand", "Post Split Command") ;
	
}
elsif ($GroupParams{"MSGRP"} =~ /XIV/ ) {

	# Establish Proccess
	AddStep("05", "CheckGroupStatus", "Check the group status Before the Establish") ;
	AddStep("06", "CheckRunningSyncs", "Check for running syncs from the same source") ; 
	AddStep("10", "EstPreCommand", "Pre Establish Command") ;
	AddStep("40", "EstPostCommand", "Post Establish Command") ;
	
	# If this is a Remote volume - XIV Mirror involved
	if ($GroupParams{"XIV_FROM_MIRROR"} eq "yes") {
		AddStep("30", "DoTheEstablish", "Delete Target Volume") ;
	}
	
	# Split Proccess
	AddStep("50", "SplitPreCommand", "Pre Split Command") ;
	AddStep("60", "DoTheSplit", "Split The Group") ;
	AddStep("85", "SplitPostCommand", "Post Split Command") ;
	

}
elsif ($GroupParams{"MSGRP"} =~ /SVC/ ) {

	# Establish Proccess
	AddStep("05", "CheckGroupStatus", "Check the group status Before the Establish") ;
	AddStep("06", "CheckRunningSyncs", "Check for running syncs from the same source") ; 
	AddStep("10", "EstPreCommand", "Pre Establish Command") ;
	AddStep("30", "DoTheEstablish", "Delete Target Volume") ;
	AddStep("40", "EstPostCommand", "Post Establish Command") ;
	
	
	# Split Proccess
	AddStep("50", "SplitPreCommand", "Pre Split Command") ;
	AddStep("60", "DoTheSplit", "Split The Group") ;
	AddStep("85", "SplitPostCommand", "Post Split Command") ;
	

}
else { # EMC Storage
	# Establish Proccess
	AddStep("05", "CheckGroupStatus", "Check the group status Before the Establish") ;
	AddStep("06", "CheckRunningSyncs", "Check for running syncs from the same source") ;  
	AddStep("10", "EstPreCommand", "Pre Establish Command") ;
	AddStep("30", "DoTheEstablish", "Do The Establish") ;
	AddStep("35", "VerifyGroupStatus", "Verify the Establish Process") ;
	AddStep("40", "EstPostCommand", "Post Establish Command") ;

	# Split Proccess
	AddStep("45", "CheckSplitStatus", "Check the group status Before the Split") ;
	AddStep("50", "SplitPreCommand", "Pre Split Command") ;
	AddStep("60", "DoTheSplit", "Split The Group") ;
	AddStep("85", "SplitPostCommand", "Post Split Command") ;
}

# Replacing "Package" (Clustered) name to REAL hostname
if ($GroupParams{"RH_CLUSTER"} eq "yes" || $GroupParams{"SERVICE_GAURD"} eq "yes") {
	my $real_hostname = GetHostnameRemote("$GroupParams{\"MASTER_HOST\"}");
	$GroupParams{"MASTER_HOST"} = $real_hostname;
}

# Setting "VGIM" parameter to perform export/import VG if needed
# if cloning VG for the same host:
if ($GroupParams{"TARGET_HOST"} eq $GroupParams{"MASTER_HOST"}) {
	Info ("TARGET_HOST equals MASTER_HOST, Changing VGIM to 1");
	$VGIM = 1 ;
}

# Check if vgimport is needed - Only for HPUX
if ( $GroupParams{OS_VERSION} ne "Linux" ) {
	# if any VG changes found between source & target:
	if ( CheckVGDiff() eq 1) {
		Info ("CheckVGDiff Exit status is 1, Changing VGIM to 1");
		$VGIM = 1 ;
	}
	# End of vg export/import setting
}

Info ("Config file is: $ConfigFile" ) ;
Info ("Param file is: $ParamFile" ) ;

print "Target Host = <$GroupParams{\"TARGET_HOST\"}>\n";
print "CopyTarget = <$CopyTarget>\n";

SetCurrentStep(GetFromStep()) ;

#--------- End Of Parameter settings ---------------------------------------  #


# step listing before execution
list_steps() ;

# Running the actual steps
TS_Init("$GROUP_NAME") ;

exit 0;
