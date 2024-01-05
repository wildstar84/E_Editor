#!/usr/bin/perl

#NOTE: POD compile:  pp -g -x -M e_static_highlightmodules -M Tk::XMLViewer -o ec.exe e.pl
#NOTE: POD compile:  pp -g -x -M e_static_basemodules -o e.exe e.pl
#NOTE: Windows compile:  perl2exe -gui -perloptions="-p2x_xbm -s" e.pl

#NOTE: In Winblows, you MUST set the palette when starting up rather than 
#relying on the Windows default IF you wish to be able to change the palette 
#later to something that would (using our hacked setPalette routine) be set 
#to a white ("Nite") foreground!!!!  Easiest way 2 do this is to create an 
#"Xdefaults" file in same directory this pgm is in w/ the line:
#tkPalette="#rrggbb"
#You can set this to something very close to Winblows' default background color.

$showgrabopt = '';
$showgrabopt = '-nograb';   #UNCOMMENT IF YOU HAVE MY LATEST VERSION OF JDIALOG!

#use lib "/perl/lib";
#use lib "/perl/site/lib";
#use lib ".";

########### THIS SECTION NEEDED BY PAR COMPILER! ############
#NOTE:  FOR SOME REASON, v.pl NEEDS BUILDING WITH:  pp -M Tk::ROText ...!
#REASON:  par does NOT pick up USE and REQUIRE's quoted in EVAL strings!!!!!

