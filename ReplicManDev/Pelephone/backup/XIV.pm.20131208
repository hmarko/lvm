package Pelephone::XIV;  

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
	@EXPORT      = qw(&isXivVolExists &isXivCgExists &isXivVolMirrorExists &isXivSnapGroupExists &XivVolDelete &XivMirrorSnapVolume &XivMirrorSnapGroup &XivSnapCreate &XivCgSnapCreate 
					&XivSnapGroupDelete &XivUnlcokVol &XivUnlcokSg &XivMapVolToHost &XivUnMapFromHost);
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

}

our @EXPORT_OK;

END { }       # module clean-up code here (global destructor)

sub isXivVolExists($$) {
	my $xiv = shift ;		chomp $xiv ;
	my $volume = shift ;		chomp $volume ;
	Info ("Checking if Volume $volume exists on XIV Box $xiv \n");
	my $cmd = "xcli -c $xiv vol_list vol=$volume  | grep -w $volume" ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub isXivCgExists($$) {
	my $xiv = shift ;		chomp $xiv ;
	my $cg = shift ;		chomp $cg ;
	Info ("Checking if CG $cg exists on XIV Box $xiv \n");
	my $cmd = "xcli -c $xiv cg_list cg=$cg  | grep -w $cg" ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}


sub isXivVolMirrorExists($$) {
	my $src_xiv = shift ;		chomp $src_xiv ;
	my $src_volume = shift ;	chomp $src_volume ;
	Info ("Checking the Volume Mirror status of volume \"$src_volume\" on XIV \"$src_xiv\" \n");
	Info ("Checking if the mirror is Active \n");
	my $cmd = "xcli -c $src_xiv mirror_list vol=$src_volume -t local_peer_name,active | grep -w $src_volume | grep -w yes" ; 
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	if ( $ExitCode ne 0 ) {
		
		Info ("The mirror is NOT Active \n");
		return $ExitCode
	}
	# Check if is Connected
	Info ("Checking if the mirror is Connected \n");
	$cmd = "xcli -c $src_xiv mirror_list vol=$src_volume -t local_peer_name,connected | grep -w $src_volume | grep -w yes" ; 
	$ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub isXivSnapGroupExists($$) {
	my $xiv = shift ;			chomp $xiv ;
	my $snap_group = shift ;	chomp $snap_group ;
	
	Info ("Checking if Snap Group \"$snap_group\" exists on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv snap_group_list snap_group=$snap_group  | grep -w $snap_group" ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivVolDelete($$) {
	my $xiv = shift ; 		chomp $xiv ;
	my $volume = shift ; 	chomp $volume ;
	
	Info ("Going to Delete the volume \"$volume\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv vol_delete vol=$volume -y | grep -e \"Command executed successfully\" -e \"Volume name does not exist\"" ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivMirrorSnapVolume($$$) {
	my $src_xiv = shift ; 		chomp $src_xiv ;
	my $src_volume = shift ; 	chomp $src_volume ;
	my $tgt_volume = shift ; 	chomp $tgt_volume ;
	
	Info ("Going to Cretae a Mirror Snapshot on volume \"$src_volume\" on Source and Target XIV \n");
	my $cmd = "xcli -c $src_xiv mirror_create_snapshot vol=$src_volume name=$tgt_volume slave_name=$tgt_volume | grep \"Command executed successfully\" " ;
	Info ("Running: $cmd \n");
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivMirrorSnapGroup($$$) {
	my $src_xiv = shift ; 		chomp $src_xiv ;
	my $src_cg = shift ; 		chomp $src_cg ;
	my $sg_name = shift ; 		chomp $sg_name ;	
	
	Info ("Going to Cretae a Mirror SnapGroup on Consistency Group \"$src_cg\" to SnapGroup \"$sg_name\" on Source and Target XIV \n");
	my $cmd = "xcli -c $src_xiv mirror_create_snapshot cg=$src_cg name=$sg_name slave_name=$sg_name | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivSnapCreate($$$) {
	my $xiv = shift;		chomp $xiv;
	my $src_volume = shift;	chomp $src_volume;
	my $tgt_volume = shift;	chomp $tgt_volume;
	
	Info ("Going to Create a Snapshot from \"$src_volume\" to \"$tgt_volume\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv snapshot_create vol=$src_volume overwrite=$tgt_volume | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivCgSnapCreate($$$) {
	my $xiv = shift;		chomp $xiv;
	my $src_cg = shift;	chomp $src_cg;
	my $tgt_cg = shift;	chomp $tgt_cg;
	
	Info ("Going to Create a CG Snapshot from \"$src_cg\" to \"$tgt_cg\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv cg_snapshots_create cg=$src_cg overwrite=$tgt_cg | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivSnapGroupDelete($$) {
	my $xiv = shift;		chomp $xiv;
	my $sg_name = shift;	chomp $sg_name;
	
	Info ("Going to Delete the Snap Group \"$sg_name\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv snap_group_delete snap_group=$sg_name | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;	
}

sub XivUnlcokVol($$) {
	my $xiv = shift;		chomp $xiv;
	my $volume = shift ; 	chomp $volume ;
	
	Info ("Going to Unlock the Volume \"$volume\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv vol_unlock vol=$volume -y | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivUnlcokSg($$) {
	my $xiv = shift;		chomp $xiv;
	my $sg_name = shift ; 	chomp $sg_name ;
	
	Info ("Going to Unlock the SnapGroup \"$sg_name\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv snap_group_unlock snap_group=$sg_name -y | grep \"Command executed successfully\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

sub XivMapVolToHost ($$$) {
	my $xiv = shift;		chomp $xiv;
	my $volume = shift;		chomp $volume;
	my $host = shift;		chomp $host;
	my $lun_id = 1;
	my $cmd = "";
	
	# Initialize $ExitCode
	my $ExitCode = 1;
	while ( ( $ExitCode ne 0 )  && ( $lun_id < 200 ) ) {
		Info ("Going to map volume $volume to host $host with lun id $lun_id on XIV $xiv \n");
		$cmd = "xcli -c $xiv map_vol host=$host vol=$volume lun=$lun_id | grep \"Command executed successfully\" " ; 
		$ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
		if ( $ExitCode eq 0 ) {
			return $ExitCode;
		} else {
			Info ("Could Not map volume to host with lun ID $lun_id, trying the next lun ID ...");
			$lun_id++;
		}
	}
	Info (" ExitCode is $ExitCode and lun_id is $lun_id \n");
	return 1;
}

sub XivUnMapFromHost ($$$) {
	my $xiv = shift;		chomp $xiv;
	my $volume = shift;		chomp $volume;
	my $host = shift;		chomp $host;
	
	Info ("Going to UnMap Volume \"$volume\" from host \"$host\" on XIV \"$xiv\" \n");
	my $cmd = "xcli -c $xiv unmap_vol vol=$volume host=$host | grep -e \"Command executed successfully\" -e \"MAPPING_IS_NOT_DEFINED\" -e \"Volume name does not exist\" " ;
	my $ExitCode = RunProgram($main::RunnigHost, "$cmd") ;
	return $ExitCode;
}

#-----------------------------------------------------------------------------#
# The Main package Section!
#

1;
 
