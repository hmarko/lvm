package Pelephone::RecoverPoint;  

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
	@EXPORT      = qw(&EnableImgAccess &CheckStorageAccess &DisableImgAccess);
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

}

our @EXPORT_OK;

END { }       # module clean-up code here (global destructor)
sub EnableImgAccess($$$) {
	my $rp_host = shift; chomp $rp_host;
	my $cg_name = shift; chomp $cg_name;
	my $cdp = shift; chomp $cdp;
	
	my $mcmd = "ssh admin\@$rp_host enable_image_access group=$cg_name copy=$cdp image=latest";
	my $ExitCode = RunProgram($main::RunnigHost, "$mcmd") ;
	return $ExitCode;
}

sub DisableImgAccess($$$) {
	my $rp_host = shift; chomp $rp_host;
	my $cg_name = shift; chomp $cg_name;
	my $cdp = shift; chomp $cdp;
	
	my $mcmd = "ssh admin\@$rp_host disable_image_access group=$cg_name copy=$cdp";
	my $ExitCode = RunProgram($main::RunnigHost, "$mcmd") ;
	return $ExitCode;
}

sub CheckStorageAccess($$$) {
	my $rp_host = shift; chomp $rp_host;
	my $cg_name = shift; chomp $cg_name;
	my $copy_name = shift; chomp $copy_name;
	
	my $mcmd = "ssh admin\@$rp_host verify_group group=$cg_name copy=$copy_name target_image=access_enabled";
	my $ExitCode = RunProgram($main::RunnigHost, "$mcmd") ;
	return $ExitCode;
}

#-----------------------------------------------------------------------------#
# The Main package Section!
#

1;
 
