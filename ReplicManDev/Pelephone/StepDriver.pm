package Pelephone::StepDriver ;

#use English '-no_match_vars';
use strict;
use warnings;
use Pelephone::Logger;
use Pelephone::System;

$| = 1 ;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	# set the version for version checking
	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw(&SetFirstStep &GetFirstStep
		&SetLastStep  &GetLastStep  &SetCurrentStep &GetCurrentStep
		&SetFromStep  &GetFromStep  &SetToStep      &GetToStep
		&SetShellName &GetShellName &SetWorkDir     &GetWorkDir
		&SetLogDate   &GetLogDate	&AddStep        &GetStepName
		&list_steps   &TS_Init      &GetStepDescription );
	%EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

	# your exported package globals go here,
	# as well as any optionally exported functions
	@EXPORT_OK   = qw(%StepsList %StepsParameter $LOCK_FILE);
}

our @EXPORT_OK;
our %StepsParameter;
our %StepsList;

our $ShellName ;
our $WorkDir ;
our $YYYYMMDD ;
our $TTY ;
our $LAST_STEP_COMPLETED ;
our $LOCK_FILE ;

END { }       # module clean-up code here (global destructor)

#-----------------------------------------------------------------------------#
sub SetStepParameter($$) {
	my $step_number = shift ;
	chomp $step_number ;
	my $parameter = shift ;
	chomp $parameter ;
	if (! IsNumeric($step_number)) {
		Exit ("The ($step_number) is invalid Step Number", 1) ;
	}
	$StepsParameter{$parameter} = $step_number ;
}
#-----------------------------------------------------------------------------#
sub SetFirstStep($)
	{	my $q = shift ; SetStepParameter ("$q", "FirstStep") ;		}
sub SetLastStep($)
	{	my $q = shift ; SetStepParameter ("$q", "LastStep") ;		}
sub SetCurrentStep($)
	{	my $q = shift ; SetStepParameter ("$q", "CurrentStep") ;	}
sub SetFromStep($)
	{	my $q = shift ; SetStepParameter ("$q", "FromStep") ;		}
sub SetToStep($)
	{	my $q = shift ; SetStepParameter ("$q", "ToStep") ;			}