#
#STRIP OUT INC PATHS USED IN COMPILATION - COMPILER PUTS EVERYTING IN IT'S OWN
#TEMPORARY PATH AND WE DONT WANT THE RUN-TIME PHISHING AROUND THE USER'S LOCAL
#MACHINE FOR (POSSIBLY OLDER) INSTALLED PERL LIBS (IF HE HAS PERL INSTALLED)!
BEGIN
{
	$v = 1  if ($0 =~ /v\w?\./io);
	$isExe = 1  if ($0 =~ /exe$/io);
	if ($isExe)
	{
		while (@INC)
		{
			$_ = shift(@INC);
			push (@myNewINC, $_)  if (/(?:cache|CODE)/o);
		}
		@INC = @myNewINC;
		eval ($0 =~ /[ev]c\w*\./io) ? 'use e_static_highlightmodules'
				: 'use e_static_basemodules';
	}
	else
	{
		while (@INC)   #REMOVE THE "." DIRECTORY!
		{
			$_ = shift(@INC);
			push (@myNewINC, $_)  unless ($_ eq '.');
		}
		@INC = @myNewINC;
	}
	#HANDLE OLD PERL "-s":  (WE DO THIS INSTEAD OF GETOPT::LONG SO WE CAN SET ARGUMENT-LESS OPTIONS TO 1 ("TRUE"))
	my @NEWARGV = ();
	foreach my $arg (@ARGV) {
		if ($arg ne '-' && $arg =~ s/^\-\-?//o) {
			($arg =~ s/\=(.+)$//o) ? eval "\$$arg = \$1;" : eval "\$$arg = 1;";
#			eval "print \"--opt($arg)=\$$arg\n\"";
		} else {
			push @NEWARGV, $arg;
		}
	}
	@ARGV = @NEWARGV;
}
################# END PAR COMPILER SECTION ##################
use File::Copy;
use Tk;                  #LOAD TK STUFF
use Tk ':eventtypes';
use Tk::JDialog;
use Tk::ROText;       #REQUIRED BY e_*.pl!
use Tk::TextUndo;
use Tk::Menubutton;
use Tk::Checkbutton;
use Tk::Radiobutton;
use Tk::ColorEditor;  #ADDED 20010131.
use Tk::Adjuster;
use Text::Tabs;
use Cwd;

our $haveTime2fmtstr = 0;

eval 'use Tk::DragDrop::Win32Site; use Tk::DropSite qw(Win32); $w32dnd = 1; 1;';
$autoScroll = 0;
eval 'use Tk::Autoscroll; $autoScroll = 1; 1';

eval 'use File::Spec::Win32; 1';
eval 'use File::Glob; 1';
#use Tk::Canvas;
#use Tk::Scale;
#xuse Tk::JOptionmenu;
$haveXML = 0; $haveTextHighlight = 0; $Ansicolor = 0; $SuperText = 0; $havePerlCool = 0;
$haveHTML = 0; $haveJS = 0; $haveBash = 0; $haveKate = 0; $haveNotebook = 0;

$Steppin = ($ENV{'DESKTOP_SESSION'} =~ /AfterStep/io) ? 1 : 0;
$Steppin = 0;  #DON'T NEED ANYMORE (NOW THAT WE FORKED/FIXED AfterStep)!
$bummer = 1  if ($^O =~ /Win/o);
$TwilightThreshold = 75000;

eval 'use Tk::NoteBook; $haveNotebook = 1; 1' unless ($nobrowsetabs);
$nobrowsetabs = 1  unless ($haveNotebook);

if ($bummer)
{
	$ENV{'HOME'} ||= $ENV{'HOMEDRIVE'} . $ENV{'HOMEPATH'};
	$ENV{'HOME'} ||= $ENV{'USERPROFILE'}  if (defined $ENV{'USERPROFILE'});
	$ENV{'HOME'} ||= $ENV{'ALLUSERSPROFILE'}  if (defined $ENV{'ALLUSERSPROFILE'});
	$ENV{'HOME'} =~ s#\\#\/#gso;
}

#$winGeometry = 0;
#our @geometry = (0, 0);

#FETCH ANY USER-SPECIFIC OPTIONS FROM e.ini:

$pgmhome = $0;
$pgmhome =~ s#[^/]*$##;  #SET NAME TO SQL.PL FOR ORAPERL!
$pgmhome ||= './';
(my $usehome = $pgmhome) =~ s#\/bin\/#\/share\/E\/#  unless ($bummer);
$pgmhome = $usehome  if (-d $usehome);
print DEBUG "-!!!- pgmhome=$pgmhome=\n"  if ($debug);
$pgmhome .= '/'  unless ($pgmhome =~ m#/$#o);
#$pgmhome = 'c:/perl/bin/'  if ($bummer && $pgmhome =~ /^\.[\/\\]$/o);

$homedir ||= $ENV{'HOME'};
$homedir ||= &cwd()  unless ($nocwd);
$homedir .= '/'  unless ($homedir =~ m#\/$#o);
@searchTagList = (0);
my $curdir;  # ||= &cwd()  unless ($nocwd);   #THIS VARIABLE ONLY USED FOR FINDING THE ".ini" FILE TO USE!
$curdir ||= &cwd(); 
#IF WE LATER FIND WE NEED THE "CURRENT DIR", WE'LL NEED TO SAVE &cwd() RESULTS AGAIN!
$debug = 1  if ($d || $debug);
open DEBUG, ">/tmp/e.dbg"  if ($debug);
#print DEBUG "--BEF-- ini dir=$curdir=  trying to open profile(${homedir}.myeprofiles)\n"  if ($debug);
if ($ARGV[0])
{
	(my $argPath = $ARGV[0]) =~ s#\/[^\/]+$##o;
	$argPath = '.'  if ($argPath eq $ARGV[0]);   #JWT:ADDED 20130506 TO CAUSE THE SEARCH FOR ini FILES TO START IN DIRECTORY THE FILE IS IN (EVEN IF THE FILE NAME CONTAINS NO PATH INFO)!
	my $argPathwSlash = $argPath;
	$argPathwSlash .= '/'  unless ($argPathwSlash =~ m#\/$#);
	$_ = ($0 =~ m#\/([^\/]+)$#o) ? $1 : $0;
	s/(\w+)\.\w+$/$1\.ini/g;

	#LOOKING FOR AN .ini FILE:

	if (-r  "${argPathwSlash}$_")   #1: THERE'S AN .ini FILE IN THE DIR WHERE THE FILE BEING EDIT IS - USE THAT!
	{
		$curdir = $argPathwSlash;
		print DEBUG "+++ USING (${argPathwSlash}$_)! FOR INI (found in same dir as file being edited!\n"  if ($debug);
	}
	else  #2: CHECK ~/.myeprofiles FOR A MAPPING OF THE DIR WHERE THE FILE BEING EDIT IS, IF SO, USE THAT!
	{
		if (-f "${homedir}.myeprofiles" && open(PROFILE, "${homedir}.myeprofiles"))
		{
			my ($srcPath, $profilePath);
			if ($argPath eq '.') {
				$argPath = $curdir;
			} elsif ($argPath !~ m#^\/#) {
				$argPath = ($curdir =~ m#\/$#) ? "${curdir}$argPath" : "${curdir}/$argPath";
			}
			while (<PROFILE>)
			{
				chomp;
				s/[\r\n\s]+$//o;
				s/^\s+//o;
				next  if (/^\#/o);
				next  unless (/\:/o);
				s/^(\w)\:/$1\^/o;   #PROTECT WINBLOWS DRIVE-LETTERS!
				($srcPath, $profilePath) = split(m#\/?\:#o, $_, 2);
				print DEBUG "******* ARGPATH=$argPath= curdir=$curdir= PROFILEPATH=$srcPath($profilePath)=\n"  if ($debug);
				if ($argPath =~ /^$srcPath/ || $curdir =~ /^$srcPath/)
				{
					$curdir = $profilePath;
					print DEBUG "******* PATH FOUND IN PROFILE - WILL USE =$profilePath=\n"  if ($debug);
					last;
				}
			}
			close PROFILE;
		}
	}
}
$curdir ||= $homedir;   #3:  IF NOTHING FOUND IN ~/.myeprofiles, TRY USER'S HOME DIRECTORY:
print DEBUG "--AFT-- ini dir=$curdir= ARGV0=$ARGV[0]=\n"  if ($debug);

$curdir .= '/'  unless ($curdir =~ m#\/$#o);
$cwd ||= $curdir;
$_ = ($0 =~ m#\/([^\/]+)$#o) ? $1 : $0;
s/(\w+)\.\w+$/$1\.ini/g;
%mimeTypes = ();

while ($curdir) {  #4: TRY THE DIRECTORY'S PARENTS, UP TO AND INCLUDING "/":
	print DEBUG "-0: trying (${curdir}$_)!\n"  if ($debug);
	last  if (-r "${curdir}$_");
	chop $curdir;
	last  unless ($curdir);
	$curdir =~ s#\/[^\/]+$#\/#o;
}

unless ($curdir)  #5: TRY THE PROGRAM'S "SHARED HOME" (../share/E/):
{
	$_ = ($0 =~ m#\/([^\/]+)$#o) ? $1 : $0;
	s/\..*$/\.ini/;
	$_ = $pgmhome . $_;
	print DEBUG "----2a: (look in program share dir($pgmhome): ini=$_=\n"  if ($debug);
	unless (-r $_) {   #6: LASTLY, TRY THE DIRECTORY THE PGM RESIDES IN - ONLY NEEDED FOR MY LEGACY CONFIGURATION (asstartuppre.pl)!
		$_ = $0;
		s/(\w+)\.\w+$/$1\.ini/g;
		print DEBUG "----2b: (look in program dir): ini=$_=\n"  if ($debug);
	}
}

print DEBUG "-3: will use (${curdir}$_)!\n"  if ($debug);
if (open PROFILE, "${curdir}$_")
{
	while (<PROFILE>)
	{
		chomp;
		s/[\r\n\s]+$//o;
		s/^\s+//o;
		next  if (/^\#/o);
		($opt, $val) = split(/\=/o, $_, 2);
		if ($opt =~ /^\$/o)
		{
			eval "$opt = \"$val\";";
		}
		else
		{
			${$opt} = $val  if ($opt && !defined(${$opt}));
		}
	}
	close PROFILE;
}

if ($0 =~ /exe$/io)   #FETCH COMMAND-LINE OPTIONS SINCE "-s" DOES NOT WORK IN PAR .exe'S?!
{
	my ($arg, $var, $val);
	while ($#ARGV >= 0 && $ARGV[0] =~ /^\-/o)
	{
		($arg = shift) =~ s/^\-//o;
		($var, $val) = split(/\=/o, $arg);
		$val = 1  unless (length $val);
		eval "\$$var = \"$val\"";
	
	}
}

if ($v)
{
	$viewer ||= 'ROTextHighlight'  if ($0 =~ /vc\w*\.(?:exe|pl)$/io);
#	eval 'use Tk::XMLViewer; $haveXML = 1; 1'  if ($xml);
	eval 'use Tk::XMLViewer; $haveXML = 1; 1'  unless ($0 =~ /vc\w*\.(?:exe|pl)$/io);
	eval 'use Tk::Text::ROSuperText; $SuperText = 1; $AnsiColor = 1; 1';
	eval 'use Tk::ROTextANSIColor; $AnsiColor = 1; 1'  unless ($SuperText || $viewer =~ /texthighlight/i);
	if ($viewer eq 'ROTextHighlight')
	{
		eval 'use Tk::TextHighlight::Perl; use Tk::ROTextHighlight; $haveTextHighlight = 1; 1';
		eval 'use Tk::TextHighlight::PerlCool; $havePerlCool = 1; 1';
		eval 'use Syntax::Highlight::Engine::Kate; $haveKate = 1; 1';
		$SuperText = 0;   #JWT:ADDED 20150606 TO PREVENT BINDWHEELMOUSE WHEN NOT RUNNING SUPERTEXT!
	}
	elsif ($viewer)
	{
		eval "use Tk::$viewer; 1";
		if ($viewer =~ /SuperText/o)
		{
			$SuperText = 1;
			$viewer = '';
		}
	}
#print DEBUG "-???- viewer=$viewer= st=$SuperText= ac=$AnsiColor=\n"  if ($debug);
}
else
{
	$editor ||= 'TextHighlight'  if ($0 =~ /[ev]c\w*\.(?:exe|pl)$/io);
	if ($editor eq 'TextHighlight')
	{
		eval 'use Tk::TextHighlight; $haveTextHighlight = 1; 1';
		eval 'use Tk::TextHighlight::PerlCool; $havePerlCool = 1; 1';
		eval 'use Syntax::Highlight::Engine::Kate; $haveKate = 1; 1';
	}
	elsif ($editor)
	{
		eval "use Tk::$editor; 1";
		if ($editor =~ /SuperText/o)
		{
			$SuperText = 1;
			$editor = '';
		}
	}
	else
	{
		eval 'use Tk::Text::SuperText; $SuperText = 1; 1';
	}
}
$havePerlCool = $havePerlCool ? 'PerlCool' : 'Perl';
eval { require 'setPalette.pl'; };
require 'getopts.pl';

require 'JCutCopyPaste.pl';

%extraOptsHash = ();
unless (defined $focus)
{
	$focus = 1  if ($ARGV[1]);
}
$focus ||= 0;
$focustab ||= $nobrowsetabs ? '' : 'Tab1';
$focustab = 'Tab'.($focustab+1)  if ($focustab =~ /^\d+$/o);

#print DEBUG "-???- codetext=$codetext=\n"  if ($debug);
if ($haveTextHighlight)
{
	my $spacesperTab = $tabspacing || 3;
	my $tspaces = ' ' x $spacesperTab;
	if ($v) {
		%{$extraOptsHash{rotexthighlight}} = (-syntax => ($codetext||$havePerlCool), 
				-autoindent => 1, 
				-rulesdir => ($codetextdir||$ENV{'HOME'}),
				-indentchar => ($notabs ? $tspaces : "\t"),
				-highlightInBackground => (defined $hib) ? $hib : 1
		);
	} else {
		%{$extraOptsHash{texthighlight}} = (-syntax => ($codetext||$havePerlCool), 
				-autoindent => 1, 
				-rulesdir => ($codetextdir||$ENV{'HOME'}),
				-indentchar => ($notabs ? $tspaces : "\t"),
				-highlightInBackground => (defined $hib) ? $hib : 1
		);
	}
}

#eval 'require "BindMouseWheel.pl"; $WheelMouse = 1; 1';
if ($SuperText)    #OTHER TEXT WIDGETS DON'T NEED THIS!
{
eval
	{
		require "BindMouseWheel.pl"; $WheelMouse = 1;
	};
}
#print "-eval returned =$@=  wm=$WheelMouse= package=".__PACKAGE__."=\n";

use Tk::JFileDialog;

#-----------------------

$vsn = '6.35';

$editmode = 'Edit';
if ($v)
{
#	$SuperText = 0;
	$editmode = 'View';
#	$haveTextHighlight = 0;
}

my (%cmdfile, %marklist, %opsysList, %alreadyHaveXMLMenu, %activeWindows, %text1Hash);
my (%scrnCnts, %saveStatus);
my $nextTab = '1';

$systmp ||= '/tmp';
$hometmp = (-w "${homedir}tmp") ? "${homedir}tmp" : $systmp;
$webtmp ||= $ENV{'WEBTMP'} || $hometmp;
$dirsep = '/';
if ($bummer)
{
	$hometmp =~ s#\/#\\#go;
	$hometmp = '\\' . $hometmp  unless ($hometmp =~ m#^(?:\\|\w\:)#o);
	unless (-w $hometmp)
	{
		$hometmp = 'C:' . $hometmp  unless ($hometmp =~ m#^\w\:#o);
		$hometmp =~ s/^\w\:/C\:/o  unless (-w $hometmp);
		$hometmp =~ s#\/#\\#gso;
	}
	$dirsep = '\\';
}
$startpath = '.';
@fnkeyText = (0);
$srchopts = '-nocase';
@srchTextChoices = ('');
%replTextChoices = ('' => '');
%srchOptChoices = ('' => $srchopts);
$srchTextVar = '';
$markSelected = '';

my $markMenuTop = $bummer ? 1 : 2;
#eval {$host = $bummer ? `hostname` : `uname -n`;};
$host = (-x '/usr/local/bin/vhostname') ? `vhostname` : `hostname`;
chomp($host);
$host ||= $bummer ? 'Windows' : 'Local';
$titleHeader = "${host}: E Perl/Tk Editor v$vsn";
print DEBUG "--F=$f= cwd=${cwd}.myefonts= hmdir=${homedir}.myefonts= pgm=${pgmhome}myefonts=\n"  if ($debug);
if (($f && open(T, $f)) || open(T, "${cwd}.myefonts") 
		|| open (T, "${homedir}.myefonts") || open (T, "${pgmhome}myefonts"))
{
	my $i = 0;
	while (<T>)
	{
		chomp;
		next  if (/^\#/o);
		($fontnames[$i], $fixedfonts[$i]) = split(/\:/o);
		$fixedfonts[$i] =~ s/\#.*$//o;
		print DEBUG "-----FF[$i]=$fixedfonts[$i]= FN=$fontnames[$i]=\n"  if ($debug);
		$i++;
	}
	close T;
}
else
{
	print DEBUG "-???- COULD NOT OPEN *myefonts!\n"  if ($debug);
	$fixedfonts[0] = '-*-lucida console-medium-r-normal-*-17-*-*-*-*-*-*-*';
	$fixedfonts[1] = '-*-lucida console-medium-r-normal-*-10-*-*-*-*-*-*-*';
	$fixedfonts[2] = '-*-lucida console-medium-r-normal-*-14-*-*-*-*-*-*-*';
	$fixedfonts[3] = '-*-lucida console-medium-r-normal-*-20-*-*-*-*-*-*-*';
	$fixedfonts[4] = '-*-lucida console-medium-r-normal-*-25-*-*-*-*-*-*-*';
	$fixedfonts[5] = '-*-lucida console-medium-r-normal-*-32-*-*-*-*-*-*-*';
	@fontnames = (qw(Normal Weensey Tiny Medium Large HUGE));
print DEBUG "--(else)---FF[0]=$fixedfonts[0]= FN=$fontnames[0]=\n"  if ($debug);
}
chomp ($host);
$host =~ s/^([^\.]+)\..*$/$1/g;  #STRIP OFF DOMAIN NAME.
$host = "\u\L$host\E";
$width ||= 80;
$height ||= 30;
@runwidth = ($popw||64, $popw||64, $popw||40);     #(Check, Run, Eval)
@runheight = ($poph||10, $poph||16, $poph||10);
$popGeometry = 0;
$histFile ||= ($v && -e "${homedir}.myvhist") ? "${homedir}.myvhist" : "${homedir}.myehist";
$pathFile ||= ($v && -e "${homedir}.myvpaths") ? "${homedir}.myvpaths" : "${homedir}.myepaths";
#ON WINDOWS, DEFAULT TO USING .lnk FILES IN USER'S "Favorites" DIRECTORY CREATED BY USER IN WINDOWS EXPLORER:
$pathFile = $ENV{'HOME'} . '/Favorites'  if ($bummer && ($pathFile !~ /\w/o || !(-f $pathFile)) && -d ($ENV{'HOME'} . '/Favorites'));
$backupct = 0;
$marklist{''}[0] = ':insert:sel:';
$marklist{''}[1] = ':insert:sel:';

print DEBUG "--font case: tf(2)=$tf= lf(4)=$lf= mf(3)=$mf= wf(1)=$wf= hf(5)=$hf= fn=$fn=\n"  if ($debug);
$fixedfont = '';
if (defined($tf))      #TINY FONT.
{
	$fixedfont = $fixedfonts[2];
}
elsif (defined($lf))   #LARGE FONT.
{
	$fixedfont = $fixedfonts[4];
}
elsif (defined($mf))   #LARGE FONT.
{
	$fixedfont = $fixedfonts[3];
}
elsif (defined($wf))   #WEENSEY FONT.
{
	$fixedfont = $fixedfonts[1];
}
elsif (defined($hf))   #HUGE FONT.
{
	$fixedfont = $fixedfonts[5];
}
elsif (defined($fn))   #FONT INDEX SPECIFIED.
{
	$fixedfont = $fixedfonts[$fn] || $fixedfonts[0];
	print DEBUG "--font number specified:  font:=$fixedfont=\n"  if ($debug);
}
elsif (defined($font)) #USER-SELECTED FONT.
{
	print DEBUG "-font is defined =$font=\n"  if ($debug);
	if ($font =~ /^\d+$/o)
	{
		$fixedfont = $fixedfonts[$font] || $fixedfonts[0];
	}
	else
	{
		for (my $i=0;$i<=$#fontnames;$i++)
		{
			print DEBUG "--matching font: names[$i]=$fontnames[$i]=\n"  if ($debug);
			if ($fontnames[$i] =~ /^$font/)
			{
				$fixedfont = $fixedfonts[$i];
				last;
			}
		}
		$fixedfont = $font  unless ($fixedfont);
		$fixedfont = $fixedfonts[0]  unless ($fixedfont =~ /^(?:\-.+|\w+)$/);
	}
}
else                   #NORMAL FONT.
{
	$fixedfont = $fixedfonts[0];
	print DEBUG "--FONT:=$fixedfont=\n"  if ($debug);
}

#$dontaskagain = 1  unless ($ask);
$MainWin = MainWindow->new;
#$MainWin->geometry("+1+1");
$MainWin->title($titleHeader);
my $CORNER = __PACKAGE__ . "::corner";
my $bits = pack("b15"x15,
		"...............",
		".#############.",
		".############..",
		".###########...",
		".##########....",
		".#########.....",
		".########......",
		".#######.......",
		".######........",
		".#####.........",
		".####..........",
		".###...........",
		".##............",
		".#.............",
		"...............",


);
$MainWin->DefineBitmap($CORNER => 15,15, $bits);

my $ebackupFid;
#print DEBUG "-???- local=${homedir}.ebackups= pgm=${pgmhome}ebackups=\n"  if ($debug);
$ebackupFid = "${homedir}.ebackups"  if (-f "${homedir}.ebackups" && -w "${homedir}.ebackups");
$ebackupFid ||= "${pgmhome}ebackups"  if (-f "${pgmhome}ebackups" && -w "${pgmhome}ebackups");

$c = $palette  if ($palette);
my $fgisblack;
$fgisblack = 1  if ($fg =~ /black/io); #KLUDGE SINCE SETPALETTE/SUPERTEXT BROKE!

$bgOrg = $bg;
$fgOrg = $fg;
my $csrFG = 'black';
if ($c)
{
	unless ($c eq 'none')
	{
		if ($c =~ /default/io)  #ADDED 20040827 TO ALL TEXT COLOR TO CHG W/O CHANGING PALETTE.
		{
			eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
			my $c0;
			$c0 = $MainWin->optionGet('tkVpalette','*')  if ($v);
			$c0 ||= $MainWin->optionGet('tkPalette','*');
			$c = $c0  if ($c0);
		}
		if ($c)
		{
			$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c);
		}
		unless ($fg)
		{
			if ($palette)
			{
				$fg = 'green';
			}
			else
			{
				$fg = $MainWin->cget('-foreground');
			}
		}
		#$bg = $MainWin->cget('-background')  unless ($bg);
		unless ($bg)
		{
			if ($palette)
			{
				$bg = 'black';
			}
			else
			{
				$bg = $MainWin->cget('-background');
			}
		}
	}
}
else
{
	if ($bummer)
	{
		if (open (T, ".Xdefaults") || open (T, "$ENV{'HOME'}/.Xdefaults")
			|| open (T, "${pgmhome}Xdefaults") || open (T, "/etc/Xdefaults"))
		{
			while (<T>)
			{
				chomp;
				if ($v && /tkVpalette\s*\=\s*\"([^\"]+)\"/o)
				{
					$c = $1;
					last;
				}
				if (/tkPalette\s*\=\s*\"([^\"]+)\"/o)
				{
					$c = $1;
					last;
				}
			}
			close T;
		}
	}
	else
	{
		eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
		$c = $MainWin->optionGet('tkVpalette','*')  if ($v);
		$c ||= $MainWin->optionGet('tkPalette','*');
	}
	if ($v)
	{
#		$c ||= 'bisque3';
		if ($c)
		{
			$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c)
		}
	}
	else
	{
		$fg = 'green'  unless ($fg);
		$bg = 'black'  unless ($bg);
		if ($c)
		{
			$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c)	
		}
	}
}
my ($textwidget) = 'TextUndo';
$textwidget = 'SuperText'  if ($SuperText);
$textwidget = $editor  if ($editor);
my $PlusN65pixmap = 0;
my $MinusN65pixmap = 0;

if ($v)
{
#print DEBUG "-???- have=$haveXML=\n"  if ($debug);
	$viewer = 'XMLViewer'  if ($haveXML && $0 !~ /vc\w*\.(?:exe|pl)$/io && $ARGV[0] =~ /\.(?:xml|xsd|xsl)$/io);
	if (!$bummer && $viewer eq 'XMLViewer') {
		$PlusN65pixmap = $MainWin->Getimage('plusN65')  if (Tk->findINC('plusN65.gif'));
		$MinusN65pixmap = $MainWin->Getimage('minusN65')  if (Tk->findINC('minusN65.gif'));
	}
	$textwidget = $viewer;
	unless ($textwidget)
	{
		$textwidget = 'ROText';
		$textwidget = 'ROTextANSIColor'  if ($AnsiColor && !$noac);
		$textwidget = 'ROSuperText'  if ($SuperText);
	}
	$SuperText = 0  if ($viewer && $viewer !~ /supertext/io);
	$AnsiColor = 0  unless ($textwidget =~ /^(?:ROSuperText|ROTextANSIColor)$/o);
}
else
{
	$SuperText = 0  if ($editor && $editor !~ /supertext/io);
	$AnsiColor = 0  unless ($textwidget =~ /^(?:SuperText|TextANSIColor)$/o);
}
my ($mytextrelief) = 'sunken';
$mytextrelief = 'groove'  if ($v);
$bottomFrame = $MainWin->Frame;
	
$wrap = 'none'  unless (defined($wrap));
$tagcnt = 0;

my $newsupertext;
#my @tabb;

&newTabFn();


#$textColorer = $MainWin->ColorEditor(-title => 'Select your favorite colors!');
#		unless ($bummer);

$w_menu = $MainWin->Frame(
		-relief => 'raised',
		-borderwidth => 0);
@menuOps = (
		-highlightthickness => 1,
		-takefocus => 1,
		-padx => 4,
		-pady => 1
);
@menuPackOps = (-ipady => 1, -side => 'left', -expand => 'no');
$w_menu->pack(-fill => 'x');
		
my $fileMenubtn = $w_menu->Menubutton(
		-text => 'File',
		-underline => 0, 
#		-highlightcolor => $fg,
#		-activeforeground => 'white',
		@menuOps
);
$fileMenubtn->command(
		-label => 'New',
		-underline => 0,
		-command => \&newFn);
unless ($nobrowsetabs)
{
	$fileMenubtn->command(
			-label => 'Open In Tab',
			-underline => 5,
			-command => \&openTabFn);
	$fileMenubtn->command(
			-label => 'New Tab',
			-underline => 4,
			-command => [\&newTabFn, 1]);
	$fileMenubtn->command(
			-label => 'Delete Tab',
			-underline => 0,
			-command => \&deleteTabFn);
}
$fileMenubtn->command(
		-label => 'Open',
		-underline => 0,
		-command => \&openFn);
$fileMenubtn->command(
		-label => 'Save',
		-underline => 0,
		-command => \&saveFn);
$fileMenubtn->command(
		-label => ($v ? 'Save Marks/Tags' : 'Save w/Marks'),
		-underline => ($v ? 5 : 7),
		-command => sub { 
			if ($v)
			{
				&saveTags($cmdfile{$activeTab}[$activeWindow]);
				&saveMarks($cmdfile{$activeTab}[$activeWindow], $activeWindow);
			}
			else
			{
				&saveFn(3);
			}
		});
$fileMenubtn->command(
		-label => 'Print',
		-underline =>0,
		-command => \&printFn);
$fileMenubtn->command(
		-label => 'Save As',
		-underline =>5,
		-command => [\&saveasFn, 1]);
$fileMenubtn->command(
		-label => 'Back up',
		-underline =>0,
		-command => [\&backupFn]);
$fileMenubtn->command(
		-label => 'Back up (/tmp)',
		-command => [\&SaveOnDestroy, 'U', 0]);
$fileMenubtn->command(
		-label => 'Back up (/tmp/#)',
		-command => [\&SaveOnDestroy, 'U', 1]);
$fileMenubtn->command(
		-label => 'Last back up',
		-underline =>0,
		-command => [\&showbkupFn]);
$fileMenubtn->command(
		-label => 'Split screen',
		-command => [\&splitScreen, 1]);
$fileMenubtn->command(
		-label => 'Single screen',
		-command => [\&splitScreen],
		-state => 'disabled');
$fileMenubtn->command(
		-label => $nb ? 'Turn on backup' : 'Turn OFF backup',
		-command => [\&toggleNB]);
$fileMenubtn->command(
		-label => 'use Perl',
		-underline =>0,
		-command => [\&resetFileType, 0]);
$fileMenubtn->command(
		-label => 'use HTML',
		-underline =>4,
		-command => [\&resetFileType, 2]);
$fileMenubtn->command(
		-label => 'use C',
		-underline =>4,
		-command => [\&resetFileType, 1]);
$scrnCnts{''} = 1;
$fileMenubtn->separator;
if ($v)
{
	$fileMenubtn->command(
			-label => 'Edit w/E',
			-underline =>0,
			-command => [\&switchPgm, 1],
	);
}
else
{
	$fileMenubtn->command(
			-label => 'View w/V',
			-underline =>0,
			-command => [\&switchPgm, 0]
	);
}
$fileMenubtn->command(
		-label => 'Exit',
		-underline =>1,
		-command => [\&exitFn]);

$fileMenubtn->pack(@menuPackOps);


$editMenubtn = $w_menu->Menubutton(
		-text => 'Edit',
		-underline => 0,
		@menuOps
);
$editMenubtn->command(
		-label => 'Goto',
		-accelerator => 'Alt-g',
		-underline =>0,
		-command => [\&doGoto]);
$editMenubtn->separator;
$editMenubtn->command(
		-label => 'Copy',
		-underline =>0,
		-command => [\&doMyCopy]);
$editMenubtn->command(
		-label => 'cuT',
		-underline =>2,
		-command => [\&doCut]);
$editMenubtn->command(
		-label => 'Paste (Clipboard)',
		-underline =>0,
		-command => [\&doPaste,'CLIPBOARD']);
$editMenubtn->command(-label => 'Paste (Primary)', -underline =>13, -command => [\&doPaste,'PRIMARY']);
$editMenubtn->separator;
$editMenubtn->command(-label => 'Colors',   -underline =>1, -command => [\&doColorEditor]);
#		unless ($bummer);
$editMenubtn->command(-label => 'Insert file',   -underline =>0, -command => [\&appendfile]);
$editMenubtn->command(-label => 'Edit This',   -underline =>1, -command => [\&editfile])
		if ($v);
$editMenubtn->command(-label => 'Undo',
		-underline =>0,
		-accelerator => 'Alt-u',
		-command => sub {
				eval { $whichTextWidget->tagDelete('savesel'); };
				eval { $whichTextWidget->tagAdd('savesel', 'sel.first', 'sel.last'); };
				$textScrolled[$activeWindow]->undo;
				eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
		}
);
$editMenubtn->command(-label => 'Redo',
		-underline => 2,
		-accelerator => 'Alt-r',
		-command => sub {
				eval { $whichTextWidget->tagDelete('savesel'); };
				eval { $whichTextWidget->tagAdd('savesel', 'sel.first', 'sel.last'); };
				$textScrolled[$activeWindow]->redo;
				eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
		}
);
$editMenubtn->entryconfigure('Undo', -state => 'disabled')
		unless ($text1Text->can('undo'));
$editMenubtn->entryconfigure('Redo', -state => 'disabled')
		unless ($text1Text->can('redo'));

$editMenubtn->command(-label => 'Left-indent', -underline => 0, -command => [\&doIndent,0,1]);
$editMenubtn->command(-label => 'Right-indent', -underline => 0, -command => [\&doIndent,1,1]);
$editMenubtn->command(-label => 'Lower-case', -command => [\&setcase,1]);
$editMenubtn->command(-label => 'Upper-case', -command => [\&setcase,0]);
$editMenubtn->command(-label => 'chr2heX', -underline => 6, -command => [\&cnvert,1]);
$editMenubtn->command(-label => 'Hex2chr', -underline => 0, -command => [\&cnvert,0]);
$editMenubtn->command(-label => 'RxEscape', -command => [\&cnvert,2]);
$editMenubtn->command(-label => 'RxUnEscape', -command => [\&cnvert,3]);
$editMenubtn->command(-label => 'Unescape u00##', -command => [\&cnvert,4]);
$editMenubtn->command(-label => 'Length', -underline => 2, -command => [\&showlength]);
$editMenubtn->command(-label => 'Save Selected', -underline => 0, -command => [\&saveSelected]);
$editMenubtn->command(-label => 'Show Filename', -underline => 5, -command => [\&showFileName]);
$editMenubtn->command(-label => 'suM', -underline => 2, -command => [\&showSum]);
$editMenubtn->command(-label => 'Time', -command => [\&showTime]);
$editMenubtn->command(-label => 'Wrap word', -underline => 0, -command => [\&setwrap,'word']);
$editMenubtn->command(-label => 'Wrap char', -command => [\&setwrap,'char']);
$editMenubtn->command(-label => 'Wrap none', -command => [\&setwrap,'none']);
$editMenubtn->command(-label => 'Reverse', -command => [\&reverseit]);
#$editMenubtn->command(-label => 'Chg. Tabs', -command => [\&chgtabs]);
$editMenubtn->pack(@menuPackOps);

my $findMenubtn = $w_menu->Menubutton(
		-text => 'Search',
		-underline => 0,
		@menuOps
);
$findMenubtn->command(-label => 'Search Again', -underline =>7, -command => [\&doSearch,0]);
$findMenubtn->command(-label => 'Search Forward >', -underline => 7, -command => [\&doSearch,0,1]);
$findMenubtn->command(-label => 'Search Backward <', -underline => 7, -command => [\&doSearch,0,0]);
$findMenubtn->separator;
$findMenubtn->command(-label => 'Modify search',   -underline =>0, -command => [\&newSearch,0]);
$findMenubtn->command(-label => 'New search',   -underline =>0, -command => [\&newSearch,1]);
$findMenubtn->command(-label => 'Clear Highlights',   -underline =>0, -command => [\&clearSearch]);
$findMenubtn->pack(@menuPackOps);

$markMenubtn = $w_menu->Menubutton(
		-text => 'Marks',
		-underline => 3,
		@menuOps
);
$markMenubtn->pack(@menuPackOps);
$markMenubtn->command(
		-label => 'Clear Marks',
		-underline => 0,
		-command => \&clearMarks);
$markMenubtn->command(
		-label => 'New Mark',
		-underline => 0,
		-command => \&addMark);

my (%markNextIndex);

$fontMenubtn = $w_menu->Menubutton(
		-text => 'Fonts', 
		@menuOps
);
$fontMenubtn->pack(@menuPackOps);
for (my $i=0;$i<=$#fontnames;$i++)
{
	$fontMenubtn->command(-label => $fontnames[$i], -underline =>0, -command => [\&setFont,$i]);
}

%themeHash = ();
@tagTypeIndex = ('', 'all', 'ul', 'bd', 'fgblack', 'fgred', 'fggreen', 'fgyellow', 'fgblue', 
	'fgmagenta', 'fgcyan', 'fgwhite', 'bgred', 'bggreen', 'bgyellow', 'bgblue', 
	'bgmagenta', 'bgcyan', 'bgwhite');

if (open (T, "${cwd}.myethemes") || open (T, "${homedir}.myethemes")
		|| open (T, "${pgmhome}myethemes"))
{
	$themeMenuBtn = $w_menu->Menubutton(
			-text => 'Themes',
			-direction => 'right',  #MENU USUALLY TOO TALL, AVOID POPOVER!
			@menuOps
	);
	$themeMenuBtn->pack(@menuPackOps);
	my ($themename, $themecode);
	while (<T>)
	{
		chomp;
		($themename, $themecode) = split(/\:/o);
		$themeHash{$themename} = $themecode;
		eval "\$themeMenuBtn->command(-label => '$themename', -command => sub {&setTheme('$themecode');});";
	}
	close T;
}
	$tagMenubtn = $w_menu->Menubutton(
			-text => 'Tags',
			@menuOps
	);
	$tagMenubtn->configure(-state => 'disabled')  unless ($newsupertext || $AnsiColor); #ADDED 20010131

	$tagMenubtn->pack(@menuPackOps);
	$tagMenubtn->command(-label => 'Clear', -underline =>2, -command => [\&setTag,'clear']);
	$tagMenubtn->command(-label => 'Underline', -underline =>0, -command => [\&setTag,'ul']);
	$tagMenubtn->command(-label => 'Bold', -underline =>0, -command => [\&setTag,'bd']);
	$tagMenubtn->command(-label => 'Black', -underline =>4, -command => [\&setTag,'fgblack']);
	$tagMenubtn->command(-label => 'Red', -underline =>0, -command => [\&setTag,'fgred']);
	$tagMenubtn->command(-label => 'Green', -underline =>0, -command => [\&setTag,'fggreen']);
	$tagMenubtn->command(-label => 'Yellow', -underline =>0, -command => [\&setTag,'fgyellow']);
	$tagMenubtn->command(-label => 'Blue', -underline =>0, -command => [\&setTag,'fgblue']);
	$tagMenubtn->command(-label => 'Magenta', -underline =>0, -command => [\&setTag,'fgmagenta']);
	$tagMenubtn->command(-label => 'Cyan', -underline =>0, -command => [\&setTag,'fgcyan']);
	$tagMenubtn->command(-label => 'White', -underline =>0, -command => [\&setTag,'fgwhite']);
	$tagMenubtn->command(-label => 'Bkgd Red', -command => [\&setTag,'bgred']);
	$tagMenubtn->command(-label => 'Bkgd Green', -command => [\&setTag,'bggreen']);
	$tagMenubtn->command(-label => 'Bkgd Yellow', -command => [\&setTag,'bgyellow']);
	$tagMenubtn->command(-label => 'Bkgd Blue', -command => [\&setTag,'bgblue']);
	$tagMenubtn->command(-label => 'Bkgd Magenta', -command => [\&setTag,'bgmagenta']);
	$tagMenubtn->command(-label => 'Bkgd Cyan', -command => [\&setTag,'bgcyan']);
	$tagMenubtn->command(-label => 'Bkgd White', -command => [\&setTag,'bgwhite']);
	$tagMenubtn->command(-label => 'Save As', -command => [\&saveasFn, 2]);

if ($v)
{
	$fnMenubtn = $w_menu->Menubutton(
			-text => 'Fun',
			-borderwidth => 0,
			-state => 'disabled');
	$fnMenubtn->pack(@menuPackOps);

}
else
{
	$fnMenubtn = $w_menu->Menubutton(
			-text => 'Fun',
			-underline => 1,
			@menuOps
	);
	$fnMenubtn->pack(@menuPackOps);
	for (my $i=1;$i<=12;$i++)
	{
		if (defined($fnkeyText[$i]) && length($fnkeyText[$i]) > 0)
		{
			$fnMenubtn->command(-label => ("F$i: \"".substr($fnkeyText[$i],0,20).'"'), -underline => 1, -command => [\&doGetFnKey, $i]);
		}
		else
		{
			$fnMenubtn->command(-label => "F$i: <undef>", -underline => 1, -command => [\&doGetFnKey, $i]);
		}
	}
	$fnMenubtn->separator;
	$fnMenubtn->command(-label => "Clear", -underline => 0, -command => [\&doClearFnKeys]);
	$fnMenubtn->command(-label => "Load",  -underline => 0, -command => [\&doLoadFnKeys]);
	$fnMenubtn->command(-label => "Save",  -underline => 0, -command => [\&doSaveFnKeys]);
}

$MainWin->title("$titleHeader, ${editmode}ing:  --untitled--");
my $clipboardWidget = $MainWin->Text();   #THIS WIDGET IS HIDDEN - USED TO KEEP PRIMARY SELECTION ACTIVE FOR INVOKE.PL & FRIENDS!

$text1Frame->pack(
		-side		=> 'left',
		-expand	=> 'yes',
		-fill   => 'both',
		-padx   => 2,
		-pady   => 1)  if ($nobrowsetabs);

$tabbedFrame->pack(
		-side		=> 'left',
		-expand	=> 'yes',
		-fill   => 'both',
		-padx   => 2,
		-pady   => 1)  unless ($nobrowsetabs);

if ($nobrowsetabs)
{
	$text1Frame->packPropagate('1');
	$textScrolled[0]->packPropagate('1');
	$textScrolled[1]->packPropagate('1');
	$textScrolled[0]->pack(
			-side   => 'bottom',
			-expand => 'yes',
			-fill   => 'both');

	$textScrolled[1]->pack(
			-side   => 'bottom',
			-expand => 'yes',
			-fill   => 'both');

	$textAdjuster->packForget();
#$textScrolled[1]->packConfigure(-side => 'bottom', -expand => 'yes', -fill => 'both');
	$textScrolled[1]->packForget();

	if ($bummer && $w32dnd)
	{
		$textScrolled[0]->DropSite(-dropcommand => [\&accept_drop, $textScrolled[0]],
			               -droptypes => 'Win32');
	}

#	$textColorer->configure(
#			-widgets=> [$text1Text, $textScrolled[$activeWindow]->Descendants])  unless ($bummer);
}

my ($mFrame, @btnOps, @btnPackOps);
$mFrame = $w_menu;
@btnOps = (-padx => 5, -pady => 1, -borderwidth => 0);
@btnPackOps = (-side => 'left', -expand => 'no', -ipady => 2);
$statusLabel = $MainWin->Label(
		-justify=> 'left',
		-relief	=> 'groove',
		-borderwidth => 2,
		-text		=> 'Status Label');
$statusLabel->pack(-side => 'bottom',
		-fill	=> 'x',
		-padx	=> 2,
		-pady	=> 1);

$openButton = $mFrame->Button(
		-text => 'Open',
		-underline =>0,
		@btnOps,
		-command => \&openFn);
$openButton->pack(@btnPackOps);

$findButton = $mFrame->Button(
		-text => 'Find',
		-underline => 2,
		@btnOps,
		-command => [\&newSearch,1]);
$findButton->pack(@btnPackOps);
$bkagainButton = $mFrame->Button(
		-text => '<',
	#-underline => 0,  #CAN'T DO, BUT SEE "<Alt-less>" BINDING!
		@btnOps,
		-command => [\&doSearch,0,0]);
$bkagainButton->pack(@btnPackOps);
$againButton = $mFrame->Button(
		-text => '>',
	#-underline => 0,  #CAN'T DO, BUT SEE "<Alt-greater>" BINDING!
		@btnOps,
		-command => [\&doSearch,0,1]);
$againButton->pack(@btnPackOps);
$gotoButton = $mFrame->Button(
		-text => 'Goto',
		-underline => 0,
		@btnOps,
		-command => [\&doGoto]);
$gotoButton->pack(@btnPackOps);
$cutButton = $mFrame->Button(
		-text => 'Cut',
		-underline => 2,
		@btnOps,
		-command => [\&doCut]);
$cutButton->pack(@btnPackOps);
$copyButton = $mFrame->Button(
		-text => 'Copy',
		-underline => 0,
		@btnOps,
		-command => [\&doMyCopy]);
$copyButton->pack(@btnPackOps);
$pasteButton = $mFrame->Button(
		-text => 'Paste(V)',
		-underline => 6,
		@btnOps,
		-command => [\&doPaste]);
$pasteButton->pack(@btnPackOps);
$markButton = $mFrame->Button(
		-text => 'Mark',
		-underline => 0,
		@btnOps,
		-command => [\&addMark]);
$markButton->pack(@btnPackOps);

unless ($nobrowsetabs)
{
	$openButton = $mFrame->Button(
			-text => '+Tab',
			-underline => 2,
			@btnOps,
			-command => \&openTabFn);
	$openButton->pack(@btnPackOps);
}

$opsys = ($bummer) ? 'DOS' : 'Unix';
$opsysList{''}[0] = $opsys;
$opsysList{''}[1] = $opsys;

$asdosButton = $mFrame->JBrowseEntry(
		-label => '',
		-state => 'readonly',
		-textvariable => \$opsys,
		-choices => [qw(DOS Unix Mac)],
		-listrelief => 'flat',
		-relief => 'sunken',
		-takefocus => 1,
		-browse => 1,
		-browsecmd => sub { $opsysList{$activeTab}[$activeWindow] = $opsys },
		-noselecttext => 1);
$asdosButton->pack(
		-side   => 'left',
		-pady   => 0,
		-ipady  => 0);

$saveButton = $mFrame->Button(
		-text => 'Save',
		@btnOps,
		-command => [\&saveFn]);
$saveButton->pack(@btnPackOps);

$exitButton = $mFrame->Button(
 		-text => 'Quit',
 		-underline => 0,
 		@btnOps,
 		-command => [\&exitFn]);
$exitButton->pack(@btnPackOps);

#t $savexButton = $mFrame->Button(
#t 		-text => 'Exit',
#t 		-underline => 1,
#t 		@btnOps,
#t 		-command => [\&savexFn]);
#t $savexButton->pack(@btnPackOps);

$bottomFrame->pack(
		-side => 'bottom',
		-fill	=> 'both',
		-expand	=> 'yes');

$findMenubtn->entryconfigure('Search Again', -state => 'disabled');
$findMenubtn->entryconfigure('Search Forward >', -state => 'disabled');
$findMenubtn->entryconfigure('Search Backward <', -state => 'disabled');
$findMenubtn->entryconfigure('Modify search', -state => 'disabled');

$againButton->configure(-state => 'disabled');
$bkagainButton->configure(-state => 'disabled');

&setTheme($themeHash{$theme})  if ($theme && defined $themeHash{$theme});
if ($bgOrg)   #USER SPECIFIED BOTH -theme AND -bg!
{
	$bg = $bgOrg;
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-background => $bg);
}
if ($fgOrg)
{
	$fg = $fgOrg;
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-foreground => $fg);
}

($Yes,$No,$Cancel,$Append) = ('~Yes','~No','~Cancel','~Append');
$yncDialog = $MainWin->JDialog(
		-title          => 'Unsaved Changes!!',
		-text           => "Do you wish to save changes?",
		-bitmap         => 'questhead',
		-default_button => $Yes,
		-escape_button		=> $Cancel,
		-buttons        => [$Yes,$No,$Cancel],
);

$saveDialog = $MainWin->JDialog(
		-title          => 'Unsaved Changes!!',
		-text           => "Do you wish to save changes?",
		-bitmap         => 'questhead',
		-default_button => $Yes,
		-escape_button		=> $Cancel,
		-buttons        => [$Yes,$No,$Append,$Cancel],
);

$replDialog = $MainWin->JDialog(
		-title          => 'Search/Replace',
		-text           => "Replace?",
		-bitmap         => 'questhead',
		-default_button => $Yes,
		-escape_button  => $No,
		-buttons        => [$Yes,$No],
);

($OK) = ('~Ok');
$errDialog = $MainWin->JDialog(
		-title          => '-ERROR!-',
		-bitmap         => 'error',
		-buttons        => [$OK],
);

if (!defined($tabs) && $ARGV[0])
{
	$ARGV[0] =~ s/^file://o;  #HANDLE KFM DRAG&DROP!
	$ARGV[0] =~ s#\\#/#go  if ($bummer);    #FIX Windoze FILENAMES!

	#HANDLE FILENAMES W/ :line# APPENDED (STRIP & GOTO THAT POSN IN FILE):
	my $posn = (!(-e $ARGV[0]) && $ARGV[0] =~ s/([^\\])\:([\d\.]+)$/$1/) ? $2 : $l;
	$activeWindow = 0;
	if (&fetchdata($ARGV[0]))
	{
		$cmdfile{''}[0] = $ARGV[0];
		my $cmdfid = '';
		$cmdfid = &cwd()  unless ($cmdfile{''}[0] =~ m#^(?:\/|\w\:)#o );
		if ($cmdfid)
		{
			$cmdfid .= '/'  unless ($cmdfid =~ m#\/$#o);
		}
		$cmdfid .= $cmdfile{''}[0];
		$cmdfid =~ s#^\.\/#&cwd."\/"#e;
		$cmdfid =~ s!^(\~\w*)!
			my $one = $1 || $ENV{'USER'};
			my $t = `ls -d $one`;
			chomp($t);
			$t;
		!e;
		$startpath = $cmdfid;
		$startpath =~ s#[^\/]+$##o;
		my @histlist = ("$cmdfid\n");
		if (open(T, $histFile))
		{
			while (<T>)
			{
				push (@histlist, $_);
			}
			close T;
		}
		if (open(T, ">$histFile"))
		{
			print T shift(@histlist);
			while (@histlist)
			{
				$_ = shift(@histlist);
				print T $_   unless ($_ eq "$cmdfid\n");
			}
			close T;
		}
		(my $filePart = $cmdfile{''}[0]) =~ s#^.*\/([^\/]+)$#$1#;
		$tabbedFrame->pageconfigure($activeTab, -label => $filePart)  unless ($nobrowsetabs);
#		$activeWindow = 1;
		&gotoMark($textScrolled[$activeWindow], (defined($posn) ? $posn : '_Bookmark'), 'append');
		if ($ARGV[1])   #IF 2ND FILE SPECIFIED, SPLIT SCREEN & OPEN IN BOTTOM.
		{
			my $posn = (!(-e $ARGV[1]) && $ARGV[1] =~ s/([^\\])\:([\d\.]+)$/$1/) ? $2 : $l;
			$cmdfile{''}[1] = $ARGV[1];
			&splitScreen();
			$textScrolled[1]->focus();
#print DEBUG "-???- setting focus to 1!\n"  if ($debug);
			$activeWindow = 1;
			$whichTextWidget = $textScrolled[1]->Subwidget($textsubwidget); #  unless (defined $focus);
			if (&fetchdata($ARGV[1]))
			{
				my $cmdfid = '';
				my $cmdfid = &cwd()  unless ($cmdfile{''}[1] =~ m#^(?:\/|\w\:)#o );
				if ($cmdfid)
				{
					$cmdfid .= '/'  unless ($cmdfid =~ m#\/$#o);
				}
				$cmdfid .= $cmdfile{''}[1];
				$cmdfid =~ s#^\.\/#&cwd."\/"#e;
				$cmdfid =~ s!^(\~\w*)!
					my $one = $1 || $ENV{'USER'};
					my $t = `ls -d $one`;
					chomp($t);
					$t;
				!e;
				$startpath = $cmdfid;
				$startpath =~ s#[^\/]+$##o;
				my @histlist = ("$cmdfid\n");
				if (open(T, $histFile))
				{
					while (<T>)
					{
						push (@histlist, $_);
					}
					close T;
				}
				if (open(T, ">$histFile"))
				{
					print T shift(@histlist);
					while (@histlist)
					{
						$_ = shift(@histlist);
						print T $_   unless ($_ eq "$cmdfid\n");
					}
					close T;
				}
				&gotoMark($textScrolled[$activeWindow], (defined($posn) ? $posn : '_Bookmark'), 'append');
			}
		}
	}
	else    #ADDED 20040407 SO IF FILE ARGUMENT SPECIFIED DOES NOT EXIST, "SAVE" STILL "REMEMBERS" IT!
	{
		$cmdfile{''}[0] = $ARGV[0]  if ($ARGV[0]);
	}
#	$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{''}[$activeWindow]\"");   #GETS OVERWRITTEN ANYWAY :(
	$dontaskagain = 1  unless ($v || $ask);
}
elsif (!$n && !$new)
{
	my $clipboard;
	my $useSelection = ($bummer) ? 'CLIPBOARD' : 'PRIMARY';
	eval { $clipboard = $MainWin->SelectionGet(-selection => $useSelection); };
	if ($clipboard && $clipboard =~ /\S/)
	{
		$textScrolled[$activeWindow]->insert('end',$clipboard);
		$_ = "..Successfully opened Selected Text.";
		&setStatus( $_);
		$textScrolled[$activeWindow]->markSet('_prev','0.0');
		$textScrolled[$activeWindow]->markSet('insert','0.0');
	}
	#TITLE WILL GET OVERWRITTEN ANYWAY ON FOCUSIN!:
	$MainWin->title("${host}: E Perl/Tk Editor v$vsn, ${editmode}ing:  \"--SELECTED TEXT--\"");
	$cmdfile{''}[0] = '';
}

$filetype = 0;

if ($cmdfile{''}[0] =~ /\.c$/io || $cmdfile{''}[0] =~ /\.h$/io || $cmdfile{''}[0] =~ /\.cpp$/io)
{
	#eval {require 'e_c.pl';};  #EVAL DOESN'T WORK HERE IN COMPILED VSN.
	require 'e_c.pl';
	$filetype = 1;
}
elsif ($cmdfile{''}[0] =~ /\..*ht[a-z]+/io)
{
	#eval {require 'e_htm.pl';};
	require 'e_htm.pl';
	$filetype = 2;
}
else
{
	#eval {require 'e_pl.pl';};
	require 'e_pl.pl';
}
$fileTypes{$filetype} = 1;

#!!$textScrolled[$activeWindow]->bind('<Alt-Key>',['Backspace','Insert']);
($text1Text,@textchildren) = $textScrolled[$activeWindow]->children;
$MainWin->bind('<Alt-b>' => [\&gotoMark, '_Bookmark']);
$MainWin->eventAdd(qw[<<PasteSelection>> <Alt-v>]);
$MainWin->bind('<Control-Tab>' => \&CtrlTabFn);

#SPECIAL CODE IF VIEWING ONLY!

if ($v)
{
	foreach my $n ('cuT', 'Paste (Clipboard)', 'Paste (Primary)',
			'Undo', 'Redo', 'Left-indent', 'Right-indent', 'Lower-case',
			'Upper-case', 'chr2heX', 'Hex2chr', 'RxEscape', 'RxUnEscape',
			'Unescape u00##', 'Insert file', 'Reverse')
	{
		$editMenubtn->entryconfigure($n, -state => 'disabled');
	}
	$fileMenubtn->entryconfigure('Save', -state => 'disabled');
	$asdosButton->configure(-state => 'disabled');
	$cutButton->configure(-state => 'disabled');
	$pasteButton->configure(-state => 'disabled');
	$saveButton->configure(-state => 'disabled');
#t	$savexButton->configure(-state => 'disabled');
	$MainWin->bind('<Escape>' => \&exitFn);
	#$MainWin->bind('<Alt-c>' => 'NoOp');
	#$MainWin->bind('<Alt-c>' => sub {&doCopy; shift->break;});  #NEEDED SINCE COLORS REBINDS 
	                                        #ALT-C TO IT'S MENUBUTTON (AFTER)
	                                        #OUR BUTTON AUTOBINDS ALT-C! :-(
	                                        #DOESN'T WORK :---(((
}

#NEXT 4 ADDED 20031107 FOR IMWHEEL.
$MainWin->bind('<Alt-Left>' => sub { 
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->xview('scroll', -1, 'units');
});
$MainWin->bind('<Alt-Right>' => sub { 
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->xview('scroll', +1, 'units');
});
$MainWin->bind('<Alt-Up>' => sub { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->yview('scroll', -1, 'units') });
$MainWin->bind('<Alt-Down>' => sub { $textScrolled[$activeWindow]->Subwidget($textsubwidget)->yview('scroll', +1, 'units') });
$MainWin->bind('<Alt-less>' => [\&doSearch,0,0]);
$MainWin->bind('<Alt-greater>' => [\&doSearch,0,1]);

if (defined($tabs) & $haveNotebook)
{
print DEBUG "--TABS-- args=".join('|',@ARGV)."=\n"  if ($debug);
	$nextTab = '1';
	my $f;
	my $subsequent = 0;
	while (@ARGV)
	{
		$f = shift(@ARGV);
		last  unless ($f && $f =~ /\w/o);

		if ($subsequent) {
			&newTabFn();
		} else {
			$nextTab = '2';
		}
		my ($topfid, $bottomfid) = split(/\:/o, $f);
		$activeWindow = 0;
print DEBUG "-----topfid=$topfid= bottom=$bottomfid=\n"  if ($debug);
		&openFn($topfid);
		if ($bottomfid)
		{
			&splitScreen();
			$textScrolled[1]->focus();
			$activeWindow = 1;
			&openFn($bottomfid);
		}
		++$subsequent;
	}
}
elsif (defined $tab1 && !($nobrowsetabs))
{
	my $tabX;
	my $i = 1;
	while (1)
	{
		$tabX = '';
		eval "\$tabX = \$tab$i  if (defined \$tab$i)";
		last  unless ($tabX);
		my ($topfid, $bottomfid) = split(/\:/o, $tabX);
#print DEBUG "--top=$topfid= bottom=$bottomfid=\n";
		&newTabFn();
		$activeWindow = 0;
		&openFn($topfid);
		if ($bottomfid)
		{
			&splitScreen();
			$textScrolled[1]->focus();
			$activeWindow = 1;
			&openFn($bottomfid);
		}
		++$i;
	}
}

#print DEBUG "-???1- focus=$focus= aw=$activeWindow= fns=$focusNotSet\n"  if ($debug);
unless ($focusNotSet)
{
	$activeWindow = ($focus == 1) ? 1 : 0;
}
####????$textScrolled[1]->Subwidget($textsubwidget)->focus();
#print DEBUG "-???2- focus=$focus= aw=$activeWindow=\n"  if ($debug);
if ($nobrowsetabs)
{
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
}
else
{
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	$tabbedFrame->raise($focustab)  if ($focustab);
}
$activeWindows{$activeTab} = $activeWindow;
#DEPRECIATED:&gotoMark($textScrolled[$activeWindow],$l)  if ($l);
if ($s)
{
	push (@srchTextChoices, $s);
	$srchOptChoices{$s} = '-nocase';
	$replTextChoices{$s} = '';
	&doSearch(2);
}

#JWT:FOR SOME UNKNOWN REASON, WE HAVE TO ALSO FORCE THESE TO BE TRANSIENT HERE?!:
$yncDialog->transient($MainWin);
$saveDialog->transient($MainWin);
$replDialog->transient($MainWin);
$errDialog->transient($MainWin);

#MainLoop;
while (Tk::MainWindow->Count)
{
	if ($childpid)
	{
		if ($childpid)
		{
			@children = `ps ef|grep "$childpid"|grep -v "grep"`;
			$childstillrunning = 0;
			while (@children)
			{
				$_ = shift(@children);
				if (/^\D*(\d+)/o)
				{
					$childstillrunning = 1  if ($1 eq $childpid);
				}
			}
			unless ($childstillrunning)
			{
				#++$abortit;
				#$abortButton->configure(-text => 'Fetch Output');
				$abortButton->invoke  if (Exists($xpopup2) && $abortButton);
				$childpid = '';
			}
		}
		eval { $xpopup2->update  }  if (Exists($xpopup2));
	}
	DoOneEvent(ALL_EVENTS);
}

sub anyChanges
{
	my $tab = shift || $activeTab;
	my $window = shift || $activeWindow;
	return 0  if ($saveStatus{$tab}[$window] =~ /(?:essfully opened file\:|saved to file\:)/o);  #WE JUST OPENED, NO CHANGES!
	return 1  if (length($textScrolled[$window]->get('1.0','3.0')) > 1);  #WE HAVE DATA, (CHANGES)!
	return 0;  #WE HAVE NO DATA (EMPTY WINDOW - NO CHANGES)
}

sub newFn
{
	my ($usrres);
	$usrres = $No;
	unless ($v)
	{
		if (anyChanges($activeTab, $activeWindow))
		{
			$yncDialog->configure(
					-text => "Save any changes to $cmdfile{$activeTab}[$activeWindow]?");
			$usrres = $yncDialog->Show();		
			$cmdfile{$activeTab}[$activeWindow] ||= "$hometmp/e.out.tmp";
		}
	}
	$_ = '';
	$usrres = $Cancel x &writedata($cmdfile{$activeTab}[$activeWindow], 1)  if ($usrres eq $Yes);
	return  if ($usrres eq $Cancel);
	$cmdfile{$activeTab}[$activeWindow] = '';
	$textScrolled[$activeWindow]->delete('0.0','end');
	&clearMarks();
	$opsysList{$activeTab}[$activeWindow] = $bummer ? 'DOS' : 'Unix';
	$MainWin->title("$titleHeader, ${editmode}ing:  New File");
	unless ($activeWindow)
	{
		(my $numberPart = $activeTab) =~ s#\D##gs;
		$tabbedFrame->pageconfigure($activeTab, -label => "Tab $numberPart")  unless ($nobrowsetabs);
	}
}

sub openTabFn
{
	my $clipboard;
	my $useSelection = $bummer ? 'CLIPBOARD' : 'PRIMARY';
	eval { $clipboard = $MainWin->SelectionGet(-selection => $useSelection); };
	if ($clipboard)
	{
		my @files2open = split(/\r?\n/, $clipboard);
#print DEBUG "--OPEN TAB=$clipboard= sel=$useSelection=\n";
		while (@files2open)
		{
			&newTabFn();
			&openFn(shift @files2open);
		}
	}
	else
	{
		&newTabFn(1);  #Open new tab & ASK for fid to open.
	}
}

sub CtrlTabFn
{
	my $otherpane = $activeWindows{$activeTab};
	$otherpane = !$otherpane  if ($scrnCnts{$activeTab} == 2);
	$otherpane ||= 0;
	$activeWindows{$activeTab} = $otherpane;
	$currentWorkingDirPane{$activeTab} = $otherpane;
	$textScrolled[$otherpane]->focus;
	Tk->break;
}

sub newTabFn
{
	my $openDialog = shift || 0;

	local *jump2top = sub
	{
		$activeWindow = shift;
		$textScrolled[$activeWindow]->focus;
		$textScrolled[$activeWindow]->markSet('_prev','insert');
		$textScrolled[$activeWindow]->markSet('insert','0.0');
		$textScrolled[$activeWindow]->see($textScrolled[$activeWindow]->index('insert'));
		&setStatus("Cursor now at 0.0.");
	};

	$activeWindow = 0;
	if ($nobrowsetabs)
	{
		$text1Frame = $bottomFrame->Frame;
		$activeTab = '';
		$activeWindow = ($focus == 1) ? 1 : 0;
		$activeWindows{$activeTab} = $activeWindow;
	}
	else
	{
		#NOTE:  AS OF v5.03 WE NOW DEFAULT TO MORE GTK-ISH TAB-COLORS
		#(MORE CONSISTANT WITH GTK-3 THEMES, SUCH AS MY PerlTkTheme)!
		#TO USE THE MORE CLASSIC (PRE-v5.03) COLORS, SET THIS TO TRUE
		#IN e.ini:

		my $classicTabs = defined($classictabs) ? $classictabs : 1;
		$activeTab = "Tab$nextTab";
		$activeWindow = ($focus == 1 && $activeTab eq $focustab) ? 1 : 0;
		$activeWindows{$activeTab} = $activeWindow;
#		my $acbgColor = $MainWin->cget( -background );    #NEXT 2 MAKE TAB ROW SAME COLOR AS REST OF WINDOW:
		my $acbgColor = $MainWin->Palette->{ activeBackground } || 'gray30';    #NEXT 2 MAKE TAB ROW SAME COLOR AS REST OF WINDOW:
#TONE IT DOWN SLIGHTLY:		my $robgColor = $MainWin->Palette->{ readonlyBackground } || 'gray40';
		my $robgColor = $MainWin->Palette->{ disabledForeground } || 'gray40';
		my $bgColor = $MainWin->Palette->{ background };
		my $foColor = $MainWin->Palette->{ foreground };
#		$tabbedFrame = $bottomFrame->NoteBook(-tabpady => 0)  unless ($nextTab > 1);
		$tabbedFrame = $bottomFrame->NoteBook(
				-tabpady => 0,
				-background => $classicTabs ? $bgColor : $acbgColor,
				-inactivebackground => $classicTabs ? $robgColor : $bgColor,
				-backpagecolor => $acbgColor,
				-focuscolor => $foColor
		)  unless ($nextTab > 1);
#print DEBUG "-newTabFn: nextTab=$nextTab= tabbedFrame=$tabbedFrame=\n"  if ($debug);
#		$tabb[$nextTab] = $tabbedFrame->add( $activeTab, -label=> "Tab $nextTab", -raisecmd => [\&chgTabs, $nextTab]);
#		$text1Frame = $tabb[$nextTab];
		$text1Frame = $tabbedFrame->add( $activeTab, -label=> "Tab $nextTab", -raisecmd => [\&chgTabs, $nextTab]);
		++$nextTab;
	}
	if ($SuperText && !$noac && !$v)
	{
		$textsubwidget = $SuperText ? 'supertext' : 'textundo';
		$textScrolled[0] = $text1Frame->Scrolled($textwidget,
				-scrollbars => 'se', -ansicolor => 1);
		$textScrolled[0]->Subwidget('xscrollbar')->configure(-takefocus => 0);
		$textScrolled[0]->Subwidget('yscrollbar')->configure(-takefocus => 0);
		$textScrolled[0]->Subwidget('corner')->Button(
			-bitmap => $CORNER,
			-borderwidth => 1,
			-takefocus => 0,
			-command => [\&jump2top, 0],
		)->pack(-side => 'top', -padx => 0, -pady => 0, -anchor => 'se');
		$textAdjuster = $text1Frame->Adjuster();
		$textScrolled[1] = $text1Frame->Scrolled($textwidget,
				-scrollbars => 'se', -ansicolor => 1);
		$textScrolled[1]->Subwidget('xscrollbar')->configure(-takefocus => 0);
		$textScrolled[1]->Subwidget('yscrollbar')->configure(-takefocus => 0);
		$newsupertext = 1;
		$textScrolled[1]->Subwidget('corner')->Button(
			-bitmap => $CORNER,
			-borderwidth => 1,
			-takefocus => 0,
			-command => [\&jump2top, 1],
		)->pack(-side => 'top', -padx => 0, -pady => 0, -anchor => 'se');
	}
	unless ($newsupertext)
	{
		($textsubwidget = $textwidget) =~ tr/A-Z/a-z/;
		$textScrolled[0] = $text1Frame->Scrolled($textwidget,
				-scrollbars => 'se');
		$textScrolled[0]->Subwidget('xscrollbar')->configure(-takefocus => 0);
		$textScrolled[0]->Subwidget('yscrollbar')->configure(-takefocus => 0);
		$textScrolled[0]->Subwidget('corner')->Button(
			-bitmap => $CORNER,
			-borderwidth => 1,
			-takefocus => 0,
			-command => [\&jump2top, 0],
		)->pack(-side => 'top', -padx => 0, -pady => 0, -anchor => 'se');
		$textAdjuster = $text1Frame->Adjuster();
		$textScrolled[1] = $text1Frame->Scrolled($textwidget,
				-scrollbars => 'se');
		$textScrolled[1]->Subwidget('xscrollbar')->configure(-takefocus => 0);
		$textScrolled[1]->Subwidget('yscrollbar')->configure(-takefocus => 0);
		$textScrolled[1]->Subwidget('corner')->Button(
			-bitmap => $CORNER,
			-borderwidth => 1,
			-takefocus => 0,
			-command => [\&jump2top, 1],
		)->pack(-side => 'top', -padx => 0, -pady => 0, -anchor => 'se');
	}
	unless ($v || $nosod)
	{
print DEBUG "-tsw=$textsubwidget= tw=$textwidget= active=$activeTab= SAVE-ON-DESTROY SET!\n"  if ($debug);
		$textScrolled[0]->Subwidget($textsubwidget)->OnDestroy([\&SaveOnDestroy, 'X', 0, 0, $activeTab, $textScrolled[0]]);
		$textScrolled[1]->Subwidget($textsubwidget)->OnDestroy([\&SaveOnDestroy, 'X', 0, 1, $activeTab, $textScrolled[1]]);
	}
	$text1Hash{$activeTab}[0] = $textScrolled[0];
	$text1Hash{$activeTab}[1] = $textScrolled[1];
	$text1Hash{$activeTab}[2] = $textAdjuster;
#	$activeWindows{$activeTab} = 0;
	$scrnCnts{$activeTab} = $scrnCnt;
#print DEBUG "---new tab:  active=$activeTab= scr0=$textScrolled[0]= wheelmouse=$WheelMouse=\n"  if ($debug);
	Tk::Autoscroll::Init($textScrolled[0])  if ($autoScroll);
	&BindMouseWheel($textScrolled[0])  if ($WheelMouse);
	&BindMouseWheel($textScrolled[1])  if ($WheelMouse);

	if ($v)
	{
		$textsubwidget = ($AnsiColor && !$noac) ? 'rotextansicolor' : 'rotext';
		$textsubwidget = 'rosupertext'  if $SuperText;
		$textsubwidget = "\L$viewer\E"  if ($viewer);
#print DEBUG "-subwidget=$textsubwidget= viewer=$viewer= ST=$SuperText=\n"  if ($debug);
		$text1Text = $textScrolled[0]->Subwidget($textsubwidget);
		print DEBUG "--configured -font := ($fixedfont)\n"  if ($debug);
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-setgrid=> 1,
				-font	=> $fixedfont,
			#-font	=> '-*-lucida console-medium-r-normal-*-18-*-*-*-*-*-*-*',
				-tabs	=> ['1.35c','2.7c','4.05c'],
				-insertbackground => 'white',
				-relief => $mytextrelief,
				-wrap	=> $wrap,
				-height => $height,
				-width  => $width, %{$extraOptsHash{$textsubwidget}});
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-setgrid=> 1,
				-font	=> $fixedfont,
			#-font	=> '-*-lucida console-medium-r-normal-*-18-*-*-*-*-*-*-*',
				-tabs	=> ['1.35c','2.7c','4.05c'],
				-insertbackground => 'white',
				-relief => $mytextrelief,
				-wrap	=> $wrap,
				-height => $height,
				-width  => $width, %{$extraOptsHash{$textsubwidget}});

		if ($viewer eq 'XMLViewer') {  #MAKE LITTLE +/- SQUARES WHITE ON DARK BG. FOR XMLVIEWER ("NIGHT 65")!:
			my ($red, $green, $blue) = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->rgb(
				$textScrolled[$activeWindow]->Subwidget($textsubwidget)->cget('-background'));
#			my @rgb = sort {$b <=> $a} ($red, $green, $blue);
#			my $max = $rgb[0]+$rgb[1];  #TOTAL BRIGHTEST 2.
#			if ($max <= 52500)  #LOOKS GOOD FOR ME.
			my $max = $red+1.5*$green+0.5*$blue;
			if ($max <= $TwilightThreshold)
			{
print "--SETTING TO NIGHT IMAGES!\n"  if ($debug);
				$textScrolled[0]->Subwidget($textsubwidget)->{PlusImage} = $PlusN65pixmap  if ($PlusN65pixmap);
				$textScrolled[0]->Subwidget($textsubwidget)->{MinusImage} = $MinusN65pixmap  if ($MinusN65pixmap);
				$textScrolled[1]->Subwidget($textsubwidget)->{PlusImage} = $PlusN65pixmap  if ($PlusN65pixmap);
				$textScrolled[1]->Subwidget($textsubwidget)->{MinusImage} = $MinusN65pixmap  if ($MinusN65pixmap);
			}
		}
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-background => $bg)  if ($bg);
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/io));
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-background => $bg)  if ($bg);
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/io));
	}
	else
	{
		$textsubwidget = $SuperText ? 'supertext' : 'textundo';
		$textsubwidget = "\L$editor\E"  if ($editor);
		print DEBUG "-subwidget=$textsubwidget= viewer=$viewer= ST=$SuperText=\n"  if ($debug);
		$text1Text = $textScrolled[0]->Subwidget($textsubwidget);
		print DEBUG "--configured -font := ($fixedfont)\n"  if ($debug);
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-setgrid=> 1,
				-font	=> $fixedfont,
				-tabs	=> ['1.35c','2.7c','4.05c'],
				-insertbackground => 'white',
				-relief => $mytextrelief,
				-wrap	=> $wrap,
				-height => $height,
				-width  => $width, %{$extraOptsHash{$textsubwidget}});
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-setgrid=> 1,
				-font	=> $fixedfont,
				-tabs	=> ['1.35c','2.7c','4.05c'],
				-insertbackground => 'white',
				-relief => $mytextrelief,
				-wrap	=> $wrap,
				-height => $height,
				-width  => $width, %{$extraOptsHash{$textsubwidget}});
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-background => $bg)  if ($bg);
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/io));
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-background => $bg)  if ($bg);
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/io));
		#THIS KLUDGE NECESSARY BECAUSE DUAL-SPEED SETPALETTE BROKEN ON WINDOZE!
	}
	if ($haveTextHighlight && ($editor =~ /texthighlight/io || $viewer =~ /texthighlight/io))
	{
		my $sections;
		if ($haveKate)
		{
			($sections, $kateExtensions) = $textScrolled[0]->Subwidget($textsubwidget)->fetchKateInfo;
			$textScrolled[0]->Subwidget($textsubwidget)->addKate2ViewMenu($sections);
			$textScrolled[1]->Subwidget($textsubwidget)->addKate2ViewMenu($sections);
		}
		if (open(T, "${cwd}.myemimes") 
			|| open (T, "${homedir}.myemimes") || open (T, "${pgmhome}myemimes"))
		{
			my ($fext, $ft);

			while (<T>)
			{
				chomp;
				s/\#.*$//o;
				next  unless (/\S/o);
				($fext, $ft) = split(/\:/o, $_, 2);
				$mimeTypes{$fext} = $ft;
			}
			close T;
		}
	}

	$whichTextWidget = $textScrolled[0]->Subwidget($textsubwidget);
	unless ($nobrowsetabs)
	{
		$tabbedFrame->raise($activeTab);
		$r = $tabbedFrame->raised();
	}
$text1Frame->packPropagate('1');
$textScrolled[0]->packPropagate('1');
$textScrolled[1]->packPropagate('1');
$textScrolled[0]->pack(
		-side   => 'bottom',
		-expand => 'yes',
		-fill   => 'both');

$textScrolled[1]->pack(
		-side   => 'bottom',
		-expand => 'yes',
		-fill   => 'both');

$textAdjuster->packForget();
#$textScrolled[1]->packConfigure(-side => 'bottom', -expand => 'yes', -fill => 'both');
$textScrolled[1]->packForget();
if ($bummer && $w32dnd)
{
	$textScrolled[0]->DropSite(-dropcommand => [\&accept_drop, $textScrolled[0]],
		               -droptypes => 'Win32');
}

	$textScrolled[0]->bind('<FocusIn>' => sub {
			&textfocusin; $activeWindow = 0; $activeWindows{$activeTab} = 0;
			my $title = $cmdfile{$activeTab}[$activeWindow] || '--SELECTED TEXT--';
			$whichTextWidget = $textScrolled[0]->Subwidget($textsubwidget);
			$MainWin->title("$titleHeader, ${editmode}ing:  \"$title\"");
			$opsys = $opsysList{$activeTab}[$activeWindow];
			&resetMarks();
			$statusLabel->configure( -text => $saveStatus{$activeTab}[0]);
	});
	$textScrolled[1]->bind('<FocusIn>' => sub {
			&textfocusin; $activeWindow = 1; $activeWindows{$activeTab} = 1;
			my $title = $cmdfile{$activeTab}[$activeWindow] || '--SELECTED TEXT--';
			$whichTextWidget = $textScrolled[1]->Subwidget($textsubwidget);
			$MainWin->title("$titleHeader, ${editmode}ing:  \"$title\"");
			$opsys = $opsysList{$activeTab}[$activeWindow];
			&resetMarks();
			$statusLabel->configure( -text => $saveStatus{$activeTab}[1]);
	});
	for (my $i=0;$i<=1;$i++)
	{
		my @bindTags = $textScrolled[$i]->Subwidget($textsubwidget)->bindtags;
#REMOVED - MESSES UP AUTOINDENT?!?!?!
#		$textScrolled[$i]->Subwidget($textsubwidget)->bindtags([$bindTags[1], $bindTags[0], @bindTags[2 .. $#bindTags]]);  #REVERSE BIND ORDER PROCESSING.

		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<Alt-l>' => [\&shocoords,0]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<Control-t>' => sub { $textScrolled[$activeWindow]->insert('insert', "\t"); $textScrolled[$activeWindow]->see('insert') })  unless ($v);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F1>' => [\&doFnKey,1]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F2>' => [\&doFnKey,2]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F3>' => [\&doFnKey,3]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F4>' => [\&doFnKey,4]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F5>' => [\&doFnKey,5]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F6>' => [\&doFnKey,6]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F7>' => [\&doFnKey,7]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F8>' => [\&doFnKey,8]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F9>' => [\&doFnKey,9]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F10>' => [\&doFnKey,10]);
#		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F11>' => [\&doFnKey,11]);
#		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<F12>' => [\&doFnKey,12]);
#		$textScrolled[$i]->Subwidget($textsubwidget)->bindtags(\@bindTags);  #REVERSE BIND ORDER PROCESSING.
#		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<Return>', sub { shift->doAutoIndent(1); })  #TRIED TO FIX AUTOINDENT, CAN'T HAVE BOTH F3 & AUTOINDENT WORK?!?!?!
	}

	if ($SuperText == 1 || $editor =~ /texthighlight/io)
	{
		$textScrolled[0]->bind('<Control-p>' => sub
		{
				$textScrolled[0]->Subwidget($textsubwidget)->markSet('_prev','insert');
				$textScrolled[0]->Subwidget($textsubwidget)->jumpToMatchingChar();
				&shocoords(0);
		});
		$textScrolled[1]->bind('<Control-p>' => sub
		{
				$textScrolled[1]->Subwidget($textsubwidget)->markSet('_prev','insert');
				$textScrolled[1]->Subwidget($textsubwidget)->jumpToMatchingChar();
				&shocoords(0);
		});
	}
	$opsys = ($bummer) ? 'DOS' : 'Unix';
	my @tablist = $tabbedFrame->pages()  unless ($nobrowsetabs);
	for (my $i=0;$i<=1;$i++)
	{
		$opsysList{$activeTab}[$i] = $opsys;

#		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<ButtonRelease-1>' => [\&shocoords,1]);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind('<ButtonRelease-1>' => sub {
			&shocoords(1);
			if ($editor =~ /TextHighlight/o || $viewer =~ /TextHighlight/o)
			{
				eval { my $self = shift; $self->blockHighlighting(0); };
			}
		});
		$textScrolled[$i]->bind('<Alt-comma>' => sub { &doSearch(0,0) });
		$textScrolled[$i]->bind('<Alt-period>' => sub { &doSearch(0,1) });
#t		$textScrolled[$i]->bind('<Alt-a>' => sub { &doSearch(0) });
		$textScrolled[$i]->bind('<Control-g>' => sub { &doSearch(0,1) });
		my $cls = ref($textScrolled[$i]->Subwidget($textsubwidget));
 		$textScrolled[$i]->Subwidget($textsubwidget)->bind($cls, '<Control-Key-'.scalar(@tablist).'>' => sub{})
 			if (!$nobrowsetabs && scalar(@tablist) <= 9);
		$textScrolled[$i]->Subwidget($textsubwidget)->bind($cls, '<Alt-Tab>' => sub{});
	}

	#NOTE:  <Ctrl-Tab> always & only TABS BETWEEN TOP & BOTTOM OF SPLIT SCREENS,
	#<Alt-Tab> always toggles to NEXT widget just like Tab, except it always
	#works, whereas Tab inserts a Tab (or spaces) when text widget has focus!
	#<Shift-Tab> always toggles to PREVIOUS widget.
	#<Ctrl-#> jumps to specified tab# (1-based) at any time (up to 9 tabs).
	#To navigate between tabs w/keyboard, Tab to the tabs row & use left &
	#right arrow keys, then when desired tab is focused, hit Enter or spacebar.

	$textScrolled[0]->Subwidget($textsubwidget)->bind('<Alt-Tab>' => sub
	{
		if ($scrnCnts{$activeTab} == 2)
		{
			$textScrolled[1]->Subwidget($textsubwidget)->focus;
		}
		else
		{
			$fileMenubtn->focus;
		}
		Tk->break;
	});
	$textScrolled[1]->Subwidget($textsubwidget)->bind('<Alt-Tab>' => sub
	{
		$fileMenubtn->focus;
		Tk->break;
	});
	$textScrolled[$activeWindow]->markSet('_prev','0.0');
	$textScrolled[$activeWindow]->markSet('insert','0.0');
	&openFn()  if ($openDialog);
