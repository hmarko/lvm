package Pelephone::Netapp;  

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
	@EXPORT      = qw(&getVolCommentCOT &deleteLunCOT &mapLunsCOT &isVolExists &offlineFlexClone &deleteFlexClone &offlineVolCOT &createSvSched &createNetappSnap &createFlexClone &deleteSnapCOT &isSnapExistsCOT
						&exportNetappVol &addVol2Vfiler &checkSmIdle &updateSM &isVolExistsCOT &deleteVolCOT &createNetappSnapCOT &createFlexCloneCOT &exportNetappVolCOT &getNetappLastSnapCOT);
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

}

our @EXPORT_OK;

END { }       # module clean-up code here (global destructor)

sub getVolCommentCOT($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;	chomp $volume ;	
	my $cmd = "ssh vsadmin\@$netapp volume show -volume $volume -fields comment | grep \" $volume \"" ;
	
	RunProgramQuiet($main::RunnigHost, "$cmd"); 
	my @Text = GetCommandResult();
	
	my $comment = pop @Text; chomp $comment ;
	$comment =~ /\s*(\S+)\s+($volume)\s+(.+)/;
	$commnet = $3;
	
	return $commnet ;
}

sub mapLunsCOT($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $path = '/vol/'.shift ;		chomp $path ;
	my $cmd = "ssh vsadmin\@$netapp lun show -fields path | grep \"$path\"" ;
	#print "$cmd\n";
	RunProgramQuiet($main::RunnigHost, "$cmd"); 
	my @Text = GetCommandResult();	
	return @Text;
}

sub deleteLunCOT($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $path = shift ;		chomp $path ;
	
	my $cmd = "ssh vsadmin\@$netapp \"set -conf off; lun delete -path $path\"" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check wheter the lun is really deleted
	$cmd = "ssh vsadmin\@$netapp lun show -fields path | grep \"$path\"";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	if ( $ExitCode eq 1 ) { # lun does not exists -> DELETED
		return 0;
	}
	else { # lun exists (grep returned 0) -> Deletion FAILED
		return 1;
	}
}