#-----------------------------------------------------------------------------#
sub GetFirstStep()    {	return $StepsParameter{"FirstStep"} ;	}
sub GetLastStep()     {	return $StepsParameter{"LastStep"} ;	}
sub GetCurrentStep()  {	return $StepsParameter{"CurrentStep"} ;	}
sub GetFromStep()     {	return $StepsParameter{"FromStep"} ;	}
sub GetToStep()       {	return $StepsParameter{"ToStep"} ;		}
#-----------------------------------------------------------------------------#
sub SetShellName($)   {	my $q = shift ; chomp $q ; $ShellName = $q ;	}
sub GetShellName()    {	return $ShellName ;	}
#-----------------------------------------------------------------------------#
sub SetWorkDir($)	  {	my $q = shift ; chomp $q ; $WorkDir = $q ;	}
sub GetWorkDir()      {	return $WorkDir ;	}
#-----------------------------------------------------------------------------#
sub SetLogDate($)	  {	my $q = shift ; chomp $q ; $YYYYMMDD = $q ;	}
sub GetLogDate()      {	return $YYYYMMDD ;	}
#-----------------------------------------------------------------------------#
sub CreateFileFrefix($$) {
	my $Add = shift ;	chomp $Add ;
	my $Tail = shift ;	chomp $Tail ;
	my $LOG_FILE = GetWorkDir() . "/TS_" . GetShellName() . "_" . GetLogDate() ;
	if ("$Add" ne "") {	$LOG_FILE .= "." . $Add ; }
	$LOG_FILE .= $Tail ;
	return $LOG_FILE ;
}
#-----------------------------------------------------------------------------#
sub CreateFileFrefix_short($$) {
	my $Add = shift ;	chomp $Add ;
	my $Tail = shift ;	chomp $Tail ;
	my $LOG_FILE = GetWorkDir() . "/TS_" . GetShellName() ;
	if ("$Add" ne "") {	$LOG_FILE .= "." . $Add ; }
	$LOG_FILE .= $Tail ;
	return $LOG_FILE ;
}
#-----------------------------------------------------------------------------#
sub CreateLog($) {
	my $LOG_FILE = CreateFileFrefix($_[0], ".log") ;
	Pelephone::Logger::Init("$LOG_FILE") ;
	return $LOG_FILE ;
}
#-----------------------------------------------------------------------------#
sub CreateSeqFile($) {
	my $LOG_FILE = CreateFileFrefix_short($_[0], ".seq") ;
	my $result = system ("touch $LOG_FILE") ;
	if ( $result ne 0 ) {
		Exit (GetShellName() . ": cannot create sequence file: $LOG_FILE", 1 );
	}
	return $LOG_FILE ;
}
#-----------------------------------------------------------------------------#
sub CreateLockFile($) {
	my $LOCK_PEFIX = CreateFileFrefix_short($_[0], ".lock") ;
	my $LOCK_FILE = $LOCK_PEFIX . "." . $$ ;
	my $result = system ("touch $LOCK_FILE") ;
	if ( $result ne 0 ) {
		Exit (GetShellName() . ": cannot create lock file: $LOCK_FILE", 1 );
	}

	foreach my $lock (`ls $LOCK_PEFIX*`) {
		chomp $lock ;
		if ( "$lock" ne "$LOCK_FILE" ) {
			# lock file with same DISK and YYYYMMDD exist
			my $pid = $lock ;
			$pid =~ s/.*lock\.// ;
			my $result = kill (0, $pid) ;
			if ( $result eq 1 ) {
				Info (GetShellName() . ": duplicate shell:") ;
				Exit ("LOG_DIR=" . GetWorkDir() . "YYYYMMDD=" . GetLogDate() . " pid: $pid", 1) ;
			}else{
				# clean up the old file
				system ("rm -f $lock") ;
			}
		}
	}

	return $LOCK_FILE ;
}
#-----------------------------------------------------------------------------#
sub AddStep($$$) {
	my $step_number = shift ;	chomp $step_number ;
	my $step_name   = shift ;	chomp $step_name ;
	my $step_desc   = shift ;	chomp $step_desc ;
	$StepsList{$step_number} = $step_name . ";" . $step_desc ;
}
#-----------------------------------------------------------------------------#
sub GetStepName($) {
	my $StepNumber = shift ;	chomp $StepNumber ;
	my $info = $StepsList{$StepNumber} ;
	my $StepName = (split (';', $info))[0] ;
	chomp $StepName ;
	return $StepName ;
}
#-----------------------------------------------------------------------------#
sub GetStepDescription($) {
	my $StepNumber = shift ;	chomp $StepNumber ;
	my $info = $StepsList{$StepNumber} ;
	my $StepDesc = (split (';', $info))[1] ;
	chomp $StepDesc ;
	return $StepDesc ;
}
#-----------------------------------------------------------------------------#
sub GetStepsList() {
	my @Steps ;
	foreach my $key (sort keys %StepsList) {
		push @Steps , $key ;
	}
	return @Steps ;
}
#-----------------------------------------------------------------------------#
sub UpdateCurrentStep() {
	my $step = GetCurrentStep() + 1 ;
	$step = "0" . $step if ($step < 10) ;
	SetCurrentStep ("$step") ;
}
#-----------------------------------------------------------------------------#
# list step names and descriptions for requested steps                        #
#-----------------------------------------------------------------------------#
sub list_steps() {
	print "Step listing for program : " , GetShellName, "\n\n" ;
	foreach my $key (GetStepsList()) {
		my $StepName = GetStepName($key) ;
		my $StepDesc = GetStepDescription($key) ;
		print "Step: $key\n" ;
		print "   STEP_NAME: $StepName\n" ;
		print "   DESCRIPTION: $StepDesc\n" ;
	}
}
#-----------------------------------------------------------------------------#
# save the last successfully run step in a sequence file                      #
#-----------------------------------------------------------------------------#
sub step_mark_completed() {
	# save the current step's number in the sequence file
	open (SEQ, ">$LAST_STEP_COMPLETED")
		|| die "Can Not Open sequence file $LAST_STEP_COMPLETED" ;
	print SEQ GetCurrentStep() ;
	close SEQ ;
}
#-----------------------------------------------------------------------------#
# get the last successfully run step in a sequence file                       #
#-----------------------------------------------------------------------------#
sub get_last_step_completed() {
	# save the current step's number in the sequence file
	my $step = 0 ;
	$step = `cat $LAST_STEP_COMPLETED` ;
	if ("$step" eq "") {	$step = 0 ;		}
	return $step ;
}
#-----------------------------------------------------------------------------#
#    This program is used by shell scripts that are split into steps.         #
#    It verifies that the previous step completed successfully.               #
#-----------------------------------------------------------------------------#
sub step_verify_sequence() {

	my $missed_step = 0 ; ;

	# read the last successfully completed step from the sequence file
	my $last_step = get_last_step_completed() ;
	my $i = GetCurrentStep() - 1 ;

	if ($last_step > 0) {
		# check for existence of steps between the current and the last run
		while ( $i > $last_step ) {
			if ( exists $StepsList{$i} ) {
				$missed_step = 1 ;
				Info (GetShellName() . ": WARNING step ${i} " . GetStepName($i) . " has not completed successfully.") ;
			}
			$i -= 1 ;
		}
	}else{
		# check for existence of steps between the first step and the current step
		$i = GetFirstStep() ;
		while ( $i < GetCurrentStep() ) {
			if ( exists $StepsList{$i}  ) {
				$missed_step = 1 ;
				Info (GetShellName() . ": WARNING step ${i} " . GetStepName($i) . " has not completed successfully.") ;
			}
			$i += 1 ;
		}
	}

	# prompt the operator to continue if missing steps existed
	if ( $missed_step ) {
		if ( $TTY ne "remote") {
			print "Are you sure that you want to continue running the program " . GetShellName() . "?\n" ;
			print "(y, n default is n): " ;
			my $ans = <STDIN> ;
			chomp $ans ;
			print "The Anser is $ans\n" ;
			if ( $ans eq "y" || $ans eq "Y" ) {
				Info ("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!") ;
				Info ("WARNING: operator running step " . GetCurrentStep() . " despite missing step(s)") ;
				Info ("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!") ;
			}else{
				Info (GetShellName() . " execution CANCELLED by operator") ;
				Exit ("Exiting...", 1) ;
			}
		}else{
			Info ("Unable to continue due to missing steps") ;
			Exit (GetShellName() . " execution ABORTED", 1) ;
		}
	}
}
#-----------------------------------------------------------------------------#
#   Program starts here
#-----------------------------------------------------------------------------#
sub TS_Init($) {
	my $init_var = shift ;
	my $LOG_FILE = CreateLog("$init_var") ;

	# set FROM_STEP and TO_STEP if they were not specified
	SetFromStep (GetFirstStep()) if (GetFromStep() eq 0) ;
	SetToStep   (GetLastStep())  if (GetToStep() eq 999) ;

	if (GetFromStep() > GetToStep()) {
		Exit (GetShellName() . ": FROM_STEP " . GetFromStep() . " is greater than TO_STEP " . GetToStep(), 1) ;
	}

	# job banner
	Banner ("- START -") if ( GetCurrentStep() eq GetFirstStep() ) ;

	# set working directory if DISK environment variable provided
	if ( GetWorkDir() ne "" ) {
		my $rv = chdir GetWorkDir() ;
		unless ( $rv ) {
			Exit (GetShellName() . ": unable to change directories to" . GetWorkDir(), 1) ;
		}else{
			Info ("\n" . GetShellName() . ": working directory set to " . GetWorkDir()) ;
		}
	}

	# check for existence of same program with same parameters
	$LOCK_FILE = CreateLockFile("$init_var") ;

	# create sequence log file
	$LAST_STEP_COMPLETED = CreateSeqFile ("$init_var") ;

	Info ("The Sequence file is : $LAST_STEP_COMPLETED") ;

	# log that the job was (re-)started
	Info "START: $main::COMMAND_LINE" ;
	Info "computer: $main::RunnigHost process: $$ tty: $TTY" ;
	Info "----------------- environment variables ----------------" ;
	foreach my $key (sort keys %ENV) {
		Info "$key=$ENV{$key}\n" ;
	}
	Info "----------------- environment variables ----------------" ;

	Info "\n" . GetShellName() . " STARTED" ;
	Info "\nLOG_FILE=$LOG_FILE" ;
	Info "\nDISK=" . GetWorkDir() . "  YYYYMMDD=" . GetLogDate() . " FROM_STEP=" . GetFromStep() . " TO_STEP=" . GetToStep() ;

	if ( (GetFromStep() eq GetToStep()) && (! exists $StepsList{GetFromStep()}) ) {
		Exit ("Step " . GetFromStep() . " does not exist.", 1) ;
	}

	while ( GetCurrentStep() le GetToStep() ) {
		#	verify that previous steps have been run before proceeding
		step_verify_sequence() ;

		#	step banner
		Banner ("STEP " . GetCurrentStep()) ;
		Info ("DESCRIPTION: " .GetStepDescription(GetCurrentStep())) ;
		Info ("Step " . GetCurrentStep() . " " . GetStepName(GetCurrentStep()) . " BEGIN") ;

		# Run the Step Procedure.
		RunSub (GetStepName(GetCurrentStep())) ;

		Info ("Step " . GetCurrentStep() . " " . GetStepName(GetCurrentStep()) . " END") ;
		Info ("-------------------------------------------------------") ;

		# call script which marks the completed step number in a sequence file
		step_mark_completed() ;

		# find next step
		UpdateCurrentStep() ;
		while ( (! exists $StepsList{GetCurrentStep()}) && (GetCurrentStep() lt GetLastStep())) {
			UpdateCurrentStep() ;
		}
	}

	#job ended banner
	Info ("\n" . GetShellName() . " FINISHED") ;
	Banner("- FINISH -") if ( GetToStep() eq GetLastStep() ) ;
	system("rm $LOCK_FILE") ;
}


SetFromStep("0") ;
SetToStep("999") ;

SetWorkDir("/tmp") ;

my $YY = `date +'%Y%m%d'` ;
SetLogDate("$YY") ;

# check if un via interactive shell
$TTY = `tty` ;
$TTY =~ s/not a tty/remote/ ;

1;