#DOESN'T WORK EXCEPT FOR SUPERTEXT (I CAN'T GET RED OF "Text" WIDGET'S DEFAULT BINDINGS?!
	$MainWin->bind('<Control-Key-'.scalar(@tablist).'>' => sub
	{
		$tabbedFrame->raise($tablist[$#tablist]);
		Tk->break;
	});
}

sub deleteTabFn
{
	my $usrres = $No;
	$yncDialog->configure(
			-text => "DELETE current tab?");
	$usrres = $yncDialog->Show();
	if ($usrres eq $Yes)
	{
		return  if (&exitFn($No, 'NOEXIT', $activeTab) eq $Cancel);
		$tabbedFrame->delete($activeTab);
	}
}

sub chgTabs
{
	my $thisTab = shift;

	my $r = $tabbedFrame->raised();
	$activeTab = $r;
	$textScrolled[0] = $text1Hash{$activeTab}[0];
	$textScrolled[1] = $text1Hash{$activeTab}[1];
	$activeWindow = $activeWindows{$activeTab};
#	$scrnCnt = $scrnCnts{$activeTab};
	if (defined $fileMenubtn)
	{
		if ($scrnCnts{$activeTab} == 2)
		{
			$fileMenubtn->entryconfigure('Single screen',  -state => 'normal');
			$fileMenubtn->entryconfigure('Split screen',  -state => 'disabled');
		}
		else
		{
			$fileMenubtn->entryconfigure('Single screen',  -state => 'disabled');
			$fileMenubtn->entryconfigure('Split screen',  -state => 'normal');
		}
	}
	$textAdjuster = $text1Hash{$activeTab}[2];
#print DEBUG "-1--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	&resetMarks();
}

sub openFn		#File.Open (Open a different command file)
{
	my ($openfid) = shift;
	my ($usrres);
	$usrres = $No;
	unless ($v)
	{
		if (anyChanges($activeTab, $activeWindow))
		{
			$yncDialog->configure(
					-text => "Save any changes to $cmdfile{$activeTab}[$activeWindow]?");
			$usrres = $yncDialog->Show();
			&fixAfterStep  if ($Steppin);
			$cmdfile{$activeTab}[$activeWindow] ||= "$hometmp/e.out.tmp";
			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
		}
	}
	$_ = '';
	$usrres = $Cancel x &writedata($cmdfile{$activeTab}[$activeWindow], 1)  if ($usrres eq $Yes);
	return  if ($usrres eq $Cancel);
	my ($savefile) = $cmdfile{$activeTab}[$activeWindow];
	if ($openfid || !&getcmdfile("Select file to $editmode"))
	{
		if ($openfid && $openfid =~ m#^\~\/#o)
		{
			#CONVERT "~/fid" TO "/home/<user-id>/fid":
			$openfid =~ s#\~#$ENV{'HOME'}#;
		}
		elsif ($openfid && $openfid !~ m#^\/#o)
		{
			#APPEND .cdout PATH TO UNPATHED FILENAMES, IF IT EXISTS:
			if (!$bummer && -e "$ENV{'HOME'}/.cdout" && open (CD, "$ENV{'HOME'}/.cdout"))
			{
				my $cdir = <CD>;
				chomp($cdir);
				close CD;
				$cdir =~ s#\/$##;
				$openfid =~ s#^\.\/##;
				$openfid = $cdir . '/' . $openfid;
			}
		}

		my $posn;
		if ($openfid) {
		#HANDLE FILENAMES W/ :line# APPENDED (STRIP & GOTO THAT POSN IN FILE):
			$posn = (!(-e $openfid) && $openfid =~ s/([^\\])\:([\d\.]+)$/$1/) ? $2 : undef; #DON'T FALLBACK TO $l HERE!
			$cmdfile{$activeTab}[$activeWindow] = $openfid;
		} else {
			$posn = (!(-e $cmdfile{$activeTab}[$activeWindow]) && $cmdfile{$activeTab}[$activeWindow] =~ s/([^\\])\:([\d\.]+)$/$1/) ? $2 : undef; #DON'T FALLBACK TO $l HERE!
		}
		&clearMarks();
		if (&fetchdata($cmdfile{$activeTab}[$activeWindow]))
		{
			$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{$activeTab}[$activeWindow]\"");
			unless ($activeWindow)
			{
				(my $filePart = $cmdfile{$activeTab}[$activeWindow]) =~ s#^.*\/([^\/]+)$#$1#;
				$tabbedFrame->pageconfigure($activeTab, -label => $filePart)  unless ($nobrowsetabs);
			}
#			&gotoMark($textScrolled[$activeWindow], (defined($l) ? $l : '_Bookmark'), 'append');
			&gotoMark($textScrolled[$activeWindow], (defined($posn) ? $posn : '_Bookmark'), 'append');
		}
		else
		{
			$cmdfile{$activeTab}[$activeWindow] = $savefile;
		}
	}
	else
	{
		$cmdfile{$activeTab}[$activeWindow] = $savefile  unless (defined($cmdfile{$activeTab}[$activeWindow]));
	}
}

sub saveSelected
{
	$txt = '';

	if ($newsupertext || $AnsiColor)
	{
		eval {$txt = $textScrolled[$activeWindow]->getansi('sel.first','sel.last');};
	}
	else
	{
		eval {$txt = $textScrolled[$activeWindow]->get('sel.first','sel.last');};
	}
	my $lastpos = '';
	eval { $lastpos = $textScrolled[$activeWindow]->index('sel.last'); };
	$txt .= "\n"  if ($txt && $lastpos =~ /\.0$/o);
	if ($newsupertext || $AnsiColor)
	{
		$txt = $textScrolled[$activeWindow]->getansi('0.0','end')  unless ($txt);
	}
	else
	{
		$txt = $textScrolled[$activeWindow]->get('0.0','end')  unless ($txt);
	}
	my ($fileDialog) = $MainWin->JFileDialog(
			-Title  => 'File to save selected text to:',
			-Path   => $startpath,
			-History => (defined $histmax) ? $histmax : 20,
			-HistFile => $histFile,
			-PathFile => $pathFile,
			-HistDeleteOk => 1,
			-HistUsePath => (defined $histpath) ? $histpath : -1,
			-HistUsePathButton => $histpathbutton,
			-DestroyOnHide => $Steppin,
			-Create => 1);

	my $fid = $fileDialog->Show;
	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	return  unless ($fid =~ /\S/o);
	$_ = $txt;
	return (&writedata($fid, 1, 1, 2));
}

sub saveFn		#File.Save (Save changes to command file)
{
	my $saveopt = shift || 0;
	my ($cancel) = 0;
	$cancel = &getcmdfile("Save file as")  unless ($cmdfile{$activeTab}[$activeWindow] =~ /\S/);
	return ($cancel)  if ($cancel);   #getcmdfile() returns 1 if no filename entered!
	$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{$activeTab}[$activeWindow]\"");
	$_ = '';
	my $usrres = $Yes;
	if (-e $cmdfile{$activeTab}[$activeWindow])
	{
		my (@fidinfo) = stat($cmdfile{$activeTab}[$activeWindow]);
		my $msg;
#		$msg = "file \"$cmdfile[$activeWindow]\"\nACCESSED DURING SESSION! overwrite?"
#				if ($fileLastUpdated && $fidinfo[8] > $fileLastUpdated);
		$msg = "file \"$cmdfile{$activeTab}[$activeWindow]\"\nexists! overwrite?"
				unless ($msg || $dontaskagain);
		if ($msg)
		{
			$usrres = $Cancel;
			$saveDialog->configure(
					-text => $msg);
			$usrres = $saveDialog->Show();
		}
	}
	if ($usrres eq $Yes || $usrres eq $Append)
	{
		$dontaskagain = 1  unless ($v || $ask > 1 || $usrres eq $Append);   #IF ASK=2, THEN ALWAYS ASK!
		return (&writedata($cmdfile{$activeTab}[$activeWindow], 0, 0, $saveopt, 0, $usrres));
	}
}

sub printFn
{
	my ($printedselected);
	if (open(T, "<${homedir}.myeprint"))
	{
		$intext = <T>;
		chomp ($intext);
	}
	&gettext("Print cmd:",25,'t',0,0,1);
	return 0  unless ($intext && $intext ne '*cancel*');
	if (open (T, ">${homedir}.myeprint"))
	{
		print T "$intext\n";
		close T;
	}
	$_ = '';
	if ($newsupertext || $AnsiColor)
	{
		eval {$_ = $textScrolled[$activeWindow]->getansi('sel.first','sel.last');};
	}
	else
	{
		eval {$_ = $textScrolled[$activeWindow]->get('sel.first','sel.last');};
	}
	if ($_)
	{
		my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');
		$_ .= "\n"  if ($_ && $lastpos =~ /\.0$/o);
		$printedselected = 1;
	}
	&writedata("$hometmp/e.out.tmp", 0, $printedselected, 2);
	my $mytitle = $cmdfile{$activeTab}[$activeWindow];
	$mytitle =~ s/\s/_/g;
	$intext .= " -o\"-title=$mytitle\" "  if ($cmdfile{$activeTab}[$activeWindow] && $intext =~ /post/o && $intext !~ /title/o);  #SPECIAL FEATURE FOR MY "POST" SCRIPTS!
	if ($intext =~ /^\s*\|/o)
	{
		system("cat $hometmp/e.out.tmp $intext &");
	}
	else
	{
		system("$intext $hometmp/e.out.tmp &");
	}
	if ($?)
	{
		&setStatus("..Could not print ($intext) - $?.");
	}
	elsif ($printedselected)
	{
		&setStatus("..printed ($intext) selected text.");
	}
	else
	{
		&setStatus("..printed ($intext) all text.");
	}
}

sub exitFn 	#File.Save (Save changes to command file)
{
	my $saveDefaultYN = shift || $No;
	my $noExit = shift || 0;
	my $currentTabOnly = shift || 0;

	my ($cancel) = 0;
	$_ = '';
	my ($msg, @wins);
	my $saveTab = $activeTab;
	my $saveActive0 = $activeWindow;
	my @tablist = ($nobrowsetabs || $currentTabOnly) ? $activeTab : $tabbedFrame->pages();
	my $tabNum = 1;
	my ($usrres);
TABLOOP: 	foreach $activeTab (@tablist)
	{
		$textScrolled[0] = $text1Hash{$activeTab}[0];
		$textScrolled[1] = $text1Hash{$activeTab}[1];
		$activeWindow = $activeWindows{$activeTab};
		if ($scrnCnts{$activeTab} == 2)
		{
			@wins = (0, 1);
		}
		else
		{
			@wins = ($activeWindow);
		}
		my $saveActive = $activeWindow;
		my $saveActiveWindowFromFocus;
		my $whichWindowIndicator = ($#wins >= 1) ? '(Top window) ' : '';
		$whichWindowIndicator = ($nobrowsetabs ? '' : "Tab# $tabNum: ") . $whichWindowIndicator;
WINDOWLOOP:		foreach $activeWindow (@wins)
		{
			$usrres = $saveDefaultYN;
			$_ = '';
			#DEFAULT=NO OR CMDFILE IS EMPTY OR (ASKAGAIN && CMDFILE EXISTS):
			if ($saveDefaultYN eq $No || $cmdfile{$activeTab}[$activeWindow] !~ /\S/o || (!$dontaskagain && -e $cmdfile{$activeTab}[$activeWindow]))
			{
				$saveActiveWindowFromFocus = $activeWindow;
				$whichWindowIndicator =~ s/Top/Bottom/o  if ($activeWindow);
				unless ($v || $cmdfile{$activeTab}[$activeWindow] =~ /\S/o)
				{
					$usrres = $No;
					if (anyChanges($activeTab, $activeWindow))
					{
						$yncDialog->configure(
								-text => "Save ${whichWindowIndicator}data to a file?");
						$usrres = $yncDialog->Show();
						if ($usrres eq $No && !$v)
						{
							&backupFn("e.after$activeWindow.tmp");
							#&SaveOnDestroy('A', 0, $activeWindow, $activeTab)  if ($0 =~ /ec\w*\.(?:exe|pl)$/io);
						}
					}
					next  unless ($usrres eq $Yes);
					&getcmdfile("Save ${whichWindowIndicator}data as");
					$usrres = $Cancel  unless ($cmdfile{$activeTab}[$activeWindow]);
				}
				$msg = '';
				if (-e $cmdfile{$activeTab}[$activeWindow])
				{
					$msg = "${whichWindowIndicator}file \"$cmdfile{$activeTab}[$activeWindow]\"\nexists! overwrite?";
					if ($chkacc)
					{
						my (@fidinfo) = stat($cmdfile{$activeTab}[$activeWindow]);
						$msg = "${whichWindowIndicator}file \"$cmdfile{$activeTab}[$activeWindow]\"\nACCESSED DURING SESSION! overwrite?"
								if ($fileLastUpdated && $fidinfo[8] > $fileLastUpdated);
					}
				}
				elsif ($usrres eq $No)
				{
					$msg = "Save any ${whichWindowIndicator}changes to $cmdfile{$activeTab}[$activeWindow]?";
				}
				if ($msg && anyChanges($activeTab, $activeWindow))
				{
					$yncDialog->configure(
							-text => $msg);
					$usrres = $yncDialog->Show()  unless ($v);
				}
				$activeWindow = $saveActiveWindowFromFocus;
			}
			$_ = '';
			if ($usrres eq $Yes)
			{
#			$dontaskagain = 1  unless ($v || $ask > 1);
				&SaveOnDestroy('S', 1, $activeWindow, $activeTab)  if ($0 =~ /ec\w*\.(?:exe|pl)$/io); #BACKUP AT EVERY SAVE WHEN EDITING CODE.
				return  if (&writedata($cmdfile{$activeTab}[$activeWindow], 1));
				print "..File \"$cmdfile{$activeTab}[$activeWindow]\" saved.\n";
			}
			elsif ($usrres eq $No && !$v)
			{
				&backupFn("e.after$activeWindow.tmp");
				#&SaveOnDestroy('A', 0, $activeWindow, $activeTab)  if ($0 =~ /ec\w*\.(?:exe|pl)$/io);
			}
			elsif ($usrres eq $Cancel)
			{
				last TABLOOP;
			}
		}
		$activeWindow = $saveActive;
		++$tabNum;
	}
	$activeTab = $saveTab;
	$textScrolled[0] = $text1Hash{$activeTab}[0];
	$textScrolled[1] = $text1Hash{$activeTab}[1];
	$activeWindow = $saveActive0;
	if ($usrres ne $Cancel)
	{
		close DEBUG  unless (!$debug || $noExit);
		exit (0)  unless ($noExit);
	}
	return $usrres;
}

sub saveasFn		#File.save As (Save under new name)
{
	my ($savefile) = $cmdfile{$activeTab}[$activeWindow];
	my $saveopt = shift;

	unless (&getcmdfile("Save file as"))
	{
		my ($usrres) = $Yes;
		if (!$dontaskagain && -e $cmdfile{$activeTab}[$activeWindow])
		{
			$usrres = $Cancel;
			$yncDialog->configure(
					-text => "file \"$cmdfile{$activeTab}[$activeWindow]\"\nexists! overwrite?");
			$usrres = $yncDialog->Show();
		}
		$_ = '';
		if ($usrres eq $Yes)
		{
			&writedata($cmdfile{$activeTab}[$activeWindow], 1, 0, $saveopt);
			$dontaskagain = 1  unless ($v || $ask > 1);
		}
	}
#	$cmdfile{$activeTab}[$activeWindow] = $savefile;	 #KEEP OLD FILENAME AS DEFAULT SAVE / COMMENT OUT TO MAKE SAVE-AS NAME THE DEFAULT SAVE NAME FOR FUTURE SAVES!
	$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{$activeTab}[$activeWindow]\"");
}

sub getcmdfile          #PROMPT USER FOR NAME OF DESIRED COMMAND FILE.  RETURNS 1 ON FAILURE/CANCEL
{
	my ($opt) = shift;
	$intext = undef;
	local $_;
	my ($fileDialog) = $MainWin->JFileDialog(
			-Title  => $opt || 'Select file to edit',
			-Path   => $startpath,
			-History => (defined $histmax) ? $histmax : 20,
			-HistFile => $histFile,
			-PathFile => $pathFile,
			-HistDeleteOk => 1,
			-HistUsePath => (defined $histpath) ? $histpath : -1,
			-HistUsePathButton => $histpathbutton,
			-DestroyOnHide => $Steppin,
			-Create => 1);
	$intext = $fileDialog->Show;
	chomp($intext);
	&fixAfterStep()  if ($Steppin);   #TRYIN TO MAKE OUR STUPID W/M RESTORE FOCUS?!?!?! :(
#print DEBUG "-3--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus();
	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	$intext = undef  if ($intext !~ /\S/o);
	if (defined($intext))
	{
		$cmdfile{$activeTab}[$activeWindow] = $intext;
		$dontaskagain = 0  if ($ask);
	}
	return $cmdfile{$activeTab}[$activeWindow]  unless ($opt);   #APPEARS NOT 2B USED.
	return (1)  unless (defined($intext));
	return (0);
}

sub fetchdata
{
	my ($fid) = shift;
	$fid =~ s/\\//g  unless ($bummer);
	my ($backups);
	print DEBUG "--open ($fid) for input...\n"  if ($debug);
	if (open(INFID,$fid))
	{
		my (@fidinfo) = stat($fid);
		$fileLastUpdated = $fidinfo[8];
		binmode INFID;
		$textScrolled[$activeWindow]->delete('0.0','end');
		&clearMarks();
		for ($i=1;$i<=$tagcnt;$i++)
		{
			eval {$whichTextWidget->tagDelete("foundme$i");};
		}
		$tagcnt = 0;
		$_ = <INFID>;
		$opsys = (s/\r\n/\n/go) ? 'DOS' : 'Unix';
		$opsys = 'Mac'  if (s/\r/\n/go);
		$opsysList{$activeTab}[$activeWindow] = $opsys;
		my $indata = $_;
		while (<INFID>)
		{
			s/\r\n?/\n/go;
			$indata .= $_;
		}
		close INFID;
		if ($textsubwidget =~ /xmlviewer/io)
		{
			$textScrolled[$activeWindow]->insertXML(-text => $indata);
			unless (defined($alreadyHaveXMLMenu{$activeTab}[$activeWindow])
					&& $alreadyHaveXMLMenu{$activeTab}[$activeWindow])
			{
				$textScrolled[$activeWindow]->XMLMenu;
				$alreadyHaveXMLMenu{$activeTab}[$activeWindow] = 1;
			}
		}
		else
		{
			if ($haveTextHighlight && ($editor =~ /texthighlight/io || $viewer =~ /texthighlight/io))
			{
				my $fext = '';
				$fext = $1  if ($fid =~ /\.(\w+)$/o);
				if ($codetext)  #FORCES ALWAYS USE SPECIFIED SYNTAX HIGHLIGHTER:
				{
					my $langModule = ($codetext eq 'Kate') ? &kateExt($fid) : $codetext;
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => $langModule);
				}
 				elsif ($mimeTypes{$fext})  #SELECT HIGHLIGHTER BASED ON FILE EXTENSION:
				{
					my $langModule = ($mimeTypes{$fext} eq 'Kate') ? &kateExt($fid) : $mimeTypes{$fext};
print DEBUG "-chose $mimeTypes{$fext} from mime file!\n"  if ($debug);
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => $langModule);
				}
#				elsif ($fid =~ /\.(?:html?|tmpl)$/io)  #DEFAULT FOR HTML STUFF:
#				{
#print DEBUG "-chose HTML!\n"  if ($debug);
#					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
#							-syntax => 'HTML');
#				}
#				elsif ($fid =~ /\.js$/io)  #DEFAULT FOR JAVASCRIPT:
#				{
#print DEBUG "-chose JavaScript!\n"  if ($debug);
#					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
#							-syntax => 'Kate::JavaScript');
#				}
#				elsif ($fid =~ /\.css$/io)  #DEFAULT FOR CSS:
#				{
#print DEBUG "-chose CSS!\n"  if ($debug);
#					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
#							-syntax => 'Kate::CSS');
#				}
#				elsif ($fid =~ /\.sh$/io)  #DEFAULT FOR SHELLSCRIPTING:
#				{
#print DEBUG "-chose Bash!\n"  if ($debug);
#					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
#							-syntax => 'Bash');
#				}
				elsif ($fid =~ /(?:\.X|x)(?:default|resource)s\b/)  #WE'RE AN Xresoure file
				{
					$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
							-syntax => 'Xresources');
print DEBUG "-chose Xresource from file name.\n"  if ($debug);
				}
				else  #LOOK FOR A "SHABANG" LINE AND TRY TO DETERMINE HIGHLIGHTING FROM THAT:
				{
					my ($line1) = split(/\n/o, $indata);
					if ($line1 =~ /\#\!.+perl/o)  #ME THINKS THIS IS A PERL FILE:
					{
						$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
								-syntax => $haveKate ? 'Kate::Perl' : $havePerlCool);
print DEBUG "-chose Perl based on line 1(#!); haveKate=$haveKate!\n"  if ($debug);
					}
					elsif ($line1 =~ /\#\!.+sh\s*$/o)  #LOOKS LIKE A SHELL-SCRIPT:
					{
						$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
								-syntax => 'Bash');
print DEBUG "-chose Bash based on line 1(#!)!\n"  if ($debug);
					}
					else   #DON'T KNOW, SO NOT GONNA HIGHTLIGHT AT ALL!:
					{
						my $langModule = $haveKate ? (&kateExt($fid) || 'None') : 'None'; 
						$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
								-syntax => $langModule);
print DEBUG "-chose (otherwise) $langModule!\n"  if ($debug);
					}
				}
				$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure('-rules' => undef);
#print DEBUG "-??????0- tsw=$textsubwidget= aw=$activeWindow=\n";
#print DEBUG "-??????1- tsw=$textsubwidget= aw=$activeWindow= widget=".$textScrolled[$activeWindow]."=\n";
#print DEBUG "-??????2- tsw=$textsubwidget= aw=$activeWindow= widget=".$textScrolled[$activeWindow]->Subwidget($textsubwidget)."=\n";
				$textScrolled[$activeWindow]->Subwidget($textsubwidget)->highlightPlug;
				$textScrolled[$activeWindow]->Subwidget($textsubwidget)->bind('<F11>' => [\&reHighlight,0]);
				$textScrolled[$activeWindow]->Subwidget($textsubwidget)->bind('<F12>' => [\&reHighlight,1]);
				my $hlmenu;
				eval { $hlmenu = $editMenubtn->entrycget('Re-Highlight', '-label'); };
#print DEBUG (defined($hlmenu) ? "HIGHLIGHT menu ALREADY DEFINED!\n" : "No highlight menu defined yet!\n");
				unless (defined($hlmenu))
				{
					$editMenubtn->command(-label => 'Re-Highlight', -command => [\&reHighlight,0]);
					$editMenubtn->command(-label => 'RE-HIGHLIGHT', -command => [\&reHighlight,1]);
				}
			}
			$textScrolled[$activeWindow]->insert('end',$indata);
			#NEXT 21 ADDED TO HANDLE LEGACY PC-WRITE "COMMENTS" (MAKE THEM BLUE LIKE PC-WRITE)
			my $srchpos = '1.0';
			my $cnt = 1;
			while (1)
			{
				$srchpos = $textScrolled[$activeWindow]->search(-forwards, -regexp, -count => \$lnoffset, '--', "\x07[^\x07\r]+\x07?", $srchpos, 'end');
				last  if not $srchpos;
				$textScrolled[$activeWindow]->tagAdd("Comment_$cnt", $srchpos, "$srchpos + $lnoffset char");
				$textScrolled[$activeWindow]->tag("configure", "Comment_$cnt", -foreground => 'blue');
				$srchpos = $textScrolled[$activeWindow]->index("$srchpos + $lnoffset char");
				++$cnt;
			}
			$srchpos = '1.0';
			while (1)
			{
				$srchpos = $textScrolled[$activeWindow]->search(-forwards, -regexp, -count => \$lnoffset, '--', "\x02[^\x02\r]+\x02?", $srchpos, 'end');
				last  if not $srchpos;
				$textScrolled[$activeWindow]->tagAdd("Bold_$cnt", $srchpos, "$srchpos + $lnoffset char");
				$textScrolled[$activeWindow]->tag("configure", "Bold_$cnt", -foreground => 'white');
				$srchpos = $textScrolled[$activeWindow]->index("$srchpos + $lnoffset char");
				++$cnt;
			}
		}
		$cmdfile{$activeTab}[$activeWindow] = $fid;
