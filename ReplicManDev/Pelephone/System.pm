package Pelephone::System;

use strict;
use warnings;
use Sys::Hostname;
use Pelephone::System::Debug;
use Pelephone::Logger;

$| = 1;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

	$VERSION     = 1.00;

	@ISA         = qw(Exporter);
	@EXPORT      = qw(&RunProgram &CopyFile &ChkSum &ReTry &SetSecureMode
		&IsSecureMode &GetCommandResult &SetRetry &IsNumeric &GetOSVer &GetHostnameRemote
		&GetOSType &RunSub &CreateTempFile &IsMount &ClearTempFile &Mount
		&UMount &ForceUMount &FUser &FSCK &ForceMount &IsExist &GetOSVerRemote &GetOSTypeRemote &RunProgramQuiet &Tune2FS
	);

	@EXPORT_OK   = qw(@Result $ExitCode $SecureMode $RunRetry);
	%EXPORT_TAGS = ( );
}

our @EXPORT_OK;
our @Result;
our $ExitCode;
our $SecureMode;
our $RunRetry;

$SecureMode = "No" ;
$RunRetry = 3 ;

END { }

#-----------------------------------------------------------------------------#
# This function set the SecureMode parameter.                                 #
# input value are (Yes,yes,Y,y, No,no,N,n) incorrect value will return 1      #
#-----------------------------------------------------------------------------#
sub SetSecureMode($) {
	my $Mode = shift ;		chomp $Mode ;
	if ($Mode eq "Yes" || $Mode eq "yes" || $Mode eq "Y" || $Mode eq "y") {
		$SecureMode = "Yes" ;
	}elsif ($Mode eq "No" || $Mode eq "no" || $Mode eq "N" || $Mode eq "n") {
		$SecureMode = "No" ;
	}else{
		return 1 ;
	}
	return 0 ;
}
#-----------------------------------------------------------------------------#
# This function set the retry argument (0..100).                              #
#-----------------------------------------------------------------------------#
sub SetRetry ($) {
	my $number = shift ;	chomp $number ;
	Debug ("SetRetry", "the retry parameter is ($number)") ;
	if (IsNumeric($number)) {
		if ($number <= 100 && $number >= 0) {
			Debug ("SetRetry", "the retry parameter set to ($number)") ;
			$RunRetry = $number  ;
			return 0 ;
		}else{
			Debug ("SetRetry", "the retry parameter is Bigger then 100 or smaller then 0") ;
		}
	}
	return 8 ;
}
#-----------------------------------------------------------------------------#
# This function check if the system run in SecureMode.                        #
#-----------------------------------------------------------------------------#
sub IsSecureMode() {
	if ($SecureMode eq "Yes") { return 1 ;  }
	else                      { return 0 ;  }
}
#-----------------------------------------------------------------------------#
# This function check if the argument is numeric.                             #
#-----------------------------------------------------------------------------#
sub IsNumeric($) {
	my $number = shift ;	chomp $number ;
	LOOP:    {
		Debug ("IsNumeric", "the argument is : $number") ;
		if ($number =~ /0/) { $number =~ s/0//g ; redo LOOP ; }
		if ($number =~ /1/) { $number =~ s/1//g ; redo LOOP ; }
		if ($number =~ /2/) { $number =~ s/2//g ; redo LOOP ; }
		if ($number =~ /3/) { $number =~ s/3//g ; redo LOOP ; }
		if ($number =~ /4/) { $number =~ s/4//g ; redo LOOP ; }
		if ($number =~ /5/) { $number =~ s/5//g ; redo LOOP ; }
		if ($number =~ /6/) { $number =~ s/6//g ; redo LOOP ; }
		if ($number =~ /7/) { $number =~ s/7//g ; redo LOOP ; }
		if ($number =~ /8/) { $number =~ s/8//g ; redo LOOP ; }
		if ($number =~ /9/) { $number =~ s/9//g ; redo LOOP ; }
		if ("$number" ne "")  {
			Debug ("IsNumeric", "the argument is NOT a number") ;
			return 0 ;
		}
	}
	Debug ("IsNumeric", "the argument is a number !") ;
	return 1;
}
#-----------------------------------------------------------------------------#
# Return the output result of the last RunProgram executed.                   #
#-----------------------------------------------------------------------------#
sub GetCommandResult() {	return @Result ;	}
#-----------------------------------------------------------------------------#
# Clear an Array from LF characters.                                          #
#-----------------------------------------------------------------------------#
sub ClearLF(@) {
	my @output ;
	foreach my $var (@_) {
		chomp $var ;
		push (@output, $var) ;
	}
	return @output ;
}
#-----------------------------------------------------------------------------#
# This function run a program on a Host, if the host is not the current host  #
# the command will run in remote mode depend on the <Secure mode> variable    #
#-----------------------------------------------------------------------------#
sub RunProgram($$) {
	my $Host = shift ;				chomp $Host ;
	my $Command = shift ;			chomp $Command ;
	my $RunnigHost = hostname() ;	chomp $RunnigHost ;
	my $cmd = "" ;
	my $line = "";
	
	# Check if the LocalHost is the <running program host>
	if ($RunnigHost eq $Host || $Host eq "local") {
		Debug ("RunProgram", "Running command in local mode") ;
		$ExitCode = RunCommandLocal("$Command") ;
	}else{
		$ExitCode = RunCommandOnRemote ($Host, "$Command") ;
	}
	chomp $ExitCode ;
	@Result = ClearLF(@Result) ;
	# Only if there is output
	if ( $#Result > 0 ) {
		Info ("RunProgram------ The output of the \"$Command\" command is:\n");
	}
	foreach $line (@Result){
		Info("RunProgram------ $line");
	}
	Debug ("RunProgram", "The exit code is : $ExitCode") ;
	Debug ("RunProgram", "The Results are :") ;
	foreach $line (@Result){
		Debug("RunProgram","$line");
	}
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# Same as RunProgram except no OUTPUT is written to the log file		      #
#-----------------------------------------------------------------------------#
sub RunProgramQuiet($$) {
	my $Host = shift ;				chomp $Host ;
	my $Command = shift ;			chomp $Command ;
	my $RunnigHost = hostname() ;	chomp $RunnigHost ;
	my $cmd = "" ;
	my $line = "";
	
	# Check if the LocalHost is the <running program host>
	if ($RunnigHost eq $Host || $Host eq "local") {
		Debug ("RunProgram", "Running command in local mode") ;
		$ExitCode = RunCommandLocal("$Command") ;
	}else{
		$ExitCode = RunCommandOnRemote ($Host, "$Command") ;
	}
	chomp $ExitCode ;
	@Result = ClearLF(@Result) ;
	Debug ("RunProgram", "The exit code is : $ExitCode") ;
	Debug ("RunProgram", "The Results are :") ;
	foreach $line (@Result){
		Debug("RunProgram","$line");
	}
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
sub CreateTempFile() {
	my $tempfilePrefix = "/tmp/TTT_" . $$ . "." ;
	my $i = 1 ;
	while (1) {
		my $file = $tempfilePrefix . $i ;
		`ls $file >/dev/null 2>&1` ;
		if ($? ne 0) {
			return $file ;
		}else{
			$i ++ ;
		}
	}
}
#-----------------------------------------------------------------------------#
sub ClearTempFile() {
	my $tempfilePrefix = "/tmp/TTT_" . $$ . ".\*" ;
	system ("rm $tempfilePrefix 2>/dev/null") ;

}
#-----------------------------------------------------------------------------#
# This function run a program on The Local Host.                              #
#-----------------------------------------------------------------------------#
sub RunCommandLocal($) {
	my $Command = shift ;			chomp $Command ;
	my $STDOUT = CreateTempFile() ;	chomp $STDOUT ;
	my $STDERR = CreateTempFile() ;	chomp $STDERR ;

	Debug ("RunCommandLocal", "\"$Command \"") ;
	system ("$Command > $STDOUT 2>$STDERR") ;
	$ExitCode = $? >> 8;			chomp $ExitCode ;
	@Result = `cat $STDOUT` ;
	@Result = ClearLF(@Result) ;
	Debug ("RunCommandLocal", "The exit code is : $ExitCode") ;
	Debug ("RunCommandLocal", "The Results are : @Result") ;
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function run a program on a Remote Host.                               #
#-----------------------------------------------------------------------------#
sub RunCommandOnRemote($$) {
	my $host = shift ;			chomp $host ;
	my $Command = shift ;		chomp $Command ;

	if (IsSecureMode()) {
		Debug ("RunCommandOnRemote", "Running command in secure mode") ;
	}else{
		Debug ("RunCommandOnRemote", "Running command in regular mode") ;
	}

	# Build Remote Host Command File !!
	my $TempFile = CreateTempFile() ;		chomp $TempFile ;
	Debug ("RunCommandOnRemote", "The Command File is $TempFile") ;
	open (OUT,">$TempFile") || die "Can not create $TempFile\n" ;
	print OUT "$Command 2>&1\n" ;
	print OUT "echo \$?\n" ;
	print OUT "exit \n" ;
	close OUT ;

	Debug ("RunCommandOnRemote", "the Command File Contain :") ;
	if (IsDebugMode()) {
		system ("ls -l $TempFile") ;
		system ("cat $TempFile") ;
	}

	# Copy the command file
	my $targetfile = $host . ":" . $TempFile ;
	Debug ("RunCommandOnRemote", "Copying : $TempFile $targetfile") ;
	if (IsSecureMode()) { `scp $TempFile $targetfile >/dev/null 2>&1` ; }
	else                { `rcp $TempFile $targetfile >/dev/null 2>&1` ; }
	if ($? ne 0) {
		print "Can not copy command file to remote Host !!!\n" ;
		return 1 ;
	}

	# Run Command on Remote Host
	if (IsSecureMode()) { `ssh $host chmod +x $TempFile`;@Result = `ssh $host "$TempFile"` ; }
	else                { @Result = `rsh $host "$TempFile"` ; }
	$ExitCode = pop @Result ;		chomp $ExitCode ;
	Debug ("RunCommandOnRemote", "The exit code is : $ExitCode") ;
	Debug ("RunCommandOnRemote", "The Results are : @Result") ;
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function get <Function Name> and run it.                               #
#-----------------------------------------------------------------------------#
sub RunSub($) {
	# Get The function name to run....
	my $Func = shift ;		chomp $Func ;

	Debug ("RunSub", "running $Func") ;
	#Build the Ful Function Name (main::<xxx>) & build a referance to it.
	$Func = \& {"main::" . $Func} ;

	# Run the function ;
	&$Func ;
	return $? ;
}
#-----------------------------------------------------------------------------#
# Split Full FileName in the format "<host>:<full path>/<file name> to :      #
# <host name> , <full path file name>                                         #
#-----------------------------------------------------------------------------#
sub SplitFullFileName ($) {
	my $filename = shift ;		chomp $filename ;
	my ($Host, $File) ;

	if ($filename =~ /:/) {
		$Host = (split (':', $filename))[0] ;
		$File = (split (':', $filename))[1] ;
	}else{
		$Host = hostname() ;
		$File = $filename ;
	}
	return ($Host, $File) ;
}
#-----------------------------------------------------------------------------#
# This function copy file from one host to another.                           #
# the process will ReTry as define in the Variable <RunRetry>                 #
#-----------------------------------------------------------------------------#
sub CopyFile($$) {
	my $SourceFile = shift ;    chomp $SourceFile ;
	my $TargetFile = shift ;    chomp $TargetFile ;
	Debug ("CopyFile", "Source File -->$SourceFile") ;
	Debug ("CopyFile", "Target File -->$TargetFile") ;

	# Split the Source FileName to Host + FileName
	my ($SHost, $SFile) = SplitFullFileName($SourceFile) ;
	Debug ("CopyFile", "Source Host ==>$SHost") ;
	Debug ("CopyFile", "Source File ==>$SFile") ;

	# Split the Target FileName to Host + FileName
	my ($THost, $TFile) = SplitFullFileName($TargetFile) ;
	Debug ("CopyFile", "Target Host ==>$THost") ;
	Debug ("CopyFile", "Target File ==>$TFile") ;

	$ExitCode = RunProgramQuiet ($SHost, "ls $SFile >/dev/null 2>&1") ;
	my $Index = 0 ;
	if ($ExitCode eq 0) {   # The source file Exist !
		while ($Index < $RunRetry) {
			if ($SecureMode eq "Yes") { # Run In Secure Mode (scp)
				`scp $SourceFile $TargetFile >/dev/null 2>&1` ;
			}else{                      # Run In Un-Secure Mode (rcp)
				`rcp $SourceFile $TargetFile >/dev/null 2>&1` ;
			}
			$ExitCode = $? ;    chomp $ExitCode ;
			Debug ("CopyFile", "CopyFile: Copy the file (trying \#$Index ) exit code : $ExitCode") ;
			if ($ExitCode eq 0) {       # The Copy Comlete successfuly !
				# Check Sum of the Source & Target Files
				my $S_chsum = ChkSum ($SHost, $SFile) ;
				my $T_chsum = ChkSum ($THost, $TFile) ;
				Debug ("CopyFile", "SourceFile chksum = $S_chsum") ;
				Debug ("CopyFile", "TargetFile chksum = $T_chsum") ;
				if ($S_chsum eq $T_chsum) { # files are the same !!!
					$ExitCode = 0 ;
					return $ExitCode ;
				}else{                      # files are diffrent, copy failed !
					$ExitCode = 9 ;
				}
			}
			$Index ++ ;
		}
	}
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function make a CheckSum of file                                       #
#-----------------------------------------------------------------------------#
sub ChkSum($$) {
	my $Host = shift ;          chomp $Host ;
	my $File = shift ;          chomp $File ;
	my $cksum = 1 ;
	if (RunProgramQuiet ($Host, "cksum $File") eq 0) {
		$cksum = (split (' ', $Result[0]))[0] ;
	}
	return $cksum ;
}
#-----------------------------------------------------------------------------#
# This function run a program on a Host <#retry> numbers of times, if the     #
# time did not succeed.                                                       #
#-----------------------------------------------------------------------------#
sub ReTry($$) {
	my $Host = shift ;          chomp $Host ;
	my $Command = shift ;       chomp $Command ;
	my $ExitCode = 0 ;
	for (my $i = 0 ; $i < $RunRetry ; $i++) {
		$ExitCode = RunProgram ($Host, "$Command") ;
		if ($ExitCode eq 0) { return 0}
	}
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function return the OS Type (HPUX, Linux, SunOS etc.)                  #
#-----------------------------------------------------------------------------#
sub GetOSType() {
	my $OS = `uname -s` ;	chomp $OS ;
	return $OS ;
}
#-----------------------------------------------------------------------------#
# This function return the OS Version                                         #
#-----------------------------------------------------------------------------#
sub GetOSVer() {
	my $ver = `uname -r` ;	chomp $ver ;
	return $ver ;
}
#-----------------------------------------------------------------------------#
# This function Un-Mount FileSystem on Host !                                 #
#-----------------------------------------------------------------------------#
sub UMount($$) {
	my $host = shift ;		chomp $host ;
	my $mp = shift ;		chomp $mp ;
		
	my $mcmd = "/usr/sbin/umount $mp" ;
	my $ExitCode = ReTry ($host, $mcmd) ;
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function Mount FileSystem on Host !                                    #
#-----------------------------------------------------------------------------#
sub Mount($$) {
	my $host = shift ;		chomp $host ;
	my $mp = shift ;		chomp $mp ;

	my $mcmd = "/usr/sbin/mount $mp" ;
	my $ExitCode = ReTry ($host, $mcmd) ;
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function kill all Process that use FileSystem on Host !                #
#-----------------------------------------------------------------------------#
sub FUser($$) {
	my $host = shift ;		chomp $host ;
	my $mp = shift ;		chomp $mp ;

	my $mcmd = "/usr/sbin/fuser -cuk $mp" ;
	my $ExitCode = ReTry ($host, $mcmd) ;
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function run FSCK on FileSystem on Host !                              #
#-----------------------------------------------------------------------------#
sub FSCK($$) {
	my $host = shift ;		chomp $host ;
	my $mp = shift ;		chomp $mp ;

	my $mcmd = "/usr/sbin/fsck -y $mp" ;
	my $ExitCode = ReTry ($host, $mcmd) ;
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function Un-Mount FileSystem on Host, if the filesystem is busy, it    #
# kills all the process that use it and then umount it. !                     #
#-----------------------------------------------------------------------------#
sub ForceUMount($$) {
	my $host = shift ;		chomp $host ;
	my $mp = shift ;		chomp $mp ;
	my $mcmd ="";
	my $ExitCode = UMount ("$host", "$mp") ;
	if ($ExitCode) {
		my $retry = $RunRetry ;
		SetRetry(3) ;
		if ( GetOSTypeRemote($host) eq "Linux" ) {
			my $mcmd = "/usr/sbin/fuser -mk $mp > /dev/null 2>&1; /usr/sbin/umount $mp || (sleep 3;/usr/sbin/fuser -mk -9 $mp; /usr/sbin/umount $mp)" ;
			Info("Force - Umounting with $mcmd");
			$ExitCode = RunProgram ($host, $mcmd) ;
		}else {
			my $mcmd = "/usr/sbin/fuser -cuk $mp ; /usr/sbin/umount $mp" ;
			Info("Force - Umounting with $mcmd");
			$ExitCode = RunProgram ($host, $mcmd) ;
		}
	}
	return $ExitCode ;
}

#-----------------------------------------------------------------------------#
# This function Mount FileSystem on Host, if the filesystem is Corrupt, it    #
# run FSCK and then mount it. !                                               #
#-----------------------------------------------------------------------------#
sub ForceMount($$) {
	my $host = shift ;		chomp $host ;
	my $mp = shift ;		chomp $mp ;

	my $ExitCode = Mount ("$host", "$mp") ;
	if ($ExitCode) {
		$ExitCode = FSCK ("$host", "$mp") ;
		if (! $ExitCode) {
			$ExitCode = Mount ("$host", "$mp") ;
		}
	}
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function check if FileSystem is mounted !                              #
#-----------------------------------------------------------------------------#
sub IsMount ($$) {
	my $host = shift ;		chomp $host ;
	my $mp = shift ;		chomp $mp ;

	my $mcmd = "/usr/sbin/mount | grep -w $mp | grep -v $mp/" ;
	my $ExitCode = RunProgramQuiet ($host, $mcmd) ;
	return $ExitCode ;
}
#-----------------------------------------------------------------------------#
# This function check if File is Exist !                                      #
#-----------------------------------------------------------------------------#
sub IsExist ($$) {
	my $host = shift ;		chomp $host ;
	my $file = shift ;		chomp $file ;

	my $mcmd = "ls -l $file" ;
	my $result = RunProgram ($host, $mcmd) ;
	return $result ;
}
#-----------------------------------------------------------------------------#
# This function return the OS Version (HPUX, Linux, SunOS etc.)               #
#-----------------------------------------------------------------------------#
sub GetOSVerRemote($) {
	my $host = shift;		chomp $host;
	my $mcmd = "uname -r";
	RunProgramQuiet($host,$mcmd);
	my $ver = pop @Result; chomp $ver ;
	return $ver ;
}
#-----------------------------------------------------------------------------#
# This function return the OS Type (HPUX, Linux, SunOS etc.)                  #
#-----------------------------------------------------------------------------#
sub GetOSTypeRemote($) {
	my $host = shift;		chomp $host;
	my $mcmd = "uname -s";
	RunProgramQuiet($host,$mcmd); 
	my $OS = pop @Result; chomp $OS ;
	return $OS ;
}
#-----------------------------------------------------------------------------#
# This function return the hostname                                           #
#-----------------------------------------------------------------------------#
sub GetHostnameRemote($) {
	my $host = shift;		chomp $host;
	my $mcmd = "hostname";
	RunProgramQuiet($host,$mcmd); 
	my $OS = pop @Result; chomp $OS ;
	return $OS ;
}
#-----------------------------------------------------------------------------#
# This function :															  #
#	Setting maximal mount count to -1										  #
#	Setting interval between checks to 0 seconds		                      #
#-----------------------------------------------------------------------------#
sub Tune2FS($$) {
	my $host = shift ;		chomp $host ;
	my $mp = shift ;		chomp $mp ;
	
	my $mcmd = "/sbin/tune2fs -c 0 -i 0 $mp";
	my $ExitCode = RunProgramQuiet ($host, $mcmd) ;
	return $ExitCode ;
}
1;