sub isVolExists($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;		chomp $volume ;
	my $cmd = "ssh $netapp vol status -l | awk '{print\$1}' | grep -w $volume" ;
	my $ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub isVolExistsCOT($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;		chomp $volume ;
	my $cmd = "ssh vsadmin\@$netapp vol show -fields volume | grep -w $volume" ;
	my $ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub isSnapExistsCOT($$$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;		chomp $volume ;
	my $snap = shift;			chomp $snap ;
	my $cmd = "ssh vsadmin\@$netapp snap show $volume -fields volume,snapshot | grep -w $snap" ;
	my $ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub offlineFlexClone($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;		chomp $volume ;
	my $cmd = "ssh $netapp vol offline $volume" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check wheter the volume is really offline
	$cmd = "ssh $netapp vol status | grep -w $volume | grep -w offline";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub offlineVolCOT($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;		chomp $volume ;
	my $cmd = "ssh vsadmin\@$netapp \"set -conf off; vol offline $volume -f true -foreground true\"" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check wheter the volume is really offline
	$cmd = "ssh vsadmin\@$netapp vol show -fields volume,state | grep -w $volume | grep -w offline";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub deleteFlexClone($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;		chomp $volume ;
	my $cmd = "ssh $netapp vol destroy $volume -f" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check wheter the FlexClone is really deleted
	$cmd = "ssh $netapp vol status -l | awk '{print\$1}' | grep -w $volume";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	if ( $ExitCode eq 1 ) { # Volume does not exists -> DELETED
		return 0;
	}
	else { # Volume exists (grep returned 0) -> Deletion FAILED
		return 1;
	}
}

sub deleteVolCOT($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;		chomp $volume ;
	my $cmd = "ssh vsadmin\@$netapp \"set -conf off; vol delete $volume -foreground true\"" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check wheter the Volume is really deleted
	$cmd = "ssh vsadmin\@$netapp vol show -fields volume | grep -w $volume";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	if ( $ExitCode eq 1 ) { # Volume does not exists -> DELETED
		return 0;
	}
	else { # Volume exists (grep returned 0) -> Deletion FAILED
		return 1;
	}
}

sub deleteSnapCOT($$$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;		chomp $volume ;
	my $snap = shift ;			chomp $snap	 ;
	my $cmd = "ssh vsadmin\@$netapp \"set -conf off; snap delete -volume $volume -snapshot $snap -foreground true\"" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check wheter the Snapshot is really deleted
	$cmd = "ssh vsadmin\@$netapp snap show $volume -fields volume,snapshot | grep -w $snap";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	if ( $ExitCode eq 1 ) { # Snapshot does not exists -> DELETED
		return 0;
	}
	else { # Snapshot exists (grep returned 0) -> Deletion FAILED
		return 1;
	}
}

sub createSvSched($$$) {
	my $netapp = shift ;		chomp $netapp ;
	my $src_volume = shift ;	chomp $src_volume ;
	my $tgt_volume = shift ; 	chomp $tgt_volume ;	
	my $vol_env = (split ('_',$tgt_volume))[2] . (split ('_',$tgt_volume))[3];
	my $cmd = "ssh $netapp snapvault snap sched $src_volume ReplicMan_$vol_env 1\@-" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check if the schedule created
	$cmd = "ssh $netapp snapvault snap sched $src_volume | grep ReplicMan_$vol_env";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub createNetappSnap($$$) {
	my $count = 1;
	my $netapp = shift ;		chomp $netapp ;
	my $src_volume = shift ;	chomp $src_volume ;
	my $tgt_volume = shift ; 	chomp $tgt_volume ;	
	my $vol_env = (split ('_',$tgt_volume))[2] . (split ('_',$tgt_volume))[3];
	my $cmd = "ssh $netapp snapvault snap create $src_volume ReplicMan_$vol_env" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check if the snap really created
	while ($count < 40) { 
		sleep 20;
		$cmd = "ssh $netapp snapvault status -s | grep -w $src_volume | grep -w ReplicMan_$vol_env | grep -w Idle";
		$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
		
		if ( $ExitCode == 0 ) {
			Info ("Snap creation Finished \n");
			return $ExitCode;
		}
		$count ++;
	}
	return $ExitCode;
}

sub createNetappSnapCOT($$$) {
	my $netapp = shift ;		chomp $netapp ;
	my $src_volume = shift ;	chomp $src_volume ;
	my $snap = shift ;			chomp $snap ;
	my $cmd = "ssh vsadmin\@$netapp snap create $src_volume $snap" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	
	# I have to check wheter the FlexClone created
	sleep 2;
	$cmd = "ssh vsadmin\@$netapp snap show -volume $src_volume | grep -w $snap";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	
	
	return $ExitCode;
}

sub createFlexClone($$$) {
	my $netapp = shift ;		chomp $netapp ;
	my $src_volume = shift ;	chomp $src_volume ;
	my $tgt_volume = shift ; 	chomp $tgt_volume ;	
	my $vol_env = (split ('_',$tgt_volume))[2] . (split ('_',$tgt_volume))[3];
	my $cmd = "ssh $netapp vol clone create $tgt_volume -s none -b $src_volume ReplicMan_$vol_env.0" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check wheter the FlexClone created
	$cmd = "ssh $netapp vol status -l | grep -w $tgt_volume";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	
	# Sometimes the netapp is acting strange, so I want to re-run the command if something is wrong
	if ( $ExitCode ne 0 ) {
		sleep 20;
		$cmd = "ssh $netapp vol clone create $tgt_volume -s none -b $src_volume ReplicMan_$vol_env.0" ;
		Info ("Running \"$cmd\" command once again\n");
		$ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
		
		# Re-check of the volume exists
		$cmd = "ssh $netapp vol status -l | grep -w $tgt_volume";
		$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	} else {# The Flex Clone worked at the first time.
		return $ExitCode;
	}
	
	return $ExitCode;
}

sub createFlexCloneCOT($$$$) {
	my $netapp = shift ;		chomp $netapp ;
	my $src_volume = shift ;	chomp $src_volume ;
	my $tgt_volume = shift ; 	chomp $tgt_volume ;	
	my $snap = shift ;			chomp $snap ;
	my $cmd = "ssh vsadmin\@$netapp vol clone create $tgt_volume $src_volume -s none -parent-snapshot $snap -junction-path /vol/$tgt_volume -foreground true" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check wheter the FlexClone created
	$cmd = "ssh vsadmin\@$netapp vol show -fields volume | grep -w $tgt_volume";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	
	return $ExitCode;
}


sub exportNetappVol($$$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;	chomp $volume ;
	my $host = shift ; 	chomp $host ;	
	my $cmd = "ssh $netapp exportfs -p rw=$host,root=$host /vol/$volume" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check if the FlexClone was really exported
	$cmd = "ssh $netapp exportfs | grep -w $volume | grep $host";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub exportNetappVolCOT($$$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;	chomp $volume ;
	my $policy = shift ; 	chomp $policy ;	
	my $cmd = "ssh vsadmin\@$netapp vol modify -volume $volume -policy $policy" ;
	Info ("Running \"$cmd\" command \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check wheter the Volume policy changed
	$cmd = "ssh vsadmin\@$netapp vol show -volume $volume | grep -w Export | grep -w $policy" ;
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	
	return $ExitCode;
}

sub addVol2Vfiler($$$) {
	my $netapp = shift ;		chomp $netapp ;
	my $vfiler = shift ; 		chomp $netapp ;
	my $tgt_volume = shift ; 	chomp $tgt_volume ;
	my $cmd = "ssh $netapp vfiler add $vfiler /vol/$tgt_volume";
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	
	# I have to check if the Vol was really added to the vfiler
	$cmd = "ssh $netapp vfiler status -a $vfiler | grep -w /vol/$tgt_volume";
	$ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub checkSmIdle($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $tgt_volume = shift ; 	chomp $tgt_volume ;
	my $cmd = "ssh $netapp snapmirror status | grep $tgt_volume | grep Idle" ;
	my $ExitCode = RunProgramQuiet($main::RunnigHost, "$cmd") ;
	
	return $ExitCode;
}

sub updateSM($$) {
	my $netapp = shift ;		chomp $netapp ;
	my $tgt_volume = shift ; 	chomp $tgt_volume ;
	my $cmd = "ssh $netapp snapmirror status | grep $tgt_volume | awk \'{print\$2}\'" ; 
	my @SM_Dest_A = `$cmd` ;
	my $ExitCode = 1;
	
	foreach my $SM_Dest (@SM_Dest_A) {
		$cmd = "ssh $netapp snapmirror update $SM_Dest";
		Info ("Running SnapMirror update command: $cmd");
		$ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
		
		# If one of the qsm failed
		if ( $ExitCode ne 0 ) {
			return $ExitCode;
		}
	}
	return $ExitCode;
}

sub getNetappLastSnapCOT($$$) {
	my $netapp = shift ;		chomp $netapp ;
	my $volume = shift ;	chomp $volume ;
	my $pattern = shift ; 	chomp $pattern ;	
	my $cmd = "ssh vsadmin\@$netapp snap show -volume $volume -fields volume,snapshot | grep -w $pattern | awk '{print\$3}' | tail -1" ;
	
	RunProgramQuiet($main::RunnigHost, "$cmd"); 
	my @Text = GetCommandResult();
	
	my $snapshot = pop @Text; chomp $snapshot ;
	
	return $snapshot ;
}

#-----------------------------------------------------------------------------#
# The Main package Section!
#

1;
 