#		$MainWin->title("$titleHeader, ${editmode}ing:  \"$fid\"");   #GETS OVERWRITTEN ANYWAY :(
		$textScrolled[$activeWindow]->markSet('_prev','0.0');
		$textScrolled[$activeWindow]->markSet('insert','0.0');
		my $tagFid = "${fid}.etg";
		if (defined $tagpath)
		{
			my $fileName = ($fid =~ m#\/([^\/]+)$#) ? $1 : $fid;
			$tagFid = $tagpath;
			$tagFid .= '/'  unless ($tagpath =~ m#\/$#);
			$tagFid .= $fileName;
			$tagFid .= '.etg';
		}
		if (($newsupertext || $AnsiColor) && -r $tagFid && open (INFID, $tagFid))
		{
			my ($onoff, $tagtype, $tagindx, %tagStartHash);
			while (<INFID>)
			{
				s/s+$//o;
				($onoff, $tagtype, $tagindx) = split(/\:/o);
				if ($onoff eq '-')
				{
					if ($tagStartHash{$tagtype})
					{
						if ($tagtype =~ /ul$/o)
						{
							$textScrolled[$activeWindow]->tagAdd($tagtype, $tagStartHash{$tagtype}, $tagindx);
							$textScrolled[$activeWindow]->tag("configure", $tagtype, -underline => 1);
						}
						elsif ($tagtype =~ /bd$/o)
						{
							$textScrolled[$activeWindow]->tagAdd($tagtype, $tagStartHash{$tagtype}, $tagindx);
							$textScrolled[$activeWindow]->tag("configure", $tagtype, -font => [-weight => "bold" ]);
						}
						elsif (substr($tagtype,4,2) eq 'bg')
						{
							my $color = substr($tagtype,6);
							$textScrolled[$activeWindow]->tagAdd($tagtype, $tagStartHash{$tagtype}, $tagindx);
							$textScrolled[$activeWindow]->tag("configure", $tagtype,"-background" => $color);
						}
						else
						{
							my $color = substr($tagtype,6);
							$textScrolled[$activeWindow]->tagAdd($tagtype, $tagStartHash{$tagtype}, $tagindx);
							$textScrolled[$activeWindow]->tag("configure", $tagtype,"-foreground" => $color);
						}
					}
				}
				else
				{
					$tagStartHash{$tagtype} = $tagindx;
				}
			}
			close INFID;
		}
		my $tagFid = "${fid}.emk";
		if (defined $tagpath)
		{
			my $fileName = ($fid =~ m#\/([^\/]+)$#) ? $1 : $fid;
			$tagFid = $tagpath;
			$tagFid .= '/'  unless ($tagpath =~ m#\/$#);
			$tagFid .= $fileName;
			$tagFid .= '.emk';
		}
		if (-r $tagFid && open (INFID, $tagFid))
		{
			my ($mkName, $mkPosn);
			while (<INFID>)
			{
				chomp;
				($mkName, $mkPosn) = split('=');
				$mkPosn =~ s/\s+$//o;    #FOR SOME REASON, CHOMP NOT WORKIN'?!
				&addMark($mkName, $mkPosn)  if ($mkPosn =~ /^[\d\.]+$/o);
			}
			close INFID;
#			unlink $tagFid  unless ($v);
		}
		unless ($v)
		{
			#$backupct = &backupFn($fid);
			$backupct = &backupFn($nb ? 'e.before.tmp' : 0);
			&SaveOnDestroy('B', 1)  if ($nb);   #JWT:ADDED 20130309 TO BE SURE TO SAVE EACH FILE IN IT'S OPENED STATE
		}
		$_ = "..Successfully opened file: \"$fid\"";
		$_ .= (-w $fid) ? '.' : ' (READONLY).';
		unless ($v || $nb)
		{
			$_ .= " backup=$backupct."  if ($backupct =~ /\d/o);
		}
		&setStatus( $_);
		unless ($v)
		{
			if ($textsubwidget =~ /supertext/io)   #ADDED 20080411 TO BLOCK CHANGES FOR UNDO.
			{
				$whichTextWidget->resetUndo;   #FOR SOME REASON SUPERTEXT HATH IT'S OWN METHOD NAMES?!
			}
			else
			{
				eval { $whichTextWidget->ResetUndo; };
			}
		}
		return 1;
	}
	else
	{
		&setStatus("..Could not open file: \"$fid\" (cwd=".&cwd.")!");
		$cmdfile{$activeTab}[$activeWindow] = $fid;
#		$MainWin->title("$titleHeader, ${editmode}ing New File:  \"$fid\"");   #GETS OVERWRITTEN ANYWAY :(
		return undef;
	}
}

sub appendfile
{
	my ($fid) = '';

	my ($fileDialog) = $MainWin->JFileDialog(
			-Title  => 'Select file to insert:',
			-Path   => $startpath,
			-History => (defined $histmax) ? $histmax : 20,
			-HistFile => $histFile,
			-PathFile => $pathFile,
			-HistDeleteOk => 1,
			-HistUsePath => (defined $histpath) ? $histpath : -1,
			-HistUsePathButton => $histpathbutton,
			-DestroyOnHide => $Steppin,
			-Create => 0);

	$fid = $fileDialog->Show;
	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	return  unless ($fid =~ /\S/o);

	if (open(INFID,$fid))
	{
		binmode INFID;
		$textScrolled[$activeWindow]->markSet('selstartmk','insert');
		$textScrolled[$activeWindow]->markGravity('selstartmk','left');
		$textScrolled[$activeWindow]->markSet('selendmk','insert');
		$textScrolled[$activeWindow]->markGravity('selendmk','right');
		while (<INFID>)
		{
			s/\r\n?/\n/go;
			$textScrolled[$activeWindow]->insert('insert',$_)  unless ($v);
		}
		close INFID;
		$textScrolled[$activeWindow]->tagAdd('sel', 'selstartmk', 'selendmk');
		my ($pos) = $textScrolled[$activeWindow]->index('selstartmk');
		$statusLabel->configure(
				-text => "..Successfully inserted file: \"$fid\" at $pos.");
	}
	else
	{
		&setStatus("..Could not open file: \"$fid\"!");
	}
}

sub writedata
{
	my ($fid) = shift;
	my $chkExists = shift || 0;
	my $opt = shift || 0;
	my $saveopt = shift || 0;
	my $doNOTsaveMarks = shift || 0;
	my $usrres = shift || $Yes;
	
#		$msg = "file \"$cmdfile{$activeTab}[$activeWindow]\"\nACCESSED DURING SESSION! overwrite?"
#				if ($fileLastUpdated && $fidinfo[8] > $fileLastUpdated);
	my ($ffid) = ">$fid";
	#####$ffid = '>'.$ffid  if ($_);   #MAKE APPEND IF SAVING "SELECTED" TEXT.

	#if (open(OUTFID,">$fid"))
#	$usrres = $Yes;
	if ($usrres eq $Append)
	{
		$ffid = '>' . $ffid;
	}
	elsif ($chkExists && -e $fid)
	{
		my $msg = "file \"$fid\"\nexists! overwrite?";
		$usrres = $Cancel;
		$saveDialog->configure(
				-text => $msg);
		$usrres = $saveDialog->Show();
		$ffid = '>' . $ffid  if ($usrres eq $Append);
	}
	return (1)  unless ($usrres eq $Yes || $usrres eq $Append);
	if (open(OUTFID, $ffid))
	{
		&write2file($fid, (($ffid =~ /^\>\>/) ? 1 : 0), $opt, $saveopt, $doNOTsaveMarks);
		my (@fidinfo) = stat($fid);          #ADDED 20060601.
		$fileLastUpdated = $fidinfo[8];
		return (0);
	}
	else
	{
		if ($usrres eq $Yes && $! =~ /Too many open files/o)  #MUST "REPLACE" FILES ON WEBFARM?!
		{
			if (open(OUTFID, ">$hometmp/e.out.tmp"))
			{
				&write2file($fid, 0, $opt, $saveopt, $doNOTsaveMarks);
				#`rm -f $fid`;
				unlink($fid);
				if ($? || $!)
				{
					sleep (1);
					copy("${hometmp}/e.out.tmp", $fid);
					eval { `chmod 777 $hometmp/e.out.tmp $fid`; };
					return (0)  if ($? || $!);
				}
			}
		}
		$errDialog->configure(
				-text => "writedata: Could not save \"$fid\" ($!)!");
		$errDialog->Show($showgrabopt);
		print "e:writedata: could not open \"$fid\" ($!)!\n";
		&setStatus("writedata:Could not save $fid ($!)!");
		return (1);
	}
}

sub write2file
{
	my ($fid) = shift;
	my $appendit = shift;
	my $opt = shift || 0;
	my $saveopt = shift || 0;   #DON'T SAVE TAGS IF SAVEOPT IS 2.  ALWAYS SAVE MARKS IF 3:
	my $doNOTsaveMarks = shift || 0;

	binmode OUTFID;
	#$_ = '';
	unless ($opt)
	{
		$_ = $textScrolled[$activeWindow]->getansi('0.0','end')
				if (($newsupertext || $AnsiColor) && $saveopt == 2);
	}
	$_ = $textScrolled[$activeWindow]->get('0.0','end')  unless ($_);
	chomp;
	s/\r\n/\n/go;
	if ($opsysList{$activeTab}[$activeWindow] eq 'DOS')
	{
		s/\n/\r\n/go;
  	}
	elsif ($opsys eq 'Mac')
	{
		s/\n/\r/go;
	}
	print OUTFID;
	close OUTFID;
	&saveTags($fid)  if ($saveopt != 2);
#print "---- should I save marks? ($doNOTsaveMarks|$saveopt)!\n";
	unless ($doNOTsaveMarks)
	{
		&saveMarks($fid, $activeWindow)  if ($saveopt == 3 || !$doNOTsaveMarks);
	}
	&setStatus("..Edits " . ($appendit ? 'appended' : 'saved') . " to file: \"$fid\".");
}

sub saveMarks
{
	my $ffid = $_[0] . '.emk';
	if (defined $tagpath)
	{
		my $fileName = ($_[0] =~ m#\/([^\/]+)$#) ? $1 : $_[0];
		$ffid = $tagpath;
		$ffid .= '/'  unless ($tagpath =~ m#\/$#);
		$ffid .= $fileName;
		$ffid .= '.emk';
	}
	my $thiswindow = $_[1];
	my @marks = sort keys %{$markHash{$activeTab}[$thiswindow]};
#print DEBUG "-saveMarks: aw=$thiswindow= mark0=$marks[0]= ffid=$ffid=\n"  if ($debug);
	my ($m, $mk, $mkIndex);
	if ($#marks >= 0)
	{
		foreach $m (@marks)
		{
			if ($markMenuHash{$activeTab}[$activeWindow]{$m}->{markposn})
			{
				if (open(OUTFID, ">$ffid"))
				{
					foreach $mk (@marks)
					{
#						print OUTFID "$mk=".$markMenuHash{$activeTab}[$activeWindow]{$mk}->{markposn}."\n";
						$mkIndex = $markWidget{$activeTab}[$activeWindow]{$mk}->index($mk);
						print OUTFID "$mk=$mkIndex\n";
					}
					close OUTFID;
				}
				return;
			}
		}
	}
	else
	{
		unlink $ffid  if (-f $ffid);
#print DEBUG "-saveMarks(REMOVE MARK FILE)\n"  if ($debug);
	}
}

sub saveTags
{
	my $fid = shift;

	if ($newsupertext || $AnsiColor)
	{
		my $ffid = $fid . '.etg';
		if (defined $tagpath)
		{
			my $fileName = ($_[0] =~ m#\/([^\/]+)$#) ? $1 : $_[0];
			$ffid = $tagpath;
			$ffid .= '/'  unless ($tagpath =~ m#\/$#);
			$ffid .= $fileName;
			$ffid .= '.etg';
		}
		my @xdump;
		eval { @xdump = $textScrolled[$activeWindow]->dump(-tag, '0.0', 'end'); };
		my $taglist = '';
		my $foundatag = 0;
		for ($i=0;$i<=$#xdump;$i+=3)
		{
			if ($xdump[$i+1] =~ /^ANSI/o)
			{
				$taglist .= (($xdump[$i] eq 'tagon') ? '+' : '-')
						. ':'.$xdump[$i+1].':'.$xdump[$i+2]."\n";
				$foundatag++;
			}
		}
		if ($foundatag && open(OUTFID, ">$ffid"))
		{
			print OUTFID $taglist;
			close OUTFID;
		}
		else
		{
			unlink $ffid;
		}
	}
}

sub newSearch
{
	my ($newsearch) = shift;

	my ($whichTextWidget) = $textScrolled[$activeWindow];
	eval { $whichTextWidget->tagDelete('savesel'); };
	eval { $whichTextWidget->tagAdd('savesel', 'sel.first', 'sel.last'); };
	$srchTextVar = '';
	my ($clipboard);

	eval
	{
		$clipboard = $MainWin->SelectionGet(-selection => 'PRIMARY');
	}
	;
	unless (defined($clipboard))
	{
		eval
		{
			$clipboard = $whichTextWidget->get('foundme.first','foundme.last');
		}
	}
	unless (defined($clipboard) && $clipboard =~ /\S/o)
	{
		eval
		{
			$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
		}
		;
	}

	$startattop = 1  if ($newsearch);
	if (Exists($xpopup))
	{
		$MainWin->focus()  if ($Steppin);
#print DEBUG "-4--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
		$xpopup->destroy;
		$MainWin->raise()  if ($Steppin);
	}
	$xpopup = $MainWin->Toplevel;
	$xpopup->transient($MainWin);
	$xpopup->title('Search For:');
	$whichTextWidget->tagDelete('foundme');

	$srchText = $xpopup->JBrowseEntry(
			-label => '',
			-textvariable => \$srchTextVar,
			-choices => \@srchTextChoices,
			-listrelief => 'flat',
			-relief => 'sunken',
			-browsecmd => sub { 
				$srchopts = $srchOptChoices{$srchTextVar}  if (defined($srchOptChoices{$srchTextVar}));
				$srchops ||= '-nocase';
				if (defined($replTextChoices{$srchTextVar}))
				{
					$replText->delete('0','end');
					$replText->insert('end',$replTextChoices{$srchTextVar});	
				}
			},
			-takefocus => 1,
###			-browse => 1,
			-noselecttext => 1,
			-deleteitemsok => 1,
			-width  => 38)->pack(
			-padx		=> 2,
			-side		=> 'top');
	my ($srchLabel) = $xpopup->Label(-text => 'Search for expression');
	$srchText->bind('<FocusIn>' => sub { $curTextWidget = shift; } );
	$srchText->bind('<Escape>' => sub
		{
			$MainWin->focus()  if ($Steppin);
#print DEBUG "-5--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
			$xpopup->destroy;
			$MainWin->raise()  if ($Steppin);
			eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
		}
	);
	$srchLabel->pack(
			-fill	=> 'x');
	$replText = $xpopup->Entry(
			-relief => 'sunken',
			-width  => 40)->pack(
			-padx		=> 2,
			-side		=> 'top');
	$replText->bind('<FocusIn>' => sub { $curTextWidget = shift;} );
	$replText->configure(-state => 'disabled')  if ($v);
	my ($replLabel) = $xpopup->Label(-text => 'Replace with expression');
	$replLabel->configure(-fg => $pasteButton->cget('-disabledforeground'))  if ($v);
	$replLabel->pack(
			-fill	=> 'x');

	$srchopts = '-nocase'  if ($newsearch);
	$exactButton = $xpopup->Radiobutton(
			-text   => 'Exact match?',
			-underline => 0,
			-takefocus      => 1,
			-value		=> '-exact',
			-variable=> \$srchopts);
	$exactButton->pack(
			-side   => 'top',
			-pady   => 6);
	$caseButton = $xpopup->Radiobutton(
			-text   => 'Case-insensitive?',
			-underline => 5,
			-takefocus      => 1,
			-value	=> '-nocase',
			-variable=> \$srchopts);
	$caseButton->pack(
			-side   => 'top',
			-pady   => 6);
	$regxButton = $xpopup->Radiobutton(
			-text   => 'Regular-expression?',
			-underline => 0,
			-takefocus      => 1,
			-value	=> '-regexp',
			-variable=> \$srchopts);
	$regxButton->pack(
			-side   => 'top',
			-pady   => 6);

	if ($newsupertext || $AnsiColor)
	{
		$tagDDlist = $xpopup->Scrolled('Listbox',
				-scrollbars => 'e',
				-height => 7,
				-selectmode => 'multiple',
		);
		$tagDDlist->pack(
				-side   => 'top',
				-pady   => 6);
		foreach my $tt ('No Tags', 'All Tags', 'Underline', 'Bold', 'Black', 'Red', 'Green', 'Yellow', 'Blue', 
'Magenta', 'Cyan', 'White', 'Bkgd Red', 'Bkgd Green', 'Bkgd Yellow', 
'Bkgd Blue', 'Bkgd Magenta', 'Bkgd Cyan', 'Bkgd White')
		{
			$tagDDlist->insert('end', $tt);
		}
	}

#NEXT 2 LINES PREVENT CORE-DUMPS ON MY BOX!
#$_ = `perl -v`;
#$regxButton->configure(-state => 'disabled')  if (/5\.8\.0/);
	my ($srchdirFrame) = $xpopup->Frame;
	$srchdirFrame->pack(-side => 'top', -fill => 'x');
	$srchwards = 1  if ($newsearch);
	$backButton = $srchdirFrame->Radiobutton(
			-text   => 'Backwards?',
			-underline => 0,
			-takefocus      => 1,
			-value	=> 0,
			-variable=> \$srchwards);
	$backButton->pack(
			-side   => 'left',
			-padx 	=> 12,
			-pady   => 6);
	$topCbtn = $srchdirFrame->Checkbutton(
			-text   => 'Start at top?',
			-underline => 0,
			-variable=> \$startattop);
	$topCbtn->pack(
			-side   => 'left',
			-padx 	 => 12,
			-pady   => 6);
	$forwButton = $srchdirFrame->Radiobutton(
			-text   => 'Forwards?',
			-underline => 0,
			-takefocus	=> 1,
			-value  => 1,
			-variable=> \$srchwards);
	$forwButton->pack(
			-side   => 'left',
			-padx 	 => 12,
			-pady   => 6);

	my $btnframe2 = $xpopup->Frame;
	$btnframe2->pack(-side => 'bottom', -fill => 'x');
	my $btnframe = $xpopup->Frame;
	$btnframe->pack(-side => 'bottom', -fill => 'x');

	my $okButton = $btnframe->Button(
			-pady => 2,
			-text => 'Ok',
			-underline => 0,
			#-command => [\&doSearch,1]);
			-command => sub { &updateSearchHistory(); &doSearch(1)});
	$okButton->pack(-side=>'left', -expand=>1, -pady => 6);
	my $gsrButton = $btnframe->Button(
			-pady => 2,
			-text => 'Global',
			-underline => 0,
			-command => sub { &updateSearchHistory(); &GlobalSrchRep($whichTextWidget)});
	$gsrButton->pack(-side=>'left', -expand=>1, -pady => 6);
	my $pasteButton = $btnframe->Button(
			-pady => 2,
			-text => 'Paste',
			-underline => 0,
			-command => sub
	{
		eval {$curTextWidget->insert('insert',$clipboard); $whichTextWidget->tagDelete('savesel') }  if (defined($clipboard));
		eval {$activewidget->tagRemove('sel','0.0','end');};
	}
	);
	$pasteButton->configure(-state => 'disabled')  unless (defined($clipboard));

	$pasteButton->pack(-side=>'left', -expand=>1, -pady => 6);
	my $cbpasteButton = $btnframe->Button(
			-pady => 2,
			-text => 'CB Paste',
			-underline => 1,
			-command => sub
	{
		eval {$curTextWidget->insert('insert',$MainWin->SelectionGet(-selection => 'CLIPBOARD'));};
		eval {$activewidget->tagRemove('sel','0.0','end');};
	}
	);
	$cbpasteButton->configure(-state => 'disabled')  unless (defined($clipboard));

	$cbpasteButton->pack(-side=>'left', -expand=>1, -pady => 6);

	my $dbugButton = $btnframe->Button(
			-pady => 2,
			-text => 'd-bug',
			-underline => 0,
			-command => sub
	{
		if ($srchTextVar)
		{
			$replText->delete('0','end');
			$replText->insert('end','\#$1');	
		}
		else
		{
			$srchTextVar = ($cmdfile{$activeTab}[$activeWindow] =~ /\.(?:js|.*ht.+)$/io) ? '^(alert)' : '^(print|for)';
		}
		$srchText->icursor(length($srchTextVar));
		$srchopts = '-regexp';
	}
	)->pack(-side=>'left', -expand=>1, -pady => 6);

	my $revButton = $btnframe2->Button(
			-pady => 2,
			-text => 'Rev. S & R',
			-command => \&revsrtext);
	$revButton->pack(-side=>'left', -expand=>1, -pady => 6);
	$revButton->configure(-state => 'disabled')  if ($v);

	$btnframe2->Button(
			-pady => 2,
			-text => 'Sub',
			-command => sub
	{
		$srchTextVar = ($cmdfile{$activeTab}[$activeWindow] =~ /\.(?:js|.*ht.+)$/io) ? 'function ' : 'sub ';
		$srchTextVar = 'PROCEDURE '  if ($cmdfile{$activeTab}[$activeWindow] =~ /\.mod$/io);
#print DEBUG "??? current fid=$cmdfile{$activeTab}[$activeWindow]= stv=$srchTextVar=\n"  if ($debug);
		$srchText->icursor(length($srchTextVar));
	}
	)->pack(-side=>'left', -expand=>1, -pady => 6);

	$btnframe2->Button(
			-pady => 2,
			-text => 'RxEx',
			-command => sub
	{
		$srchTextVar =~ s#([\/\\\.\*\+\?\|\(\)\[\]\{\}\-\=\"\'\$\@\#\!\<\>\~\%\^\&])#\\$1#g;
#		$srchText->icursor(length($srchTextVar));
	}
	)->pack(-side=>'left', -expand=>1, -pady => 6);

	my $canButton = $btnframe2->Button(
			-pady => 2,
			-text => 'Cancel',
			-underline => 0,
			-command => sub
	{
		$MainWin->focus()  if ($Steppin);
#print DEBUG "-6--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
		$xpopup->destroy;
		$MainWin->raise()  if ($Steppin);
		eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
	}
	);
	$canButton->pack(-side=>'left', -expand=>1, -pady => 6);
	my $clearButton = $btnframe2->Button(
			-pady => 2,
			-text => 'Clear',
			-underline => 1,
			-command => sub { $srchTextVar = ''; $replText->delete('0','end');});
	$clearButton->pack(-side=>'left', -expand=>1, -pady => 6);
	$xpopup->bind('<Escape>'        => [$canButton	=> Invoke]);

	$srchText->bind('<Return>'        => [$okButton	=> 'Invoke']);
	$replText->bind('<Return>'        => [$okButton	=> 'Invoke']);
	$xpopup->bind('<Escape>'        => [$canButton	=> 'Invoke']);

	$srchpos = '1.0';
	$lnoffset = 0;

	unless ($newsearch || $srchstr le ' ')
	{
		$srchTextVar .= $srchstr;
	}
	$replText->insert('end',$replstr)  unless ($newsearch || $replstr le ' ');
	$xpopup->focus();
	$srchText->focus();
}

sub doSearch
{
	my ($newsearch) = shift;

	my $whichTextWidget = $textScrolled[$activeWindow];

	eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); }
			if (Exists($xpopup));
	$srchwards = shift  if (@_);
	if ($newsearch)
	{
		for ($i=1;$i<=$tagcnt;$i++)
		{
			$whichTextWidget->tagDelete("foundme$i");
		}
		$tagcnt = 0;
	}
	$findMenubtn->entryconfigure('Search Again', -state => 'normal');
	$findMenubtn->entryconfigure('Search Forward >', -state => 'normal');
	$findMenubtn->entryconfigure('Search Backward <', -state => 'normal');
	$findMenubtn->entryconfigure('Modify search', -state => 'normal');
	$againButton->configure(-state => 'normal');
	$bkagainButton->configure(-state => 'normal');
	if ($editor =~ /TextHighlight/o || $viewer =~ /TextHighlight/o)
	{
		eval { $whichTextWidget->Subwidget($textsubwidget)->blockHighlighting(1); };
	}
#print DEBUG "-at 1 ddlist=$tagDDlist=\n";
	eval { @searchTagList = $tagDDlist->curselection; };
#print DEBUG "-at 2 at=$@=\n";
	if ($newsearch == 2)   #START EDITOR AT THIS POSITION!
	{
		$srchstr = $s;
		$srchopts = '-exact';
		$srchopts = '-nocase'  if ($srchstr =~ s#/i$##o);
		$srchwards = 1;
	}
	else
	{
		print DEBUG "-!!!- TAGLIST=".join('|',@{$tagSearch})."=\n"  if ($debug);
		$srchstr = $srchTextVar  if ($newsearch);
		eval { $replstr = $replText->get }  if ($newsearch);  #PRODUCES ERROR SOMETIMES W/O EVEL?!?!?!
		if (Exists($xpopup))
		{
			$MainWin->focus()  if ($Steppin);
#print DEBUG "-7--AW=$activeWindow= AT== scr0=$textScrolled[0]=\n"  if ($debug);
			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
			$whichTextWidget->Subwidget($textsubwidget)->focus();
			$xpopup->destroy;
			$MainWin->raise()  if ($Steppin);
		}
	}
	my $srchstrWas = $srchstr;
	my $hasEOL = ($srchstr =~ s/\\n$/\$/s) ? ' + 1 char' : '';
	$srchpos = '0.0'  if ($whichTextWidget->index('insert') >= $whichTextWidget->index('end') - 1);
	$lnoffset = $newsearch ? 0 : 1;
	$srchpos = $whichTextWidget->index('insert')  unless ($newsearch && $startattop);
	$startattop = 0;
	if ($srchwards)
	{
#print DEBUG "-at 3 taglist=".join('|',@searchTagList)."=\n";
		if (!@searchTagList || !$searchTagList[0])
		{
			$srchpos = $whichTextWidget->search(-forwards, $srchopts, -count => \$lnoffset, '--', $srchstr, $srchpos, 'end');
		}
		else
		{
			($srchpos, $srchstr) = &jumpToTag($srchpos, $srchwards, @searchTagList);
			$hasEOL = 0;
		}
	}
	else
	{
		my ($l) = length($srchstr) || 0;
		$srchpos = $whichTextWidget->index("insert - $l char")  if ($l > 0);
		if (!@searchTagList || !$searchTagList[0])
		{
			$srchpos = $whichTextWidget->search(-backwards, $srchopts, -count => \$lnoffset, '--', $srchstr, $srchpos, '0.0');
		}
		else
		{
			($srchpos, $srchstr) = &jumpToTag($srchpos, $srchwards, @searchTagList);
			$hasEOL = 0;
		}
	}
	if ($srchpos)
	{
		&setStatus("..Found \"$srchstr\" at position $srchpos");
		$whichTextWidget->tagDelete('foundme');
#		eval { $whichTextWidget->tagRemove('sel','0.0','end'); };  #REMOVED 20080426; ADDED 20080411
		$whichTextWidget->markSet('anchor', $srchpos);
		$whichTextWidget->tagAdd('foundme', $srchpos, "$srchpos + $lnoffset char");
		$whichTextWidget->tagConfigure('foundme',
				-relief => 'raised',
				-borderwidth => 1,
				-background  => 'yellow',
				-foreground     => 'black');
		$whichTextWidget->see($srchpos);
		$srchpos = $whichTextWidget->index("$srchpos + $lnoffset char");
		$whichTextWidget->markSet('_prev','insert');
		$whichTextWidget->markSet('insert',$srchpos);
		$srchpos = $whichTextWidget->index('foundme.first')  unless ($srchwards);
		my ($replstrx) = $replstr;
		if ($replstr =~ /\S/o and !$v)
		{
			#$replstrx = ''  if ($replstr eq "\'\'");  #CHGD. TO NEXT 20050331.
			$replstrx = ''  if ($replstr eq "``");  #TREAT `` AS EMPTY STR!
			$replDialog->configure(
					-text => "Replace\n\"$srchstr\"\nwith\n\"$replstrx\"?");
			$usrres = $replDialog->Show($showgrabopt);
			if ($usrres eq $Yes)
			{
				$chgstr = $whichTextWidget->get('foundme.first','foundme.last');
				if ($srchopts eq '-regexp')
				{
					$_ = $replstrx;   #ADDED NEXT 7 20010924.
					s/\:\#([+-]\d+)?/
							my ($offset) = $1;
							my $str = $tagcnt+($offset);
							"$str"
					/ego;
					$chgstr =~ s/$srchstr/eval "return \"$replstrx\""/egs;
				}
				elsif ($srchopts eq '-nocase')
				{
					$chgstr =~ s/\Q$srchstr\E/$replstrx/eigs;
				}
				else
				{
					$chgstr =~ s/\Q$srchstr\E/$replstrx/egs;
				}
				$whichTextWidget->delete('foundme.first',"foundme.last$hasEOL");
				$whichTextWidget->insert('insert',$chgstr);
				$whichTextWidget->tagDelete('foundme');
				$lnoffset = length($chgstr);
				++$tagcnt;
				$whichTextWidget->tagAdd("foundme$tagcnt", "insert - $lnoffset char", "insert");
				$whichTextWidget->tagConfigure("foundme$tagcnt",
						-relief => 'raised',
						-borderwidth => 1,
						-background  => 'green',
						-foreground     => 'black');
			}
		}
	}	
	else
	{
		&setStatus("..Did not find \"$srchstr\".");
	}
	$srchstr = $srchstrWas  if ($hasEOL);
}

sub clearSearch
{
	for ($i=1;$i<=$tagcnt;$i++)
	{
		$textScrolled[$activeWindow]->tagDelete("foundme$i");
	}
	$tagcnt = 0;
	eval {$textScrolled[$activeWindow]->tagDelete("foundme"); };
}

sub revsrtext
{
	my ($s) = $srchTextVar;
	my ($r) = $replText->get;
	$srchTextVar = $r;
	$replText->delete('0','end');
	$replText->insert('end',$s);
}

sub doIndent
{
	my ($doright) = shift;
	my $standAloneBlock = shift;
	&beginUndoBlock($textScrolled[$activeWindow])  if ($standAloneBlock);
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');

	my $spacesperTab = $tabspacing || 3;
	my $tspaces = ' ' x $spacesperTab;
	my $indentStr = $notabs ? $tspaces : "\t";

	$textScrolled[$activeWindow]->markSet('selstart','sel.first linestart - 2 char');
	if ($lastpos =~ /\.0$/o)
	{
		$textScrolled[$activeWindow]->markSet('selend','sel.last - 1 char');
	}
	else
	{
		$textScrolled[$activeWindow]->markSet('selend','sel.last lineend');
	}
	$textScrolled[$activeWindow]->markSet('_prev','insert');
	$textScrolled[$activeWindow]->markSet('insert','selend');
	$clipboard = $textScrolled[$activeWindow]->get('sel.first linestart - 1 char','selend');
	if ($doright == 1)       #SHIFT ALL LINES RIGHT 1 TAB-STOP.
	{
		my @l = split(/\n/o, $clipboard, -1);
		for (my $i=0;$i<=$#l;$i++)
		{
			$l[$i] = $indentStr . $l[$i]  unless ($l[$i] !~ /\S/o || ($l[$i] =~ /^(?:\#.*|\w+(?:\:\s*\;\s*)?)$/o && $l[$i] !~ /^else\s*$/io));
		}
		$clipboard = join("\n", @l);
	}
	else                     #SHIFT ALL LINES LEFT 1 TAB-STOP OR 3 SPACES.
	{
		$clipboard =~ s/\n(\t|$tspaces)/\n/g;
	}
	$textScrolled[$activeWindow]->delete('sel.first linestart - 1 char','selend');
	$textScrolled[$activeWindow]->insert('insert',$clipboard);
	$textScrolled[$activeWindow]->tagAdd('sel','selstart + 2 char','selend + 1 char');
	$textScrolled[$activeWindow]->markSet('insert', 'sel.first');
	&endUndoBlock($textScrolled[$activeWindow])  if ($standAloneBlock);
}

sub setcase
{
	my ($whichflag) = shift;
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');

	eval
	{
		$textScrolled[$activeWindow]->markSet('selstart','sel.first');
		$textScrolled[$activeWindow]->markSet('selend','sel.last');
		$textScrolled[$activeWindow]->markSet('_prev','insert');
		$textScrolled[$activeWindow]->markSet('insert','selend');
		$clipboard = $textScrolled[$activeWindow]->get('sel.first','selend');
		if ($whichflag)    #CONVERT ALL TEXT TO LOWER-CASE.
		{
			$clipboard =~ tr/A-Z/a-z/;
		}
		else               #CONVERT ALL TEXT TO UPPER-CASE.
		{
			$clipboard =~ tr/a-z/A-Z/;
		}
		$textScrolled[$activeWindow]->delete('sel.first','selend');
		$textScrolled[$activeWindow]->insert('insert',$clipboard);
		my ($l) = length($clipboard);
		$textScrolled[$activeWindow]->tagAdd('sel',"selend - $l char",'selend');
	}
}

sub cnvert
{
	my ($whichflag) = shift;
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');

	eval
	{
		$textScrolled[$activeWindow]->markSet('selstart','sel.first');
		$textScrolled[$activeWindow]->markSet('selend','sel.last');
		$textScrolled[$activeWindow]->markSet('_prev','insert');
		$textScrolled[$activeWindow]->markSet('insert','selend');
		$clipboard = $textScrolled[$activeWindow]->get('sel.first','selend');
		if ($whichflag == 1)    #CONVERT ALL TEXT HEX CONSTANTS.
		{
			$clipboard =~ s/(.)/'\x'.sprintf('%02x',ord($1))/seg;
			$clipboard =~ s/\\x([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]+)/'\x{'.sprintf('%04d',$1).'}'/seg;
		}
		elsif ($whichflag == 2)    #ESCAPE ALL PERL REGEX CHARS:
		{
			$clipboard =~ s#([\/\\\.\*\+\?\|\(\)\[\]\{\}\-\=\"\'\$\@\#\!\<\>\~\%\^\&])#\\$1#sg;
		}
		elsif ($whichflag == 3)    #UNESCAPE ALL PERL REGEX CHARS:
		{
			$clipboard =~ s#\\([\/\\\.\*\+\?\|\(\)\[\]\{\}\-\=\"\'\$\@\#\!\<\>\~\%\^\&])#$1#sg;
		}
		elsif ($whichflag == 4)    #UNESCAPE ALL "\\" & \u00## CHARS::
		{
			$clipboard =~ s/\\u00([0-9A-Fa-f]{2})/chr(hex($1))/egs;
			$clipboard =~ s#\\##gs;
		}
		else               #CONVERT ALL HEX CONSTANTS TO TEXT.
		{
			$clipboard =~ s/\\x\{?([0-9A-Fa-f]{2})\}?/chr(hex($1))/seg;
		}
		$textScrolled[$activeWindow]->delete('sel.first','selend');
		$textScrolled[$activeWindow]->insert('insert',$clipboard);
		my ($l) = length($clipboard);
		$textScrolled[$activeWindow]->tagAdd('sel',"selend - $l char",'selend');
	}
}

sub rxescape
{
}

sub gotoErr
{
	my ($errline) = shift;

	my ($errsel) = undef;
	eval
	{
		$errsel = $MainWin->SelectionGet(-selection => 'PRIMARY');
	}
	;
	$errline = $errsel  if ($errsel);
	$errline =~ s/\D//go;
	&gotoMark($textScrolled[$activeWindow], $errline);
}

sub doSaveXXXX
{
	my ($mytitle) = "File to save results:";
	my ($create) = 1;
	my ($fileDialog) = $MainWin->JFileDialog(
			-Title =>$mytitle,
			-Path => $startpath,
			-History => (defined $histmax) ? $histmax : 20,
			-HistFile => $histFile,
			-PathFile => $pathFile,
			-HistDeleteOk => 1,
			-HistUsePath => (defined $histpath) ? $histpath : -1,
			-HistUsePathButton => $histpathbutton,
			-DestroyOnHide => $Steppin,
			-Create => $create);

	my ($myfile) = $fileDialog->Show(-Horiz=>0);
	&fixAfterStep()  if ($Steppin);
   	$startpath = $fileDialog->getLastPath();
	$histpathbutton = $fileDialog->getHistUsePathButton();
	if ($myfile =~ /\S/o && open(OUTFID, ">$myfile"))
	{
		binmode OUTFID;
		$_ = $text2Scrolled->get('0.0','end');
		chomp;
		s/\r\n/\n/go;
		if ($opsys eq 'DOS')
		{
			s/\n/\r\n/go;
	  	}
		elsif ($opsys eq 'Mac')
		{
			s/\n/\r/go;
		}
		print OUTFID;
		close OUTFID;
		&setStatus("..Results saved to file: \"$myfile\".");
		return (0);
	}
	else
	{
		$errDialog->configure(
				-text => "doSave: Could not save \"$myfile\" ($!)!");
		$errDialog->Show($showgrabopt);
		&setStatus("doSave:COULD NOT SAVE TO \"$myfile\"!");
		print "e:doSave:COULD NOT SAVE RESULTS TO \"$myfile\"!\n";
		return (1);
	}
}

#t sub savexFn
#t {
#t 	&exitFn($Yes);
#t }

sub clearMarks
{
	my $lastMenuItem = $markMenubtn->menu->index('end');
	$markMenubtn->menu->delete($markMenuTop+1,'end')  if ($lastMenuItem > $markMenuTop);
	foreach my $i (keys %{$markHash{$activeTab}[$activeWindow]})    #DELETE MARKS FOR THIS WINDOW.
	{
		delete $markHash{$activeTab}[$activeWindow]->{$i};
		delete $markWidget{$activeTab}[$activeWindow]{$i};
		$markMenuIndex{$activeTab}[$activeWindow][$markMenuHash{$activeTab}[$activeWindow]{$i}->{index}] = 0;
		delete $markMenuHash{$activeTab}[$activeWindow]{$i};
		$textScrolled[$activeWindow]->markUnset($i);
	}
	for (my $i=0;$i<=$#{$markMenuIndex{$activeTab}[$activeWindow]};$i++)
	{
		if ($markMenuIndex{$activeTab}[$activeWindow][$i] && $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]})
		{
			$markMenubtn->command(
					-label => $markMenuIndex{$activeTab}[$activeWindow][$i],
					-underline => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]}->{underline} || '0',
					-command => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]}->{command});
		}
	}
	$marklist{$activeTab}[$activeWindow] = ':insert:sel:';
}

sub resetMarks
{
	return unless (defined $markMenubtn);
	my $lastMenuItem = $markMenubtn->menu->index('end');
	$markMenubtn->menu->delete($markMenuTop+1,'end')  if ($lastMenuItem > $markMenuTop);
	for (my $i=0;$i<=$#{$markMenuIndex{$activeTab}[$activeWindow]};$i++)
	{
		if ($markMenuIndex{$activeTab}[$activeWindow][$i] && $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]})
		{
			$markMenubtn->command(
					-label => $markMenuIndex{$activeTab}[$activeWindow][$i],
					-underline => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]}->{underline} || '0',
					-command => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]}->{command});
		}
	}
}

sub addMark
{
	$intext = shift;
	$mkPosn = shift || 'insert';
	&gettext("Mark Name:",20,'t',2)  unless ($intext);
	$intext = '_Bookmark'  unless ($intext =~ /^[_a-zA-Z0-9]/o);
	unless ($intext eq  '*cancel*')
	{
		unless ($intext !~ /\S/o || $marklist{$activeTab}[$activeWindow] =~ /\:$intext\:/)
		{
			($intext,$ul) = split(/\,/o, $intext);
			$ul = 0  unless ($ul =~ /^\d+$/o);
			$ul = 4  if (!$ul && !$filetype && $intext =~ /^sub /o);
			#EVAL SO THAT "$intext" IS SET STATICALLY!
			$markWidget{$activeTab}[$activeWindow]{$intext} = $textScrolled[$activeWindow];
			#########eval { $markMenubtn->menu->delete($intext); };
			$activeWindow = 0  unless ($activeWindow =~ /\d/o);
			$evalstr = "
					\$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{index} = \$markNextIndex{\"$activeTab\"}[$activeWindow];
					\$markMenuIndex{\"$activeTab\"}[$activeWindow][\$markNextIndex{\"$activeTab\"}[$activeWindow]] = \"$intext\";
					\$markNextIndex{\"$activeTab\"}[$activeWindow]++;
					\$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{underline} = \$ul || '0';
					\$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{tab} = \"$activeTab\";
					\$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{command} = sub
					{
						\$tabbedFrame->raise(\$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{tab})  unless (\$nobrowsetabs);
						\$markWidget{\"$activeTab\"}[$activeWindow]{\"$intext\"}->markSet('_prev','insert');
						\$markWidget{\"$activeTab\"}[$activeWindow]{\"$intext\"}->markSet('insert',\"$intext\");
						my (\$gotopos) = \$markWidget{\"$activeTab\"}[$activeWindow]{\"$intext\"}->index('insert');

						\$markWidget{\"$activeTab\"}[$activeWindow]{\"$intext\"}->see(\$gotopos);
						\&setStatus(\"Cursor now at \$gotopos.\");
						\$markWidget{\"$activeTab\"}[$activeWindow]{\"$intext\"}->focus;
					};
					\$markMenubtn->command(
						-label => '$intext',
						-underline => \$ul,
						-command => \$markMenuHash{\"$activeTab\"}[$activeWindow]{\"$intext\"}->{command}
					);
			";
			eval $evalstr  unless ($markMenuHash{$activeTab}[$activeWindow]{$intext});
			$marklist{$activeTab}[$activeWindow] .= ':' . $intext . ':';
		}
		$textScrolled[$activeWindow]->markSet("$intext",$mkPosn);
		delete $markHash{$activeTab}[($activeWindow ? 0 : 1)]->{$intext};
		$marklist{$activeTab}[($activeWindow ? 0 : 1)] =~ s/\Q\:$intext\E\://;
		$markHash{$activeTab}[$activeWindow]->{$intext} = $intext;
		my ($markpos) = $textScrolled[$activeWindow]->index($mkPosn);
		$markMenuHash{$activeTab}[$activeWindow]{$intext}->{markposn} = $markpos;
		&setStatus("Mark \"$intext\" set to $markpos.");
	}
}

sub gettext
{
	my ($header,$sz,$typ,$mk,$mylist,$preload,$csr) = @_;

	my ($clipboard);
	$inlist = '';

	if ($mylist != 1)   #1ST TRY PRIMARY SELECTION.
	{
		eval
		{
			$clipboard = $MainWin->SelectionGet(-selection => 'PRIMARY');
		}
		;
		unless (length($clipboard) > 0)  #ADDED 20080426 - NEXT TRY "FOUND" TEXT (HANDY FOR MARKS)!
		{
			eval
			{
				$clipboard = $textScrolled[$activeWindow]->get('foundme.first','foundme.last');
			}
		}
	}
	unless (length($clipboard) > 0)  #LAST, TRY THE CLIPBOARD.
	{
		eval
		{
			$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
		}
		;
	}

	if (Exists($textPopup))
	{
		$MainWin->focus()  if ($Steppin);
#print DEBUG "-4--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
		$textPopup->destroy;
		$MainWin->raise()  if ($Steppin);
	}
	$textPopup = $MainWin->Toplevel;
	$textPopup->title($header);
	$textPopup->transient($MainWin);
	my $getText = $textPopup->Entry(
			-relief => 'sunken',
			-width  => $sz);
	$getText->insert('end',$intext)  if ($preload);
	$getText->icursor($getText->index($csr))  if ($csr);
	$getText->bind('<FocusIn>' => sub { $curTextWidget = shift;} );
#x	$getText->bind('<Alt-v>' => sub
#x	{
#x		eval
#x		{
#x			$curTextWidget->insert('insert',
#x					$MainWin->SelectionGet(-selection => 'PRIMARY'));
#x		}
#x	}
#x	);

	if ($typ eq 'p')
	{
		$getText->configure(
				-show   => '*');
	}

	if ($mylist && $mylist != 1)
	{
		$listFrame = $textPopup->Frame;
#x		$chooseOption = $listFrame->JOptionmenu(
#x				-textvariable => \$inlist,
#x				-command => [\&dobuttons, $textPopup, $getText, 0],
#x				-highlightthickness => 2,
#x				-takefocus => 1,
#x				-options => $mylist,
#x		)->pack;
		$chooseOption = $listFrame->JBrowseEntry(
				-textvariable => \$inlist,
				-state => 'normal',
				-browsecmd => [\&dobuttons, $textPopup, $getText, 0],
				-highlightthickness => 2,
				-takefocus => 1,
###				-browse => 1,
				-choices => $mylist,
		)->pack;
	}
	my $btnframe = $textPopup->Frame;

	my $okButton = $btnframe->Button(
			-padx => 12,
			-pady =>  6,
			-text => 'Ok',
			-underline      => 0,
			-command => [\&dobuttons, $textPopup, $getText, 0]);
	$okButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');

	if ($mk == 1)
	{
		my $prvbutton = $btnframe->Button(
				-padx => 12,
				-pady =>  6,
				-text => 'Back',
				-underline      => 0,
				-command => [\&dobuttons, $textPopup,$getText, 2]);
		$prvbutton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
	}
	elsif ($mk == 2)
	{
		my $prvbutton = $btnframe->Button(
				-padx => 12,
				-pady =>  6,
				-text => 'Line',
				-underline      => 0,
				-command => sub
		{
			$curTextWidget->insert('insert',(
					$textScrolled[$activeWindow]->index('insert')));
		}
		);
		$prvbutton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
	}

	my $pasteButton = $btnframe->Button(
			-pady => 6,
			-text => 'Paste',
			-underline => 0,
			-command => sub
	{
		eval {$curTextWidget->insert('insert',$clipboard);}  if (defined($clipboard));
	}
	);
	$pasteButton->configure(-state => 'disabled')  unless (defined($clipboard));

	$pasteButton->pack(-side=>'left', -expand=>1, -pady=> '2m');

	my $canButton = $btnframe->Button(
			-padx => 12,
			-pady =>  6,
			-text => 'Cancel',
			-underline      => 0,
			-command => [\&dobuttons, $textPopup,$getText, 1]);
	$canButton->pack(-side=>'right', -expand=>1, -padx=>'2m', -pady=>
	'2m');

	my ($btnframe2, $insButton, $sel0Button, $sel1Button);
	if ($mk == 1)
	{
		$markSelected = '';
		$btnframe2 = $textPopup->Frame;

		$insButton = $btnframe2->Button(
				-padx => 6,
				-pady =>  6,
				-text => 'Insert',
				-underline      => 0,
				-command => [\&dobuttons, $textPopup, $getText, 3]);
		$insButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
		$sel0Button = $btnframe2->Button(
				-padx => 6,
				-pady =>  6,
				-text => 'Sel.First',
				-underline      => 4,
				-command => [\&dobuttons, $textPopup, $getText, 4]);
		$sel0Button->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
		$sel1Button = $btnframe2->Button(
				-padx => 6,
				-pady =>  6,
				-text => 'Sel.Last',
				-underline      => 4,
				-command => [\&dobuttons, $textPopup, $getText, 5]);
		$sel1Button->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
		$endButton = $btnframe2->Button(
				-padx => 6,
				-pady =>  6,
				-text => 'End',
				-underline      => 0,
				-command => [\&dobuttons, $textPopup, $getText, 6]);
		$endButton->pack(-side=>'left', -expand=>1, -padx=>'2m', -pady=>'2m');
		my @markChoices = ('','0.0','end','_prev',split(/\:+/o, substr($marklist{$activeTab}[$activeWindow],13)));
		$markList = $textPopup->JBrowseEntry(
#				-state => 'readonly',
				-label => 'Select to mark:',
				-choices => \@markChoices,
				-altbinding => 'Nolistbox=listbox.space',
				-textvariable => \$markSelected,
				-browsecmd => [\&select2Mark]
				);
	}
	$getText->pack(
			-padx   => 12,
			-pady   => 12,
			-side   => 'top');
				#-expand => 'yes',
				#-fill   => 'x');
	$listFrame->pack  if ($mylist && $mylist != 1);
	$markList->pack(-side => 'bottom', -fill => 'x')  if ($mk == 1);
	$btnframe2->pack(-side => 'bottom', -fill => 'x')  if ($mk == 1);
	$btnframe->pack(-side => 'bottom', -fill => 'x');
	$getText->bind('<Return>'       => [$okButton => "Invoke"]);
	$getText->bind('<Escape>'       => [$canButton => "Invoke"]);
#1	$textPopup->focus();
#1	$getText->focus();
	if ($Steppin) {  #JWT:ADDED 20140606 B/C TO GET AFTERSTEP TO GIVE "TRANSIENT" WINDOWS THE FOCUS?!
		$textPopup->waitVisibility;  #WAIT HERE FOR USER RESPONSE!!!
#		DoOneEvent(ALL_EVENTS);
		select(undef, undef, undef, 0.1);  #FANCY QUICK-NAP FUNCTION!
	}
	$getText->focus();
	$textPopup->waitWindow;  #WAIT HERE FOR USER RESPONSE!!!
}

sub select2Mark
{
	my $start = $textScrolled[$activeWindow]->index('insert');
	my $useXmark = 0;
	if ($markSelected =~ /^\s*[\+\-]\d+/o)
	{
		$markSelected =~ s/\..*$//o;
		eval
		{
			$textScrolled[$activeWindow]->markSet('_xmark',"insert $markSelected lines");
			$useXmark = 1;
		}
		;
	}
	elsif ($markSelected =~ /^[\d\.]+$/o)
	{
		$markSelected .= '.0'  if ($markSelected =~ /^\d+$/o);
		$textScrolled[$activeWindow]->markSet('_xmark',$markSelected);
		$useXmark = 1;
	}
	my $end = $textScrolled[$activeWindow]->index($markSelected);
	($end > $start) ? $textScrolled[$activeWindow]->tagAdd('sel', 'insert', ($useXmark ? '_xmark' : $markSelected))
			: $textScrolled[$activeWindow]->tagAdd('sel', ($useXmark ? '_xmark' : $markSelected), 'insert');
	$MainWin->focus()  if ($Steppin);
#print DEBUG "-8--TOMARK=$markSelected= START=$start= END=$end= AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	if (Exists($textPopup))
	{
		eval { $textPopup->destroy };  #JWT:NOTE, THIS CAN CAUSE A WARNING DUMP FROM JBROWSEENTRY BEING SUDDENLY KILLED!
	}
	$MainWin->raise()  if ($Steppin);
	$textScrolled[$activeWindow]->markSet('_prev', $start);
	$textScrolled[$activeWindow]->markSet('insert', $end);
	$textScrolled[$activeWindow]->see('insert');
	&setStatus( "Cursor now at $end.");
	$intext = '*cancel*';   #CANCEL DOGOTO (WE'RE THERE).
	$markSelected = '';
}

sub dobuttons
{
	($xPopup, $xText, $abort) = @_;

	if ($abort == 1)
	{
		$intext = '*cancel*';
	}
	elsif ($abort == 2)
	{
		$intext = '_prev';
	}
	elsif ($abort == 3)  #GOTO 'INSERT' CURSOR.
	{
		$intext = $textScrolled[$activeWindow]->index('insert');
	}
	elsif ($abort == 4)  #GOTO 'SEL.START'.
	{
		$intext = '*cancel';
		eval {$intext = $textScrolled[$activeWindow]->index('sel.first'); };
		$intext ||= '*cancel*';
	}
	elsif ($abort == 5)  #GOTO 'SEL.END'.
	{
		$intext = '*cancel*';
		eval {$intext = $textScrolled[$activeWindow]->index('sel.last'); };

		$intext ||= '*cancel*';
	}
	elsif ($abort == 6)  #GOTO 'END'.
	{
		$intext = $textScrolled[$activeWindow]->index('end');
	}
	else
	{
		$intext = $xText->get;
	}
	$MainWin->focus()  if ($Steppin);
#print DEBUG "-9--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	$xPopup->destroy;
	$MainWin->raise()  if ($Steppin);
}

sub gotoMark
{
	my ($self,$intext,$ops) = @_;

	$intext .= '.0'  if ($intext =~ /^\d+$/o);
	my $xtra = ($ops =~ /append/io) ? 1 : 0;
	eval 
	{
		if ($markWidget{$activeTab}[$activeWindow]{$intext})
		{
			$markWidget{$activeTab}[$activeWindow]{$intext}->focus;
			$markWidget{$activeTab}[$activeWindow]{$intext}->markSet('_xprev','_prev')  if ($intext eq '_prev');
			$markWidget{$activeTab}[$activeWindow]{$intext}->markSet('_prev','insert');
			$intext = '_xprev'  if ($intext eq '_prev');
			$markWidget{$activeTab}[$activeWindow]{$intext}->markSet('insert',$intext);
			my ($gotopos) = $markWidget{$activeTab}[$activeWindow]{$intext}->index('insert');

			$markWidget{$activeTab}[$activeWindow]{$intext}->see($gotopos);
		}
		else
		{
			$textScrolled[$activeWindow]->focus;
			$textScrolled[$activeWindow]->markSet('_xprev','_prev')  if ($intext eq '_prev');
			$textScrolled[$activeWindow]->markSet('_prev','insert');
			$intext = '_xprev'  if ($intext eq '_prev');
			$textScrolled[$activeWindow]->markSet('insert',$intext);
			my ($gotopos) = $textScrolled[$activeWindow]->index('insert');

			$textScrolled[$activeWindow]->see($gotopos);
		}
		$gotopos = $textScrolled[$activeWindow]->index('insert')
				unless ($gotopos =~ /\S/o);
		&setStatus("Cursor now at $gotopos.", $xtra);
	};
}

sub doGoto
{
	&gettext("Go To (line#.col#):",20,'t',1);
	unless ($intext eq  '*cancel*')
	{
		$intext = '0'  unless ($intext =~ /\S/o);
		$intext .= '0'   if ($intext =~ /^\d+\.$/o);
		if ($intext =~ /^\s*[\+\-]/o)
		{
			$intext =~ s/\..*$//o;
			eval
			{
				$textScrolled[$activeWindow]->markSet('_prev','insert');
				$textScrolled[$activeWindow]->markSet('insert',"insert $intext lines");
			}
			;
		}
		elsif ($intext || $markSelected !~ /\S/o)
		{
			$intext .= '.0'  if ($intext =~ /^\d+$/o);
			eval
			{
				$textScrolled[$activeWindow]->markSet('_xprev','_prev')  if ($intext eq '_prev');
				$textScrolled[$activeWindow]->markSet('_prev','insert');
				$intext = '_xprev'  if ($intext eq '_prev');
				$textScrolled[$activeWindow]->markSet('insert',$intext);
			}
			;
		}
		&select2Mark()  if ($markSelected =~ /\S/o);
		my $gotopos = $textScrolled[$activeWindow]->index('insert');
		$textScrolled[$activeWindow]->see('insert');
		&setStatus("Cursor now at $gotopos.");
	}		
}

sub GlobalSrchRep
{
	my ($whichTextWidget) = shift;
	my ($markAllMatches) = shift || 0;

	my ($wholething) = undef;

	eval { $whichTextWidget->tagAdd('sel', 'savesel.first', 'savesel.last'); };
print STDERR "-5- GlobalSrchRep: markall=$markAllMatches=\n"  if ($debug);
	$findMenubtn->entryconfigure('Search Again', -state => 'normal');
	$findMenubtn->entryconfigure('Search Forward >', -state => 'normal');
	$findMenubtn->entryconfigure('Search Backward <', -state => 'normal');
	$findMenubtn->entryconfigure('Modify search', -state => 'normal');
	$srchstr = $srchTextVar;
#XXX	return  unless ($srchstr =~ /\S/);
	return  unless (length $srchstr);

	$replstr = '';
	eval { $replstr = (defined $replText) ? $replText->get : ''; };
	$MainWin->focus()  if ($Steppin);
print STDERR "-10--AW=$activeWindow= AT=$activeTab= scr0=$textScrolled[0]=\n"  if ($debug);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
	$xpopup->destroy  if (Exists($xpopup));
	$MainWin->raise()  if ($Steppin);
	$againButton->configure(-state => 'normal');
	$bkagainButton->configure(-state => 'normal');
	for ($i=1;$i<=$tagcnt;$i++)
	{
		$whichTextWidget->tagDelete("foundme$i");
	}
	$tagcnt = 0;

	eval
	{
		$wholething = $whichTextWidget->get('sel.first','sel.last');
		$selstart = $whichTextWidget->index('sel.first');
		$selend = $whichTextWidget->index('sel.last');
	}
	;
	unless (defined($wholething))
	{
		#$wholething = $whichTextWidget->get('0.0','end');
		$selstart = '0.0';
		$selend = $whichTextWidget->index('end');
print STDERR "-10- NOT whole thing, start=$selstart, end=$selend, replstr=$replstr=\n"  if ($debug);
		if (length($replstr))
		{
			$replDialog->configure(
					-text => "Replace\n\"$srchstr\"\nwith\n\"$replstr\"\nin Entire file?");
			$usrres = $replDialog->Show();
			return (1)  unless ($usrres eq $Yes);
		}
	}
	$whichTextWidget->markSet('selstartmk',$selstart);
	$whichTextWidget->markSet('selendmk',$selend);

	my ($replstrx) = $replstr;
	$replstrx = ''  if ($replstr eq '``');  #TREAT '' AS EMPTY STR!
	$srchpos = $selstart;
	&beginUndoBlock($whichTextWidget);
#DECIDED BETTER TO SHOW HIGHLIGHTING AS IT GOES:	if ($editor =~ /TextHighlight/o || $viewer =~ /TextHighlight/o)
#	{
#		eval { $textScrolled[$activeWindow]->blockHighlighting(1); };
#	}
$textScrolled[$activeWindow]->markSet('_prev','insert');
print STDERR "--srchstr WAS=$srchstr=\n"  if ($debug);
	#NOTE:  TO DELETE ENTIRE LINES THAT CONTAIN SEARCH-STR, SPECIFY LIKE:
	#".+PATTERN\n", REPLACE="``", AND SELECT "REGULAR-EXPRESSION!:
	my $hasEOL = ($srchstr =~ s/\\n$/\$/s) ? ' + 1 char' : '';
print STDERR "--HASEOL=$hasEOL= srchstr NOW=$srchstr=\n"  if ($debug);
	while (1)
	{
		$srchpos = $whichTextWidget->search(-forwards, $srchopts, -count => \$lnoffset, '--', $srchstr, $srchpos, 'end');
		last  if not $srchpos;
		$selend = $whichTextWidget->index('selendmk');
		last  if ($srchpos > $selend);
		$whichTextWidget->markSet('insert',$srchpos);
		$whichTextWidget->see($srchpos);
		$whichTextWidget->tagDelete('foundme');
		$whichTextWidget->tagAdd('foundme', $srchpos, "$srchpos + $lnoffset char");
		$whichTextWidget->tagConfigure('foundme',
				-relief => 'raised',
				-borderwidth => 1,
				-background  => 'yellow',
				-foreground     => 'black');
		$chgstr = $whichTextWidget->get('foundme.first','foundme.last');
print STDERR "--CHGSTR WAS=$chgstr= replstr=$replstr=\n"  if ($debug);
		&addMark($chgstr)  if ($markAllMatches);
		if (length($replstr))
		{
			if ($srchopts eq '-regexp')
			{
				$_ = $replstrx;   #ADDED NEXT 7 20010924.
				s/\:\#([+-]\d+)?/
						my ($offset) = $1;
						my $str = $tagcnt+($offset);
						"$str"
				/eg;
				$chgstr =~ s/$srchstr/eval "return \"$replstrx\""/egs;
print STDERR "--REGEXP: CHGSTR NOW=$chgstr= FM=$srchstr= TO=$replstrx=\n"  if ($debug);
			}
			elsif ($srchopts eq '-nocase')
			{
				$chgstr =~ s/\Q$srchstr\E/$replstrx/eigs;
print STDERR "--NOCASE: CHGSTR NOW=$chgstr= FM=$srchstr= TO=$replstrx=\n"  if ($debug);
			}
			else
			{
				$chgstr =~ s/\Q$srchstr\E/$replstrx/egs;
print STDERR "--CASE: CHGSTR NOW=$chgstr= FM=$srchstr= TO=$replstrx=\n"  if ($debug);
			}
		}
		$whichTextWidget->delete('foundme.first',"foundme.last$hasEOL");
		$whichTextWidget->insert('insert',$chgstr);
		$whichTextWidget->tagDelete('foundme');
		$lnoffset = length($chgstr);
		++$tagcnt;
		$whichTextWidget->tagAdd("foundme$tagcnt", $srchpos, "$srchpos + $lnoffset char");
		$whichTextWidget->tagConfigure("foundme$tagcnt",
				-relief => 'raised',
				-borderwidth => 1,
				-background  => 'green',
				-foreground     => 'black');
		$srchpos = $whichTextWidget->index("$srchpos + $lnoffset char");
	}
#	if ($editor =~ /TextHighlight/o || $viewer =~ /TextHighlight/o)
#	{
#		eval { $textScrolled[$activeWindow]->blockHighlighting(0); };
#	}
	&endUndoBlock($whichTextWidget);
	my $chgd = (length($replstr) > 0) ? '/changed' : '';
	&setStatus( "..$tagcnt matches of \"$srchstr\" found${chgd}!");
	$whichTextWidget->tagAdd('sel', 'selstartmk', 'selendmk');

}

sub shocoords
{
	my ($calledbymouse) = shift;
#	$text1Text->SUPER::mouseSelectAutoScanStop;    #ADDED FOR SUPERTEXT!
	$whichTextWidget->mouseSelectAutoScanStop  if ($SuperText && $calledbymouse && !$v);
	my ($gotopos) = $textScrolled[$activeWindow]->index('insert');
	$textScrolled[$activeWindow]->see($gotopos);
	&setStatus( $gotopos);
}

sub setwrap
{
	my $wrap = shift || 'none';
	$whichTextWidget->configure(-wrap => $wrap);
}

sub print_couples
{
	my $w = shift;

	my $s=$w->cget('-matchingcouples');
	print (defined $s ? $s :'undef');
	print "\n";
}

sub showlength
{
	$clipboard = '';
	eval {$clipboard = $textScrolled[$activeWindow]->get('sel.first','sel.last');};

	$clipboard = $textScrolled[$activeWindow]->get('0.0','end')  unless ($clipboard);
	&setStatus( 'Length = '.length($clipboard));
}

sub showSum
{
	$clipboard = '';
	eval {$clipboard = $textScrolled[$activeWindow]->get('sel.first','sel.last');};

	$clipboard = $textScrolled[$activeWindow]->get('0.0','end')  unless ($clipboard);
	my @l = split(/\n/o, $clipboard, -1);
	my $columncnt = 0;
	my @sums = ();
	my $columnsnotequal = 0;
	for (my $i=0;$i<=$#l;$i++)
	{
		@numbers = ();
		$j = 0;
		while ($l[$i] =~ s/([\d\+\-\.]+)//o)
		{
			$sums[$j++] += $1;
		}
		if ($columncnt != $j)
		{
			$columnsnotequal = $i  if ($columncnt && $j);
			$columncnt = $j  if ($columncnt < $j);
		}
	}
	$_ = "\tTOTAL:  \t" . join("\t", @sums) . "\n";
$textScrolled[$activeWindow]->markSet('_prev','insert');
	$textScrolled[$activeWindow]->markSet('insert','end');
	eval { $textScrolled[$activeWindow]->markSet('insert','sel.last'); };
	$textScrolled[$activeWindow]->insert('insert',$_);
	&setStatus( 
			"w:No. of Columns NOT EQUAL at row: $columnsnotequal, right-padded w/zeros!")
		if ($columnsnotequal);
}

sub showTime
{
	unless ($haveTime2fmtstr) {
		$haveTime2fmtstr = -1;
		eval "use Date::Time2fmtstr; \$haveTime2fmtstr = 1; 1";
	}
	unless ($haveTime2fmtstr == 1) {
		&setStatus('-showTime requires Date::Time2fmtstr installed!');
		return;
	}

	my $timestring = '';
	my $clipboard = '';
	eval {
		$textScrolled[$activeWindow]->markSet('selstart','sel.first');
		$textScrolled[$activeWindow]->markSet('selend','sel.last');
		$textScrolled[$activeWindow]->markSet('_prev','insert');
		$textScrolled[$activeWindow]->markSet('insert','selend');
		$clipboard = $textScrolled[$activeWindow]->get('sel.first','selend');
	};
#x	eval {$clipboard = $textScrolled[$activeWindow]->get('sel.first','sel.last');};

	$timefmt ||= 'yyyy-mm-dd hh:mi:ss PM';
	if ($clipboard) {
		if ($clipboard =~ /^[0-9]{9,11}$/o) {
			$timestring = time2str($clipboard, $timefmt);
			if (!$v && $timestring) {
				$replDialog->configure(
						-text => "Replace\n\"$clipboard\"\nwith\n\"$timestring\"?");
				my $usrres = $replDialog->Show();
				if ($usrres eq $Yes) {
					$clipboard = $timestring;
					$textScrolled[$activeWindow]->delete('sel.first','selend');
					$textScrolled[$activeWindow]->insert('insert',$clipboard);
					my ($l) = length($clipboard);
					$textScrolled[$activeWindow]->tagAdd('sel',"selend - $l char",'selend');
				}
			}
			$timestring ||= "-Invalid time highlighted ($clipboard)-";
			&setStatus($timestring);
		} elsif (!$v) {
			my $askedAlready = 0;
			my $cnt = 0;
			my $usrres = '';
			while ($clipboard =~ /([0-9]{9,11})/o) {
				my $tm = $1;
				$timestring = time2str($tm, $timefmt);
				if ($timestring) {
					unless ($askedAlready)
					{
						$replDialog->configure(
								-text => "Replace\n\"$tm\" (et. al!)\nwith corresponding\n\"$timefmt\"?");
						$usrres = $replDialog->Show();
					}
					if ($usrres eq $Yes) {
						$clipboard =~ s/$tm/$timestring/;
						++$cnt;
						$askedAlready = 1;
					} else {
						last;
					}
				
				} else {
					$timestring ||= '-Invalid time highlighted-';
					last;
				}
			}
			if ($askedAlready && $cnt)
			{
				$textScrolled[$activeWindow]->delete('sel.first','selend');
				$textScrolled[$activeWindow]->insert('insert',$clipboard);
				my ($l) = length($clipboard);
				$textScrolled[$activeWindow]->tagAdd('sel',"selend - $l char",'selend');
				&setStatus("i:$cnt time values changed to formatted string.");
			} else {
				&setStatus('..no time values found/changed in selection.');
			}
		} else {
			&setStatus('..no time values changed in selection (readonly)!');
		}
	} else {
		&setStatus('Current time:  ' . time2str(time, $timefmt));
	}
}

sub reverseit
{
	$clipboard = '';
	eval {$clipboard = $textScrolled[$activeWindow]->get('sel.first','sel.last');};

	my $cln = length($clipboard);
	if ($cln > 1) {
		$textScrolled[$activeWindow]->markSet('insert', 'sel.first');
		&doCut();
		$textScrolled[$activeWindow]->tagDelete('sel');
		$textScrolled[$activeWindow]->SelectionClear();
		$clipboard = reverse($clipboard);
		$textScrolled[$activeWindow]->insert('insert', $clipboard);
		$textScrolled[$activeWindow]->tagAdd('sel', "insert - $cln char", 'insert');
	}
}

sub setFont
{
	my ($myfont) = shift;

	$fixedfont = $fixedfonts[$myfont] || $fixedfonts[1];
	
	$whichTextWidget->configure(-font => $fixedfont);
}

sub setTag
{
	my ($fg) = shift;
	my $selstart;
	eval { $selstart = $textScrolled[$activeWindow]->index('sel.first') or '0.0'; };
	$selstart ||= '0.0';
	my $selend;
	eval { $selend = $textScrolled[$activeWindow]->index('sel.last') or 'end'; };
	$selend ||= 'end';

	if ($fg eq 'clear')
	{
		my @xdump = $textScrolled[$activeWindow]->dump(-tag, $selstart, $selend);
		for ($i=0;$i<=$#xdump;$i+=3)
		{
			if ($xdump[$i] eq 'tagon')
			{
				if ($xdump[$i+1] =~ /^ANSI/o)
				{
					$textScrolled[$activeWindow]->tagRemove($xdump[$i+1], $selstart, $selend);
				}
			}
		}
	}
	elsif ($fg eq 'ul')
	{
		$textScrolled[$activeWindow]->tagAdd("ANSIul", $selstart, $selend);
		$textScrolled[$activeWindow]->tag("configure", "ANSIul", -underline => 1);
	}
	elsif ($fg eq 'bd')
	{
		$textScrolled[$activeWindow]->tagAdd("ANSIbd", $selstart, $selend);
		$textScrolled[$activeWindow]->tag("configure", "ANSIbd", -font => [-weight => "bold" ]);
	}
	elsif (substr($fg,0,1) eq 'b')
	{
		my $color = substr($fg,2);
		$textScrolled[$activeWindow]->tagAdd("ANSI$fg", $selstart, $selend);
		$textScrolled[$activeWindow]->tag("configure", "ANSI$fg","-background" => $color);
	}
	else
	{
		my $color = substr($fg,2);
		$textScrolled[$activeWindow]->tagAdd("ANSI$fg", $selstart, $selend);
		$textScrolled[$activeWindow]->tag("configure", "ANSI$fg","-foreground" => $color);
	}
}

sub setTheme
{
	my ($bg, $fg, $c, $font);
	my $oldfg = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->cget('-foreground');
	my $oldbg = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->cget('-background');
	my ($fgsame, $bgsame);
	$foreground = 0;
	eval $_[0];
	$fgsame = 1  if ($fg =~ s/same//io);
	$bgsame = 1  if ($bg =~ s/same//io);
	my $fgisblack;
	$fgisblack = 1  if ($fg =~ /black/io); #KLUDGE SINCE SETPALETTE/SUPERTEXT BROKE!
	$c = ''  if ($c =~ /same/io);
	if ($c =~ /default/io)
	{
		eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
		my $c0;
		$c0 = $MainWin->optionGet('tkVpalette','*')  if ($v);
		$c0 ||= $MainWin->optionGet('tkPalette','*');
		$c = $c0  if ($c0);
		if ($c)
		{
			$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c);
		}
		$c = '';
	}
	if ($c)
	{
		$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
					: $MainWin->setPalette($c);
		unless ($fg)
		{
			if ($palette)
			{
				$fg = 'green';
			}
			else
			{
				$fg = $MainWin->cget('-foreground');
			}
		}
		unless ($bg)
		{
			if ($palette)
			{
				$bg = 'black';
			}
			else
			{
				$bg = $MainWin->cget('-background');
			}
		}
		unless ($nobrowsetabs)
		{
			my $acbgColor = $MainWin->Palette->{ activeBackground } || 'gray30';    #NEXT 2 MAKE TAB ROW SAME COLOR AS REST OF WINDOW:
#TONE IT DOWN SLIGHTLY:		my $robgColor = $MainWin->Palette->{ readonlyBackground } || 'gray40';
			my $robgColor = $MainWin->Palette->{ disabledForeground } || 'gray40';
			my $bgColor = $MainWin->Palette->{ background };
			my $foColor = $MainWin->Palette->{ foreground };
			$tabbedFrame->configure(-background => $bgColor, -inactivebackground => $robgColor, -backpagecolor => $acbgColor, -focuscolor => $foColor);
		}
	}
	else
	{
		if ($v)
		{
			eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
			$c = $MainWin->optionGet('tkVpalette','*');
#			$c ||= 'bisque3';
			$fg ||= 'black';
#			$bg ||= 'bisque3';
			if ($c)
			{
				$foreground ? $MainWin->setPalette(background => $c, foreground => $foreground)
						: $MainWin->setPalette($c)
			}
		}
		else
		{
			$fg = 'green'  unless ($fg);
			$bg = 'black'  unless ($bg);
			eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
#			$c = $MainWin->optionGet('tkPalette','*');
#			$MainWin->setPalette($c)  if ($c);
		}
	}
	$fgisblack = 1  if ($fg =~ /black/io);
	$fg = $oldfg || 'green'  if ($fgsame);
	$bg = $oldbg || 'black'  if ($bgsame);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-background => $bg)  if ($bg);
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-foreground => $fg)  if ($fgisblack || ($fg && $fg !~ /black/io));
	if ($bummer && $c) {
		$w_menu->configure('-background' => $c, '-foreground' => $fg);
		$asdosButton->configure('-background' => $c);
		$asdosButton->state($asdosButton->state);
	}
	

	#NOW FIX THE TEXT CURSOR!!!!

	my ($red, $green, $blue) = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->rgb(
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->cget('-background'));
#	my @rgb = sort {$b <=> $a} ($red, $green, $blue);
#	my $max = $rgb[0]+$rgb[1];  #TOTAL BRIGHTEST 2.
#	if ($max > 52500)  #LOOKS GOOD FOR ME.
	my $max = $red+1.5*$green+0.5*$blue;
	if ($max > $TwilightThreshold)  #LOOKS GOOD FOR ME.
	{
		$csrFG = "black";      #SPEED LIMIT 70
	}
	else
	{
		$csrFG = "white";      #NIGHT 65
	}
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
			-insertbackground => $csrFG);

	&setFont($font)  if ($font =~ /\d/o);
}

sub accept_drop
{
	my($c, $seln) = @_;
	my $filename;
	my $own =  $c->SelectionExists('-selection'=>$seln);
	my @targ = $c->SelectionGet('-selection'=>$seln,'TARGETS');
	foreach (@targ)
	{
		if (/FILE_NAME/o)
		{
			$filename = $c->SelectionGet('-selection'=>$seln,'FILE_NAME');
			last;
		}
		if ($^O eq 'MSWin32' && /STRING/o)
		{
			$filename = $c->SelectionGet('-selection'=>$seln,$_);
			last;
		} 
	}
	if ($filename)
	{
		$filename =~ s#\\#/#go;  #FIX Windoze FILENAMES!
		&openFn($filename);
	}
}

sub backupFn
{
	my $tofid = shift;   #FID IS NOW THE FILE YOU'RE BACKING UP *TO* IF PASSED IN!
	my $fmfid = shift;   # || $cmdfile{$activeTab}[$activeWindow];

	$fmfid = $cmdfile{$activeTab}[$activeWindow]  if (defined($fmfid) && $fmfid == 1);
	my $nostatus = $tofid ? 1 : 0;

#print DEBUG "-???- backup file=$ebackupFid=\n"  if ($debug);
	if (!$tofid && $ebackupFid && open(T, "<$ebackupFid"))
	{
		binmode T;
		$_ = <T>;
		chomp;
		($backups, $backupct) = split(/\,/o);
		close T;
		++$backupct;
		$backupct = 0  if ($backupct >= $backups);
		$tofid = "$hometmp/e.${backupct}.tmp";
	}
	$tofid ||= 'e.data.tmp';
	$tofid = $hometmp.'/'.$tofid  unless ($tofid =~ m#^(?:\/|\w\:|\\)#o);
	if ($fmfid)
	{
		copy($fmfid, $tofid);   #EMERGENCY PROTECTION!
		eval { `chmod 777 $tofid`; };
	}
	else
	{
		if ($newsupertext || $AnsiColor)
		{
			$_ = $textScrolled[$activeWindow]->getansi('0.0','end');
		}
		else
		{
			$_ = $textScrolled[$activeWindow]->get('0.0','end');
		}
		if (&writedata($tofid, 0, 1, 2))
		{
			&setStatus("..Could not back up file to \"$tofid\"!");
			return $backupct;
		}
	}
	unless ($nostatus)
	{
		if ($ebackupFid && open(T, ">$ebackupFid"))
		{
			print T "$backups,$backupct\n";
			close T;
			&setStatus("..backed up: backup=$backupct.")  if ($backupct =~ /\d/o);
		}
		else
		{
			&setStatus("..Could not save backup information - $?.");
		}
	}
	return $backupct;
}

sub showbkupFn
{
	my $bk = ($backupct =~ /\d/o) ? $backupct : 'data';
	&setStatus("..Last backup file was: \"$hometmp/e.${bk}.tmp\".");
}

sub doMyCopy
{
	&doCopy;
	my $clipboard;
	eval
	{
		$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
	};
	unless (length $clipboard) {   #ADDED 20080426: NOTHING SELECTED, TRY "YELLOW" TEXT:
		eval
		{
			$textScrolled[$activeWindow]->tagAdd('sel', 
					$textScrolled[$activeWindow]->index('foundme.first'), 
					$textScrolled[$activeWindow]->index('foundme.last'));  #ADDED 20080425
			&doCopy;
			$whichTextWidget->tagRemove('sel','0.0','end');
			$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
		};
	}
	$clipboard =~ s/[\r\n].*$//so;
	&setStatus("..copied selected text ("
			.substr($clipboard,0,20)."...) to clipboard.")
		if ($clipboard);		
}

sub doGetFnKey
{
	return  if ($v);
	my $fnkey = $_[scalar(@_)-1];
	my $selected;
	eval
	{
		$selected = $MainWin->SelectionGet(-selection => 'PRIMARY');
	};
	if (defined $selected && length($selected) && $selected ne $fnkeyText[$fnkey])
	{
		if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
		{
			$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,20).'"'), -label => ("F$fnkey: \"".substr($selected,0,20).'"'));
		}
		else
		{
			$fnMenubtn->entryconfigure("F$fnkey: <undef>", -label => ("F$fnkey: \"".substr($selected,0,20).'"'));
		}
		$fnkeyText[$fnkey] = $selected;
		$textScrolled[$activeWindow]->tagDelete('sel');
	}
	else
	{
		if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
		{
			$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,20).'"'), -label => "F$fnkey: <undef>");
		}
		$fnkeyText[$fnkey] = undef;
	}
}

sub doFnKey    #GIVE THE ABILITY TO HAVE UP TO 5 FUNCTION KEYS SAVED WITH STUFF TO PASTE.
{
	return  if ($v);
	my $fnkey = $_[scalar(@_)-1];

	eval { $whichTextWidget->delete('sel.first','sel.last'); };
	$textScrolled[$activeWindow]->tagDelete('foundme');	
	if ($fnkey == 3 && !$SuperText)    #THIS HACK TO FIX BIND ISSUE WITH <F3> (SUPERTEXT GETS THIS RIGHT, THOUGH)!
	{
		my $clipboard = '';
		eval
		{
			$clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD');
		};
		my $l = length($clipboard);
		if ($l > 0)
		{
			eval { $whichTextWidget->delete("insert - $l char",'insert'); };
		}
	}

	$textScrolled[$activeWindow]->insert('insert', $fnkeyText[$fnkey]);
	my $l = length($fnkeyText[$fnkey]);
	$textScrolled[$activeWindow]->tagAdd('foundme', "insert - $l char", 'insert');
	$textScrolled[$activeWindow]->tagConfigure('foundme',
			-relief => 'raised',
			-borderwidth => 1,
			-background  => 'yellow',
			-foreground  => 'black');
	Tk->break;
}

sub doClearFnKeys
{
	for (my $fnkey=1;$fnkey<=12;$fnkey++)
	{
		if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
		{
			$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,20).'"'), -label => "F$fnkey: <undef>");
		}
		$fnkeyText[$fnkey] = undef;
	}
	@fnkeyText = (0);
}

sub doSaveFnKeys
{
	my $anythingDefined = 0;
	for (my $fnkey=1;$fnkey<=12;$fnkey++)
	{
		if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
		{
			$anythingDefined = 1;
			last;
		}
	}
	if ($anythingDefined)
	{
		if (open (OUT, ">${homedir}.myefns"))
		{
			$_ = '';
			for (my $fnkey=1;$fnkey<=12;$fnkey++)
			{
				$_ .= $fnkeyText[$fnkey] . "\x02\n";
			}
			chop; chop;
			print OUT $_;
			close OUT;
		}
	}
	else
	{
		unlink "${homedir}.myefns";
	}
}

sub doLoadFnKeys
{
	@fnkeyText = (0);
	if (open (IN, "${homedir}.myefns"))
	{
		my $fnkey = 1;
		my $s = '';
		while (<IN>)
		{
			$s .= $_;
		}
		close IN;
		my @v = split(/\x02\n/o, $s);
		while (@v)
		{
			$_ = shift(@v);
			if (length($_))
			{
				if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
				{
					$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,20).'"'), -label => ("F$fnkey: \"".substr($_,0,20).'"'));
				}
				else
				{
					$fnMenubtn->entryconfigure("F$fnkey: <undef>", -label => ("F$fnkey: \"".substr($_,0,20).'"'));
				}
				$fnkeyText[$fnkey] = $_;
			}
			else
			{
				if (defined($fnkeyText[$fnkey]) && length($fnkeyText[$fnkey]) > 0)
				{
					$fnMenubtn->entryconfigure(("F$fnkey: \"".substr($fnkeyText[$fnkey],0,20).'"'), -label => "F$fnkey: <undef>");
				}
				$fnkeyText[$fnkey] = undef;
			}
			++$fnkey;
		}
	}
}

sub updateSearchHistory
{
	my $found = 0;
	@srchTextChoices = $srchText->choices();
	return  unless ($srchTextVar =~ /\S/o);
	for (my $i=0;$i<=$#srchTextChoices;$i++)
	{
		if ($srchTextChoices[$i] eq $srchTextVar)
		{
			$found = $i;
			last;
		}
	}
	if ($found)
	{
		my @newlist;
		foreach my $i (@srchTextChoices)
		{
			push(@newlist, $i)  unless ($i eq $srchTextVar);
		}
		@srchTextChoices = @newlist;
	}
	shift(@srchTextChoices);
	unshift(@srchTextChoices, $srchTextVar);
	unshift(@srchTextChoices, '');
	$srchOptChoices{$srchTextVar} = $srchopts;
	$replTextChoices{$srchTextVar} = $replText->get;
}

sub splitScreen
{
	my $openDialog = shift || 0;

	@geometry = ($MainWin->width, $MainWin->height);
	$winGeometry = $MainWin->geometry();
#??	$winGeometry =~ s/[+-].+$//o  if ($ENV{'DESKTOP_SESSION'} =~ /AfterStep/io);  #AFTERSTEP BUG - WANTS TO FORCE TO UPPER-LEFT PART OF DESKTOP?!
	$text1Frame->packPropagate('1');
	$bottomFrame->packPropagate('1');
	$textScrolled[0]->packPropagate('1');
	$textScrolled[1]->packPropagate('1');
	if ($scrnCnts{$activeTab} == 2)
	{
		my ($usrres) = $No;

		my $inActiveWindow = $activeWindow;
		$activeWindow = ($inActiveWindow ? 0 : 1);   #ACTIVE WINDOW IS ONE WE'RE FIXING TO CLOSE!
		my $saveActiveWindowFromFocus = $activeWindow;
		$yncDialog->configure(
				-text => "Save any changes to $cmdfile{$activeTab}[$activeWindow]?");
		$usrres = $yncDialog->Show()  unless($v);
		$activeWindow = $saveActiveWindowFromFocus;
		my ($cancel) = 0;
		$cancel = &saveFn  if ($usrres eq $Yes);
		if (!$cancel && $usrres ne $Cancel)
		{
			#$textScrolled[1]->Subwidget($textsubwidget)->configure(
			#		-height => $height);
			$textAdjuster->packForget();
			$textScrolled[$activeWindow]->packForget();
			$fileMenubtn->entryconfigure('Single screen',  -state => 'disabled');
			$fileMenubtn->entryconfigure('Split screen',  -state => 'normal');
			$textScrolled[$inActiveWindow]->Subwidget($textsubwidget)->configure(
					-height => $height);
			$textScrolled[$inActiveWindow]->configure(
					-height => $height);
			$textScrolled[$activeWindow]->Subwidget($textsubwidget)->configure(
					-height => $height);
			$textScrolled[$activeWindow]->configure(
					-height => $height);
			$textScrolled[$inActiveWindow]->packConfigure(-fill => 'both', -expand => 1);
			$textScrolled[$inActiveWindow]->focus();
			$scrnCnts{$activeTab} = 1;
			my $lastMenuItem = $markMenubtn->menu->index('end');
			$markMenubtn->menu->delete($markMenuTop+1,'end')  if ($lastMenuItem > $markMenuTop);
			foreach my $i (keys %{$markHash{$activeTab}[$activeWindow]})    #DELETE MARKS FOR THIS WINDOW.
			{
				delete $markHash{$activeTab}[$activeWindow]->{$i};
				delete $markWidget{$activeTab}[$activeWindow]{$i};
				$markMenuIndex{$activeTab}[$activeWindow][$markMenuHash{$activeTab}[$activeWindow]{$i}->{index}] = 0;
				delete $markMenuHash{$activeTab}[$activeWindow]{$i};
			}
			for (my $i=0;$i<=$#{$markMenuIndex{$activeTab}[$activeWindow]};$i++)
			{
				if ($markMenuIndex{$activeTab}[$activeWindow][$i] && $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$activeWindow][$i]})
				{
					$markMenubtn->command(
							-label => $markMenuIndex{$activeTab}[$activeWindow][$i],
							-underline => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$i]}->{underline} || '0',
							-command => $markMenuHash{$activeTab}[$activeWindow]{$markMenuIndex{$activeTab}[$i]}->{command});
				}
			}
			$marklist{$activeTab}[$activeWindow] = ':insert:sel:';
			$winGeometry =~ s/x\d+/x$height/;
		}
		$activeWindow = $inActiveWindow;
		$MainWin->title("$titleHeader, ${editmode}ing:  \"$cmdfile{$activeTab}[$activeWindow]\"");
		$MainWin->update;
		if ($nobrowsetabs)
		{
			$MainWin->geometry($winGeometry);
		}
		else  #1ST TAB REQUIRES THIS QUIRKEY GEOMETRY STUFF, OTHERS DON'T!:
		{
			my ($firstTab) = $tabbedFrame->pages;
			$MainWin->geometry($winGeometry)  if ($activeTab eq $firstTab);
		}
	}
	else
	{
		$textScrolled[0]->packForget();
		$textScrolled[1]->packForget();
		if ($nobrowsetabs) {
			$text1Frame->packForget();
		} else {
			$tabbedFrame->packForget();
		}
		$bottomFrame->packForget();
		$fileMenubtn->entryconfigure('Split screen',  -state => 'disabled');
		$fileMenubtn->entryconfigure('Single screen',  -state => 'normal');
		$scrnCnts{$activeTab} = 2;
		($height = $winGeometry) =~ s/^[^x]+x//;
		$height =~ s/[\+\-].*$//;
		my $setHeight =  int($height / 2);
		$textScrolled[0]->Subwidget($textsubwidget)->configure(
				-height => $height - $setHeight);
		$textScrolled[0]->configure(
				-height => $height - $setHeight);
		$textScrolled[1]->Subwidget($textsubwidget)->configure(
				-height => $setHeight);
		$textScrolled[1]->configure(
				-height => $setHeight);
		$MainWin->update;
		$textScrolled[1]->pack(
				-side   => 'bottom',
				-expand => 'yes',
				-fill   => 'both');
		$textScrolled[0]->pack(
				-side   => 'bottom',
				-expand => 'yes',
				-fill   => 'both');
		$textAdjuster->packAfter($textScrolled[1], -side => 'bottom');

		$textScrolled[1]->focus();
		$activeWindow = 1;
		if ($nobrowsetabs) {
			$text1Frame->pack(
					-side		=> 'left',
					-expand	=> 'yes',
					-fill   => 'both',
					-padx   => 2,
					-pady   => 1
			);
		} else {
			$tabbedFrame->pack(
					-side		=> 'left',
					-expand	=> 'yes',
					-fill   => 'both',
					-padx   => 2,
					-pady   => 1
			);
		}
		$bottomFrame->pack(
				-side => 'bottom',
				-fill	=> 'both',
				-expand	=> 'yes');
		$winGeometry =~ s/x\d+/x$setHeight/;
		$MainWin->update;
		if ($nobrowsetabs)
		{
			$MainWin->geometry($winGeometry);
		}
		else  #1ST TAB REQUIRES THIS QUIRKEY GEOMETRY STUFF, OTHERS DON'T!:
		{
			my ($firstTab) = $tabbedFrame->pages;
			$MainWin->geometry($winGeometry)  if ($activeTab eq $firstTab);
		}
		$text1Frame->packPropagate('1');
		$bottomFrame->packPropagate('1');
		$textScrolled[0]->packPropagate('1');
		$textScrolled[1]->packPropagate('1');
		if ($openDialog)
		{
			&openFn()  unless (length($textScrolled[1]->get('1.0','3.0')) > 1);
		}
	}
	$MainWin->update;
	$winGeometry = $MainWin->geometry();
}

sub resetFileType
{
	my $filetype = shift;
	
	unless ($fileTypes{$filetype})
	{
#		$perlMenubtn = undef;
		if ($filetype == 1)
		{
			#eval {require 'e_c.pl';};
			require 'e_c.pl';
		}
		elsif ($filetype == 2)
		{
			#eval {require 'e_htm.pl';};
			require 'e_htm.pl';
		}
		else
		{
			#eval {require 'e_pl.pl';};
			require 'e_pl.pl';
		}
		$fileTypes{$filetype} = 1;
	}
}

sub doColorEditor
{
	unless ($textColorer)
	{
		$textColorer = $MainWin->ColorEditor(-title => 'Select your favorite colors!');
		$textColorer->configure(
				-widgets=> [$text1Text, $textScrolled[$activeWindow]->Descendants])  unless ($bummer);
	}
	$textColorer->Show();
}

sub toClipboard
{
	my $clpbrd = shift;
	$clipboardWidget->delete('0.0', 'end');
	$clipboardWidget->insert('end', $clpbrd);
	$clipboardWidget->tagAdd('sel', '0.0', 'end - 1 char');

	return;
}
sub showFileName
{
	my $fid = $cmdfile{$activeTab}[$activeWindow];
	unless ($fid =~ m#^(?:\/|\w\:)#o)
	{
		$_ = &cwd();
		$_ .= '/'  unless (m#\/$#o || $fid =~ m#^(?:\/|\w\:)#o);
		$fid = $_ . $fid;
		$fid =~ s#\/[^\/]+\/\.\.\/#\/#o;
		$fid =~ s#\/\.\/#\/#o;
	}
	if ($cmdfile{$activeTab}[$activeWindow])
	{
		&setStatus($fid);
		&toClipboard($fid);
	}
	else
	{
		&setStatus('--untitled--');
		&toClipboard('');
	}
	if ($cmdfile{$activeTab}[$activeWindow])   #NOW PUT THE FULL FILENAME INTO THE CLIPBOARD!
	{
		eval {
			$MainWin->SelectionOwn(-selection => 'CLIPBOARD');
			$MainWin->clipboardClear;
			$MainWin->clipboardAppend('--',$fid);
			if (defined($ENV{'CLIPBOARD_FID'}))
			{
				if (open(CLIPBRD,">$ENV{'CLIPBOARD_FID'}"))
				{
					binmode CLIPBRD;
					print CLIPBRD $fid;
					close CLIPBRD;
				}
			};
		};
	}
}

sub setStatus
{
	if (defined $statusLabel)
	{
		if (defined $_[1])
		{
			if ($_[1] == 1)
			{
				my $currentMsg = $statusLabel->cget('-text');
				$currentMsg .= ' ' . $_[0];
				$statusLabel->configure( -text => $currentMsg);
				$saveStatus{$activeTab}[$activeWindow] = $currentMsg;
				return;
			}
		}
		$statusLabel->configure( -text => $_[0]);
		$saveStatus{$activeTab}[$activeWindow] = $_[0];
	}
}

sub toggleNB
{
	if ($nb)
	{
		$nb = 0;
		$fileMenubtn->entryconfigure('Turn on backup',  -label => 'Turn OFF backup');
	}
	else
	{
		$nb = 1;
		$fileMenubtn->entryconfigure('Turn OFF backup',  -label => 'Turn on backup');
	}
}

sub kateExt
{
	my $fid = shift;
	
#	my %extHash = (
#		'.pl' => ($havePerlCool ? 'PerlCool' : 'Perl'),
#		'.htm' => 'Kate::HTML',
#		'.html' => 'Kate::HTML',
#		'.js' => 'Kate::JavaScript',
#		'.java' => 'Kate::Java',
#		'.c' => 'Kate::C',
#		'.h' => 'Kate::C',
#		'.cpp' => 'Kate:Cplusplus',
#		'.sh' => 'Kate::Bash',
#		'.css' => 'Kate::CSS',
#		'.for' => 'Kate::Fortran',
#		'.f77' => 'Kate::Fortran',
#		'.ps' => 'Kate::PostScript',
#		'.py' => 'Kate::Python',
#		'.sql' => 'Kate::SQL',
#		'.tdf' => 'Kate::SQL',
#		'.xml' => 'Kate::XML',
#		'.jsp' => 'Kate::JSP',
#		'.def' => 'Kate::Modulaminus2',
#		'.mod' => 'Kate::Modulaminus2'
#	);

     my $haveKateExt = 0;
	foreach my $e (keys %{$kateExtensions}) {
		$kateExtensions->{$e} = 'HTML'  if ($kateExtensions->{$e} eq 'Kate::HTML');
		$kateExtensions->{$e} = 'Bash'  if ($kateExtensions->{$e} eq 'Kate::Bash');
		print DEBUG "-???- kateExt($e)=$kateExtensions->{$e}= fid=$fid=\n"  if ($debug);
		return $kateExtensions->{$e}  if ($fid =~ /$e/i);
		$haveKateExt = 1;
	}
	return (defined($defaulthighlight) && $defaulthighlight) ? $defaulthighlight : 'None';
}

sub beginUndoBlock
{
	my $whichTextWidget = shift;

	if ($textsubwidget =~ /supertext/io)   #ADDED 20080411 TO BLOCK CHANGES FOR UNDO.
	{
		eval { $whichTextWidget->_beginUndoBlock };
	}
	else
	{
		eval { $whichTextWidget->addGlobStart };
	}
}

sub endUndoBlock
{
	my $whichTextWidget = shift;

	if ($textsubwidget =~ /supertext/io)   #ADDED 20080411 TO BLOCK CHANGES FOR UNDO.
	{
		eval { $whichTextWidget->_endUndoBlock };
	}
	else
	{
		eval { $whichTextWidget->addGlobEnd };
	}
}

sub editfile
{
	for (my $i=0;$i<=1;$i++)
	{
		if ($cmdfile{$activeTab}[$i])
		{
			&saveTags($cmdfile{$activeTab}[$i]);
			&saveMarks($cmdfile{$activeTab}[$i], $i);
		}
	}
	my $curposn = $textScrolled[$activeWindow]->index('insert');
	my $cmd = $0;
	$cmd =~ s/\bv([\w\.]*)/e$1/;
	my $cmdArgs = $cmdfile{$activeTab}[$activeWindow];
	system "$cmd -nb -l=$curposn $cmdArgs &";
}

sub switchPgm
{
	my $switchin2E = shift;

	for (my $i=0;$i<=1;$i++)
	{
		if ($cmdfile{$activeTab}[$i])
		{
			&saveTags($cmdfile{$activeTab}[$i]);
			&saveMarks($cmdfile{$activeTab}[$i], $i);
		}
	}
	my $nb = '-nb';
	unless ($switchin2E)
	{
		return  if (&exitFn($No, 'NOEXIT') eq $Cancel);
		$nb = '';
	}

	my $curposn = $textScrolled[$activeWindow]->index('insert');
	my $cmd = $0;
	my @cmdArgs = ();
#print DEBUG "-???- BEF: cmd=$cmd= sw2e=$switchin2E=\n"  if ($debug);
	if ($switchin2E)
	{
		$cmd =~ s/\bv([\w\.]*)/e$1/;
	}
	else
	{
		my $cmd0 = $cmd;
		$cmd =~ s/\be([\w\.]*)/v$1/;
		unless ((-e $cmd) && (-x $cmd)) {
			$cmd = $cmd0;
			push @cmdArgs, '-v';
		}
	}
#print DEBUG "-???- AFT: cmd=$cmd=\n"  if ($debug);
	if ($nobrowsetabs)
	{
		push (@cmdArgs, $nb)  if ($nb);
		push (@cmdArgs, "-l=$curposn");
		if ($scrnCnts{$activeTab} == 2)
		{
#			exec "\"$cmd\" $nb -l=$curposn -focus=$activeWindow $cmdfile{$activeTab}[0] $cmdfile{$activeTab}[1]";
			push @cmdArgs, "-focus=$activeWindow", $cmdfile{$activeTab}[0], $cmdfile{$activeTab}[1];
		}
		else
		{
#			exec "\"$cmd\" $nb -l=$curposn $cmdfile{$activeTab}[$activeWindow]";
			push @cmdArgs, $cmdfile{$activeTab}[$activeWindow];
		}
	}
	else
	{
		my @tablist = $tabbedFrame->pages();
		my $t = shift(@tablist);
		$t0 = 'Tab1';
#x		$cmdArgs = "-focustab=$t0 -focus=$activeWindows{$t0} "
#x				.$cmdArgs  if ($t0 eq $activeTab);
		push (@cmdArgs, "-focustab=$t0", "-focus=$activeWindows{$t0}")  if ($t0 eq $activeTab);
		my $i = 1;
		foreach my $t (@tablist)
		{
			$t0 = 'Tab'.$i;
			next  unless ($cmdfile{$t}[0] =~ /\S/o || $cmdfile{$t}[1] =~ /\S/o);
#x			$cmdArgs .= " -tab$i=".$cmdfile{$t}[0];
			push @cmdArgs, "-tab$i=.$cmdfile{$t}[0]";
#x			$cmdArgs .= ":".$cmdfile{$t}[1]  if ($scrnCnts{$t});
			push (@cmdArgs, ":$cmdfile{$t}[1]")  if ($scrnCnts{$t});
#print DEBUG "-???2- t0=$t0= t=$t= AT=$activeTab= cmdargs=".join(' ', @cmdArgs)."=\n"  if ($debug);
#x			$cmdArgs = "-focustab=Tab".($i+1)." -focus=$activeWindows{$t} "
#x					.$cmdArgs  if ($t eq $activeTab);
			unshift (@cmdArgs, ("-focustab=Tab".($i+1)), "-focus=$activeWindows{$t}")
					if ($t eq $activeTab);
			++$i;
		}
#x		$cmdArgs .= ' '.$cmdfile{$t0}[0];
		push @cmdArgs, $cmdfile{$t0}[0];
#x		$cmdArgs .= ' '.$cmdfile{$t0}[1]  if ($scrnCnts{$t0});
		push (@cmdArgs, $cmdfile{$t0}[1])  if ($scrnCnts{$t0});
#		$cmdArgs = "-focustab=$t0 -focus=$activeWindows{$t0} "
#					.$cmdArgs  if ($t0 eq $activeTab);
#print DEBUG "-???1- t=$t0= cmdargs=$cmdArgs=\n"  if ($debug);
#print DEBUG "-!!!- WILL EXEC($cmd, ".join(' ', @cmdArgs).")!\n"  if ($debug);
#x		exec "\"$cmd\" -nb -l=$curposn $cmdArgs";
		unshift @cmdArgs, '-nb', "-l=$curposn";
	}
	exec $cmd, @cmdArgs;
}

sub fixAfterStep   #TRYIN TO MAKE OUR STUPID W/M RESTORE FOCUS?!?!?! :(
{
	$MainWin->state('normal');
	$MainWin->focus();
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus();
	$MainWin->raise();
	$MainWin->focus(-force);
}

sub reHighlight   #SOMETIMES HIGHLIGHTING DOES NOT WORK PROPERLY, PARTICULARY WITH syntax.highlight.perl.Improved?!
{
	my $widget = shift;
	my $force = shift;
	if ($force)
	{
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->highlightPlugInit;
		return
	}
	my ($firstLn, $lastLn);
	eval { 
		$firstLn = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->linenumber('sel.first');
		$lastLn = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->linenumber('sel.last');
	};
	unless (defined($firstLn) && defined($lastLn))
	{
		$firstLn = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->linenumber('insert');
		$lastLn = $textScrolled[$activeWindow]->Subwidget($textsubwidget)->linenumber('end');
	}
	$textScrolled[$activeWindow]->Subwidget($textsubwidget)->highlight($firstLn, $lastLn);
}

sub SaveOnDestroy
{
print DEBUG "-SaveOnDestroy:  args=".join('|',@_)."= nst=$newsupertext=\n"  if ($debug);
	my $situation = shift || '';
	my $appendRandom = shift;
	my $awin = shift || $activeWindow;
	my $aTab = shift || $activeTab;
	my $w = shift || $textScrolled[$awin];
#print DEBUG "-!!!- w=$w=\n";

#	(my $fn = $cmdfile{$activeTab}[$activeWindow]) =~ s/(\S)\.\w+$/$1/o;
	(my $fn = $cmdfile{$activeTab}[$activeWindow]) =~ s/(\S)(\.\w+)$/$1/o;
	my $extORdotfile = $2;
	$fn = $1  if ($fn =~ m#^.*\/([^\/]+)$#);
	$fn = $extORdotfile  if ($fn =~ m#^\/#);  #WE'RE A .dotfile!
	$fn =~ s/ //go;
	$tofid = "${systmp}/e_${situation}${aTab}W${awin}_${fn}_$$.tmp";
	if ($appendRandom)
	{
		(my $rand = time) =~ s/^\d\d\d\d\d//o;
		$tofid =~ s/\.tmp$/\_${rand}\.tmp/;
	}
	if ($newsupertext || $AnsiColor)
	{
		$_ = $w->getansi('0.0','end');
#print DEBUG "-??????- SaveOnDestroy1: cash10=".substr($_,0,10)."=\n";
	}
	else
	{
#		$_ = $textScrolled[$awin]->get('0.0','end');
		$_ = $w->get('0.0','end');
#print DEBUG "-??????- SaveOnDestroy2: cash10=".substr($_,0,10)."=\n";
	}
	if (/\S/o && &writedata($tofid, 0, 1, 2, 1))
	{
		print DEBUG "e:Could not back up file to \"$tofid\"!";
	}
}

sub jumpToTag
{
#print DEBUG "-----JUMPTOTAG(".join('|',@_).")!\n";
	my $srchpos = shift;   #SEARCH STARTING POSITION.
	my $srchwards = shift; #SEARCH DIRECTION (1=FORWARD, 0=BACKWARD).
	my $t;
	my $tagMatchStr = '';
	while ($t = shift)     #GET NEXT SELECTED TAG-TYPE TO SEARCH FOR (1 OR MORE):
	{
		if ($t == 1)  #"ALL TAGS":
		{
			$tagMatchStr = join('|',@tagTypeIndex[2..$#tagTypeIndex]);
			last;
		}
		else
		{
			$tagMatchStr .= $tagTypeIndex[$t].'|';
		}
	}
	$tagMatchStr =~ s/\|$//o;
#print DEBUG "--JUMPTOTAG: tagMatchStr=$tagMatchStr=\n";
	my @xdump;
	if ($srchwards)
	{
		eval { @xdump = $textScrolled[$activeWindow]->dump(-tag, "$srchpos + 1 char", 'end'); };
#print DEBUG "++AT=$@= next tag=".join('|',@xdump)."= search=$tagMatchStr\n";
		my $i=1;
		my $foundit = 0;
		while (defined($xdump[$i]))
		{
			if ($xdump[$i] =~ /$tagMatchStr$/ && $xdump[$i-1] =~ /tagon/o)
			{
#print DEBUG "+!!!+ GOTO $xdump[$i+1]!\n";
				$textScrolled[$activeWindow]->markSet('insert',$xdump[$i+1]);
				$textScrolled[$activeWindow]->see('insert');
				++$foundit;
				last;
			}
			$ i+= 3;
		}
		$xdump[$i] =~ s/ANSI//o;
		$lnoffset = 1;
		return $foundit ? ($xdump[$i+1], $xdump[$i]) : ('', 'Tag');
	}
	else
	{
		eval { @xdump = reverse($textScrolled[$activeWindow]->dump(-tag, '0.0', "$srchpos - 1 char")); };
		my $i=1;
		my $foundit = 0;
#print DEBUG "-???- tagmatchregex=$tagMatchStr=\n";
		while (defined($xdump[$i]))
		{
			if ($xdump[$i] =~ /$tagMatchStr$/ && $xdump[$i+1] =~ /tagon/o)
			{
#print DEBUG "-!!!- GOTO $xdump[$i-1]! ($xdump[$i]) regex=$tagMatchStr=\n";
				$textScrolled[$activeWindow]->markSet('insert',$xdump[$i-1]);
				$textScrolled[$activeWindow]->see('insert');
				++$foundit;
				last;
			}
			$ i+= 3;
		}
		$xdump[$i] =~ s/ANSI//o;
		$lnoffset = 1;
		return $foundit ? ($xdump[$i-1], $xdump[$i]) : ('', 'Tag');
	}
	$lnoffset = 0;
}

sub chgtabs
{
	&gettext("Spaces/tab(0=\\t):",2,'t',0,0,1);
	return 0  unless ($intext && $intext ne '*cancel*');
	$tabspacing = $intext  if ($intext =~ /^\d+$/ && $intext <= 12);
	$notabs = $intext  unless ($intext);
}

__END__

=head1 NAME

E Editor - Perl/Tk text text-editor featuring code highlighting, multiple-tabs, and more.

=head1 AUTHOR

Jim Turner

(c) 1999-2023, Jim Turner, under the same license that Perl 5 itself is.  All rights reserved.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 1999-2023 Jim Turner.

E Editor is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this program; if not, write to the Free
Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

=head1 SYNOPSIS

	<e.pl> [I<-options>] [file1 [-tabs file2 file3 ...]]

	<e.pl> [I<-options>] file1 file2  #FOR SPLIT-SCREEN EDITING

	<v.pl> [I<-options>] [file1 [-tabs file2 file3 ...]]  #VIEWING

=head1 DESCRIPTION

E Editor provides a convenient screen text editor for editing text files and 
source-code files, etc.  E features language-based color-syntax highlighting, 
bracket-matching and jumping, and syntax-checking for Perl and C sources, 
quick-eval and quick-run for Perl sources.  General features include multiple 
browser tabs and split-screen option for editing multiple files at once.  
Named bookmarks, easy search and replace, easy auto and manual file backup, 
and recent file and search-term memory, and an open-readonly option.
Depending on what's available on your system, E can use any one of a number 
of installed Tk::Text-derived widgets for it's editing screen, for example, 
L<Tk::TextHighlight>, L<Tk::Text::SuperText>, L<Tk::TextUndo>, etc.  To 
use E Editor as a (readonly) viewer, simply symlink "v.pl" to "e.pl".
Drag and Drop files is available for M$-Windows users.

=head1 OPTIONS

=over 4

=item B<-bg>=I<background-color>

Change (default unhighlighted) text foreground color.
Default:  I<green>.
NOTE:  Can also be combined with B<-c> and B<-palette>.

=item B<-fg>=I<foreground-color>

Change (default unhighlighted) text-area background color.
Default:  I<black>.
NOTE:  Can also be combined with B<-c> and B<-palette>.

=item B<-c>=I<color-palette-name>

(Color palette) - Same as B<-palette>, see below.
Name of color-palette to use, specified in .Xdefaults.
Default (.Xdefaults: I<tkPalette> for editor,  I<tkVPalette> for viewer; 
or, the system's default Xwindows colors, if not specified.
NOTE:  Overridden by the B<-theme> option, if specified.

=item B<-codetext>=I<[Kate::]Language>

Selects which language to use for syntax-highlighting.  Depending on 
whether B<-[editor|-viewer]> mode is being used, can be any one of:
Default determined, if possible from the file extension or the 
first line ("#!...") of the file, otherwise, none.
Valid I<Language> values are:  I<None>, I<Bash>, I<Perl>, I<Perl>, 
I<PerlCool>, I<Xresources>, and, if L<Syntax::Highlight::Engine::Kate> 
is installed, any of the many I<Kate::language> values.

=item B<-editor>=I<module>

(editor - e.pl):  Should be based on L<Tk::Text>.  The "Tk::" is omitted.
Known to work:  I<Text>, I<TextANSIColor>, I<SuperText>, 
and I<TextHighlight>.  Default:  I<Text>.

=item B<-f>=I</path/to/fontfile>

Default:  I<./.myefonts|~/.myefonts|<programhome>/myefonts>.
Text file containing list of font definitions to use in the 
font-selection dialog.  Format of text file (each line):
IndexCharacter Description:unix-font-string

Example line:  B<A Normal-17 LT:-*-lucidatypewriter-medium-r-normal-*-17-*-100-100-*-*-*-*>

Select this font with "-font=A" or to make default, make this the 
first line in the "~/.myefonts" file.  See myefonts 
(file included) for examples.

=item B<-font>=I<#|id|font-name|unix-font-string>

Specify the index# or id (in font file) or the Unix font 
string to use as the default text font.	 
Default:  I<0> (1st font in font-file).

=item B<-wf>|B<-tf>|B<-sf>|B<-lf>|B<-hf>

Specify a starting font-size:  (weensey font, tiny font, 
small font, large font, or huge font.
NOTE:  This overrides any "font" option specified in the *.ini files.

=item B<-height>=I<#>

Specify number of I<lines> to show at start (starting window height).
Default:  I<25>.

=item B<-width>=I<#>

Specify number of I<characters> wide to start (starting window width).
Default:  I<80>.

=item B<-histFile>=I</path/to/file>

File to save history of last several opened files for quick 
recall in the file open dialog.  
Default:  I<~/.myehist>

=item B<-histmax>=I<#>

Number of recently edited/viewed files to be kept in the 
dropdown list in the file open dialog.  
Default:  I<16>.

=item B<-homedir>=I<path>

User's "HOME" directory for looking for configuration files, 
such as ".myefonts", ".myethemes",	etc.
Default:  I<~/> ($HOME).
	
=item B<-kandrstyle>=I<0|1|2>

Specify K&R-style Perl stmts. when inserting into code or 
reformatting.  I<0>: "if ()\n{"; I<1>: "if (){"; I<2>: "if () {".
Default:  I<0> (vertically-aligned, non-K&R style) formatting.

=item B<-l>=I<line#[.col#]>

Start with cursor on that line# / column#.
NOTE:  Line#s are one-based, but column#s are zero-based!
Default:  I<1.0> (the beginning of the file).

=item B<-nb>

(editor only) - Causes the file not to be auto-backed up when opened.
Default:  auto-backup when opening a file.

=item B<-nobrowsetabs>

Do not do multitab browsing (maximum open files is then limited to 
2 (via split-screen), but provides for a slightly smaller window 
(vertically).
Default:  (multi-tab browing enabled and at least one tab shows).

=item B<-notabs>=I<0|1>

Pad indentations with 0=tabs, or 1=spaces.
Default:  I<0>: tabs.

=item B<-palette>=I<color-palette-name>

Name of color-palette to use, specified in .Xdefaults.
Default (.Xdefaults: I<tkPalette> for editor,  I<tkVPalette> for viewer; 
or, the system's default Xwindows colors, if not specified.
NOTE:  Overridden by B<-theme> option, if specified.

=item B<-pathFile>=I</path/to/file>

Configuration file containing list of "favorite" directories/folders 
in a drop-down list in the file open dialog box.
Format of text file (each line):  /some/path;Comment
Default:  I<~/.myepaths>

=item B<-s>=I<"string">

Start with cursor on 1st match of "I<string>".

=item B<-savemarks>=I<0|1>

Whether to save bookmarks when saving file.  Bookmarks are saved in a 
separate file (with the extension:  .emk).  1:  Save bookmark locations 
automatically when file is saved (if any set).  0:  Don't (user must 
specifically save them) in the [File].[Save w/Marks] menu option.
Default:  (editor: I<1>, viewer: I<0>).

=item B<-tabspacing>=I<#>

Number of spaces equivalent to a tab when indenting.
Default:  I<3>.

=item B<-theme>=I<themename>

Name of color theme to start up in.  For list of themes, view/edit 
~/.myethemes.  If B<-fg> or B<-bg> are also specified, they override 
for the text widget whatever colors are specified in ~/.myethemes file 
for <themename>.  Format of text file (each line):  

Themename:$c="I<color>"|""|DEFAULT; $fg="I<color>"|same; $bg="I<color>|same">

"I<color>" can be a color-name or "#rrggbb".  See I<myethemes> 
(file included) for examples.
	
=item B<-viewer>=I<module>

(viewer - v.pl):  Same as for B<-editor>, but applies to v.pl 
(viewer-mode).  Should be based on L<Tk::ROText>.  The "Tk::" is omitted.
Known to work:  I<ROText>, I<ROTextANSIColor>, I<ROSuperText>, I<ROTextHighlight>, 
and I<XMLViewer>.  Default:  I<ROText>.

=back

You can also specify the above options in an "ini" file, (e.ini for 
editor mode and v.ini for viewer mode).  

Example, I use TextHighlight when editing code, so symlinked ec.pl to 
e.pl for highlighted code-editing, and set up a file (ec.ini) containing:

		editor=TextHighlight

=head1 RESOURCES

=over 4

=item B<tktextcutchars>

List of "cut-characters" used by Tk.

=item B<tkPalette>

Default palette color for this and some other Perl/Tk applications.

=item B<tkVpalette>

Default palette color for the "viewer" (v.pl) version of this program.

=back

=head1 FILES

=over 4

=item B<e.pl>

Main program script source.

=item B<v.pl>

Symlink to e.pl which, when run, is readonly.

=item B<~/.ebackups>

Data file that specifies the maximum number of backup 
files to keep and the number of the latest backup file index number.
Single line of text in the format:  

I<max-number-of-backups-to-keep>,I<last-backup-file-number>

=item B<~/.myefonts> (or I<program-home>/B<myefonts>

Font configuration file (for list of fonts available in the 
[Fonts] dropdown menu).

=item B<~/.myehist>

Program-created "history" list of last several files opened.

=item B<~/.myemimes> (or I<program-home>/B<myemimes>

User-created mime-configuration text file for syntax-highlighting 
special cases.  Line Format:  I<file-extension>:I<[Kate::]Language>

Example1:  mod:Kate::Modula-2
Example2:  tmpl:HTML

See B<-codetext> option.

=item B<~/.myepaths>

List of favorite directories with optional descriptive names for 
use in the file-open dialog.  Optional, user-created.

=item B<~/.myeprint>

Program-created data file containing printer command last used 
by the [File].[Print] dialog.

=item B<~/.myeprofiles>

Optional user-created file listing directories for which an 
alternate directory should be searched for an B<e.ini> 
configuration file.  This is useful for remote servers on which 
an e.ini file can or should not be stored.  

Line format:  I<directory-edited-file-is-in>:I<directory-ini-file-is-in>

=item B<~/.myethemes> (or I<program-home>/B<myethemes>

Theme configuration file (for list of themes available in the 
[Themes] dropdown menu).

=item B<./>I<program-name>B<.ini>

Optional user-created text configuration file for specifying default 
options for I<program-name>.pl.  Normally I<program-name> will be I<"e">.  
A separate one should be used for the viewer symlink (I<"v">.  It may 
be desirable to create other symlink names in order to use other 
corresponding *.ini files.  The program searches for these .ini files 
in the order:  1) The directory the file being edited, 2) The directory 
pointed to by B<~/.myeprofiles>, if the directory the file being edited 
in is in that list, 3)  The user's home directory (I<~/>), and last, 
the directory the program script is in, (often /usr/local/share/E/, if 
the program lives in /usr/local/bin/).  The search stops when one is found.

=item B<./>I<filename>.emk

Program-created file containing bookmark indices and tag data created in 
the same directory (if possible) of the I<filename> being edited and saved.

=item B<~/tmp/e.>I<index-number>.tmp

Program-created file for backup copies of file being edited.  I<index-number> 
is a sequence number derived from the "rolodex" maintained by B<~/.ebackups>.

=item B</tmp/e_>I<type-letter>TabI<tab#>WI<window#>_I<filename>_<random-number>B<.tmp>

Auto-backup and manual temporary backup files from the [File].[Backup /tmp] 
menu options.  I<type-letter> is either "B" - auto open backup, "U" - 
user-requested temp. backup from menu, or "X" - auto exit backup.

=back

=head1 KEYWORDS

editor viewer perl Tk

=head1 DEPENDS

L<perl> L<File::Copy> L<Text::Tabs> L<Tk> L<Tk::JDialog> L<Tk::JBrowseEntry> 
L<Tk::JFileDialog> L<Tk::ColorEditor> L<Tk::Adjuster> L<Tk::NoteBook> L<Tk::TextUndo> 
<Cwd getopts.pl setPalette.pl JCutCopyPaste.pl

=head1 RECOMMENDS

L<Tk::Autoscroll> L<File::Glob> L<Tk::XMLViewer> L<Tk::Text::SuperText> 
L<Tk::Text::ROSuperText>

For code syntax-highlighting:  L<Tk::TextHighlight> L<Tk::ROTextHighlight> 
L<Syntax::Highlight::Perl::Improved> L<Syntax::Highlight::Engine::Kate>

For M#-Windows:  L<File::Spec::Win32> L<Tk::DragDrop::Win32Site> L<Tk::DropSite>

=cut
