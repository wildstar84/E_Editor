#NOTE:  e.src.pl NOW GOES IN $systmp (default /tmp/ram/ - a ram disk).
#FOR SSD-BASED SYSTEMS, $systemp SHOULD BE ON A RAMDISK TO AVOID CONSTANTLY
#WRITING SHORT-LIVED TEMP. FILES TO AN SSD DRIVE!:

$perlMenubtn = $w_menu->Menubutton(
	-text => 'Perl',
	-underline => 0,
	@menuOps);
$perlMenubtn->command(
	-label => 'Check',
	-underline =>0,
	-command => [\&perlFn,0]);
$perlMenubtn->command(
	-label => 'Eval{}',
	-underline =>0,
	-command => [\&perlFn,2]);
$perlMenubtn->command(
	-label => 'Run',
	-underline =>0,
	-command => [\&perlFn,1]);
$perlMenubtn->separator;
$perlMenubtn->command(
	-label => 'Block',
	-underline =>0,
	-command => [\&perlFn2,1]);
$perlMenubtn->command(
	-label => 'Comment (#)',
	-underline =>1,
	-command => [\&commentFn,0]);
$perlMenubtn->command(
	-label => 'Comment (Pod)',
	-underline =>9,
	-command => [\&commentFn,1]);
$perlMenubtn->command(
	-label => 'If-Then',
	-underline =>3,
	-command => [\&perlFn2,5]);
$perlMenubtn->command(
	-label => 'If-Then-Else',
	-underline =>0,
	-command => [\&perlFn2,2]);
$perlMenubtn->command(
	-label => 'For',
	-underline =>0,
	-command => [\&perlFn2,3]);
$perlMenubtn->command(
	-label => 'While',
	-underline =>0,
	-command => [\&perlFn2,6]);
$perlMenubtn->command(
	-label => 'Do-While',
	-underline =>0,
	-command => [\&perlFn2,9]);
$perlMenubtn->command(
	-label => 'Sub',
	-underline =>0,
	-command => [\&perlFn2,4]);
$perlMenubtn->command(
	-label => 'Unless',
	-underline =>0,
	-command => [\&perlFn2,7]);
$perlMenubtn->command(
	-label => 'Reformat',
	-underline =>0,
	-command => [\&perlFn2,8]);
$perlMenubtn->command(
	-label => 'Tabs_'.($tabspacing||3).'_2spc',
	#-underline =>0,
	-command => [\&perlFn2,10]);
$perlMenubtn->command(
	-label => 'Spaces2Tabs_'.($tabspacing||3),
	#-underline =>0,
	-command => [\&perlFn2,11]);
$perlMenubtn->command(
	-label => 'Shebang',
	#-underline =>0,
	-command => [\&shebang]);
$perlMenubtn->command(
	-label => 'Highlight Fns',
	#-underline =>0,
	-command => [\&findFns]);

$perlMenubtn->pack(@menuPackOps);

if (defined($v))
{
	$perlMenubtn->entryconfigure('Block', -state => 'disabled');
	$perlMenubtn->entryconfigure('Comment (#)', -state => 'disabled');
	$perlMenubtn->entryconfigure('Comment (Pod)', -state => 'disabled');
	$perlMenubtn->entryconfigure('If-Then', -state => 'disabled');
	$perlMenubtn->entryconfigure('If-Then-Else', -state => 'disabled');
	$perlMenubtn->entryconfigure('For', -state => 'disabled');
	$perlMenubtn->entryconfigure('While', -state => 'disabled');
	$perlMenubtn->entryconfigure('Do-While', -state => 'disabled');
	$perlMenubtn->entryconfigure('Sub', -state => 'disabled');
	$perlMenubtn->entryconfigure('Unless', -state => 'disabled');
	$perlMenubtn->entryconfigure('Reformat', -state => 'disabled');
	$perlMenubtn->entryconfigure('Tabs_'.($tabspacing||3).'_2spc', -state => 'disabled');
	$perlMenubtn->entryconfigure('Spaces2Tabs_'.($tabspacing||3), -state => 'disabled');
	$perlMenubtn->entryconfigure('Shebang', -state => 'disabled');
}

sub perlFn
{
	my ($runit) = shift;  #(0=check, 1=run, 2=eval)

	$abortit = 0;
	$closeit = 0;

	$bummer = 1  if ($^O =~ /Win/o && $^O !~ /cygwin/io);	
#print "-??? perlFn: runit=$runit= BUMMER=$bummer=\n";
	if ($runit == 2)
	{
		$_ = '';
		my ($wholething) = undef;
		eval
		{
			$wholething = $textScrolled[$activeWindow]->get('sel.first','sel.last');
			$_ = $wholething;
		};
		return 0  unless (defined($wholething));
		my ($result) = eval $wholething  unless (&writedata("$systmp/e.src.tmp"));
		if (open (TEMPFID,">$systmp/e.out.tmp"))
		{
			print TEMPFID "$result\n";
			print TEMPFID "\nEval returned error:  $@!\n"  unless ($@ eq '');
			close TEMPFID;
		}
	}
	elsif ($runit)
	{
		&gettext("Optional command-line arguments:",40,'t');
		return  if ($intext eq  '*cancel*');
		$_ = '';
		unless (&writedata("$systmp/e.src.tmp"))
		{
			#sleep(4);
			$MainWin->Busy;
			if ($bummer)
			{
				#$_ = "perl c:\\tmp\\e.src.tmp $intext >c:\\tmp\\e.out.tmp";
				$_ = "c:\\perl\\bin\\perl \"$systmp\\e.src.tmp\" $intext >\"$hometmp\\e.out.tmp\" 2>&1";
#print "-RUNNING CMD=$_=\n";
				system $_;
#print "-DID CMD!\n";
			}
			else
			{
				system "perl $systmp/e.src.tmp $intext >$systmp/e.out.tmp 2>&1 &";
				#sleep 3;
				#(@childpid) = `ps -ef|grep "e.src.tmp"`;
				(@childpid) = `ps ef|grep "e.src.tmp"`;
#print "-current pid=$$= cnt=$#childpid=\n";
#print join("\n----------\n",@childpid);
				#$childfid;
				foreach $i (0..$#childpid)
				{
					$childpid = $childpid[$i];
				#$childpid =~ s/\D+(\d+)\s+\d+\s+\d+.*$/$1/;
#print "-BEFORE: child=$childpid= cf($i)=$childpid[$i]=\n";
					if ($childpid[$i] !~ /grep/o && $childpid[$i] =~ /perl.+e\.src\.tmp/o && $childpid[$i] =~ /^\D*(\d+)/o)
					{
						$childpid = $1;
#print ">>>>> SET CHILDPID =$childpid=\n";
						goto GOTCHILD;
					}
				}
				$childpid = '';
#print "-!!!- CHILD RESET1\n";
GOTCHILD: ;
#print "-AFTER!: child=$childpid=\n";
#print "-x=".join('|',@x)."= at=$@= q=$?=\n";
			}
		}
	}
	else
	{
		$MainWin->Busy;
		#system "perl -c <$systmp/e.src.tmp >$systmp/e.out.tmp 2>&1 "  unless (&writedata("$systmp/e.src.tmp"));
		$_ = '';
		unless (&writedata("$systmp/e.src.tmp"))
		{
			#sleep(2);
			#system "perl -c <$systmp/e.src.tmp >$systmp/e.out.tmp 2>&1 ";
			#CHANGED TO NEXT LINE 20010514 TO FIX SAVE DELAY SYMPTOMS.
			if ($bummer)
			{
				#$_ = "perl -c c:\\tmp\\e.src.tmp 2>c:\\tmp\\e.out.tmp";
				$_ = "c:\\perl\\bin\\perl -c \"$systmp\\e.src.tmp\" 2>\"$hometmp\\e.out.tmp\"";
				if (`TYPE c:\\tmp\\e.out.tmp` =~ /\"\-T\" is on the \#\! line/o)
				{
					$_ = "c:\\perl\\bin\\perl -T -c \"$systmp\\e.src.tmp\" 2>\"$hometmp\\e.out.tmp\"";
				}
			}
			else
			{
				$_ = "perl -c <$systmp/e.src.tmp >$systmp/e.out.tmp 2>&1 ";
				if (`cat $systmp/e.out.tmp` =~ /\"\-T\" is on the \#\! line/o)
				{
					$_ = "perl -T -c <$systmp/e.src.tmp >$systmp/e.out.tmp 2>&1 ";
				}
			}
#print "-GRAVING COMPILE CMD=$_=\n";
			(@_) = `$_`;
#print "-DID COMPILE! res=".join('|',@_)."=\n";
			#sleep(2);
		}
	}

	$xpopup2->destroy  if (Exists($xpopup2));
	$xpopup2 = $MainWin->Toplevel;
#print STDERR "-popGeometry=$popGeometry=\n";
#print STDERR "-popGeometry=$popGeometry=\n";
	$xpopup2->geometry($popGeometry)  if ($popGeometry);
	$xpopup2->title('Perl syntax-check results:');
	$xpopup2->title('Results:')  if ($runit);
	my $w_menu = $xpopup2->Frame(
			-relief => 'raised',
			-borderwidth => 2);
	$w_menu->pack(-fill => 'x');
	
	my $bottomFrame = $xpopup2->Frame;
	my $xpopup2lbl = $bottomFrame->Frame;
	$xpopup2lbl->pack(
		-side	=> 'top',
		-fill   => 'x',
		-padx   => '2m',
		-pady   => '1m');
	my $xpopup2btnFrame = $bottomFrame->Frame;
	$xpopup2btnFrame->pack(
		-side	=> 'bottom',
		-fill   => 'x',
		-padx   => '2m',
		-pady   => '1m');
	
	my $text2Frame = $bottomFrame->Frame;
	$text2Scrolled = $text2Frame->Scrolled('ROText',
		-scrollbars => 'se');
	$text2Text = $text2Scrolled->Subwidget('rotext')->configure(
		-setgrid=> 1,
		-font	=> $fixedfont,
		-tabs	=> ['1.35c','2.7c','4.05c'],
		-insertbackground => 'white',
		-relief => 'sunken',
		-wrap	=> 'none',
		-height => $runheight[$runit],
		-width  => $runwidth[$runit]);

	my $fileMenubtn = $w_menu->Menubutton(
		-text => 'File',
		-underline => 0,
		@menuOps,
	);
	$fileMenubtn->command(-label => 'Save',    -underline =>0, -command => [\&doSave]);
	$fileMenubtn->separator;
	$fileMenubtn->command(-label => 'Close',   -underline =>0, -command => sub {
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
		$xpopup2 => 'destroy';
		$MainWin->raise();
	});
	my $editMenubtn = $w_menu->Menubutton(
		-text => 'Edit', -underline => 0,
		@menuOps,
	);
	$editMenubtn->command(
		-label => 'Copy',
		-underline =>0,
		-command => [\&doCopy]);
	$editMenubtn->separator;
	$editMenubtn->command(-label => 'Find',   -underline =>0, -command => [\&newSearch,$text2Scrolled,1]);
	$editMenubtn->command(-label => 'Modify search',   -underline =>0, -command => [\&newSearch,$text2Scrolled,0]);
	$editMenubtn->command(-label => 'Again', -underline =>0, -command => [\&doSearch,$text2Scrolled,0]);

	$fileMenubtn->pack(-side=>'left');
	$editMenubtn->pack(-side=>'left');

	$text2Frame->pack(
		-side	=> 'left',
		-expand	=> 'yes',
		-fill   => 'both',
		-padx   => '2m',
		-pady   => '1m');
	
	$text2Scrolled->pack(
		-side   => 'bottom',
		-expand => 'yes',
		-fill   => 'both');

	#$text2Text->bind('<FocusIn>' => sub { $curTextWidget = shift;} );
	$text2Scrolled->bind('<FocusIn>' => [\&textfocusin]);
	#my $okButton = $xpopup2btnFrame->Button(  #CHGD TO NEXT 20020215
	$okButton = $xpopup2btnFrame->Button(
		-padx => 11,
		-underline => 0,
		-text => 'Ok',
		-command => sub {
			unless ($abortit)
			{
#print "-1: child=$child=\n";
				if ($childpid =~ /^\d+$/o)
				{
#print "\n------abort=$childpid=\n"; 
					`kill -TERM $childpid`;
					$statusLabel->configure(-text=>"..Aborted process \"$childpid\"!");
					$abortButton->configure(-text => 'Abort Output');
					$childpid = '';
#print "-!!!- CHILD RESET2\n";
				}
				++$abortit;
			}
			else
			{
				$abortButton->configure(-state => 'disabled');
			}
			$closeit = 1;
			$xxx = $text2Scrolled->Subwidget('rotext')->cget(-height);
#print STDERR "-HEIGHT($runit) =$xxx= =".$text2Scrolled->Subwidget('rotext')->height."=\n";
			$runheight[$runit] = $xxx  if ($xxx =~ /^\d+$/o);
			$xxx = $text2Scrolled->Subwidget('rotext')->cget(-width);
#print STDERR "-WIDTH($runit) =$xxx=\n";
			$runwidth[$runit] = $xxx  if ($xxx =~ /^\d+$/o);
			#$popGeometry = $xpopup2->width.'x'.$xpopup2->height;
			$popGeometry = $xpopup2->geometry();
			$popGeometry =~ s/[+-].+$//o  if ($ENV{DESKTOP_SESSION} =~ /AfterStep/io);  #AFTERSTEP BUG - WANTS TO FORCE TO UPPER-LEFT PART OF DESKTOP?!
#print STDERR "-geometry now=$popGeometry=\n";
$MainWin->focus();   #SEEMS TO BE NEEDED BY OUR W/M TO PROPERLY RESTORE FOCUS?!
$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
			$xpopup2->destroy;
			$MainWin->Unbusy;
$MainWin->raise();
		});
	$okButton->pack(-side=>'left', -expand => 1, -padx=>'2m', -pady=>'1m');
	$abortButton = $xpopup2btnFrame->Button(
		-padx => 11,
		-underline => 0,
		-text => 'Kill process',
		-command => sub {
#print "-????????? ABORTIT=$abortit=\n";
			unless ($abortit)
			{
				if ($childpid)
				{
#print "----abort=$childpid=\n"; 
					`kill -TERM $childpid`;
					$statusLabel->configure(-text=>"..Aborted process \"$childpid\"!");
					&FetchAbortedOutput();
				}
			}
			else
			{
				$abortButton->configure(-text => 'Output aborted!');
				$abortButton->configure(-state => 'disabled');
			}
			++$abortit;
#print "-!!!!!!!- ABORTIT set to =$abortit=\n";
		}
	);
#print "-2: child=$childpid=\n";
	$abortButton->configure(-text => "Kill pid $childpid")  if ($childpid =~ /^\d+$/o);
	$abortButton->pack(-side=>'left', -expand => 1, -padx=>'2m', -pady=>'1m') 
			if ($runit == 1 && $childpid =~ /^\d+$/o);
	$bottomFrame->pack(
		-side => 'bottom',
		-fill	=> 'both',
		-expand	=> 'yes');

	$xpopup2->bind('<Escape>'   => [$okButton	=> Invoke]);
	unless ($runit == 1)
	{
		my ($errline) = undef;
#print "-opening2 tempfid!\n";
		$xpopup2->update;
		if (open(TEMPFID,"<$systmp/e.out.tmp"))
		{
#print "-opened2 tempfid!\n";
			while (<TEMPFID>)
			{
#print "-output2 line=$_=\n";
#print " x";
				$errline = $1  if (!defined($errline) && /line (\d+)/o);
				last  if ($closeit || $abortit > 1);
				$text2Scrolled->insert('end',$_);
				$text2Scrolled->see('end');
				$xpopup2->update;
			}
#print "-closed2 tempfid!!!\n";
			close TEMPFID;
			$MainWin->Unbusy;
			#$abortButton->configure(-state => 'disabled');
		}
		$MainWin->Unbusy;
		if (defined($errline))   #IF ERRORS, POSITION CURSOR TO LINE# OF 1ST ERROR!
		{
			#$errline .= '.0';
			my $errButton = $xpopup2btnFrame->Button(
					-padx => 11,
					-underline => 0,
					-text => 'Errors',
					-command => [\&gotoErr, $errline]);
			$errButton->pack(-side=>'left', -expand => 1, -padx=>'2m', -pady=>'1m');
			$errButton->focus;
		}
		else
		{
			$okButton->focus;
		}
	}
	else
	{
		unless ($childpid)
		{
			$okButton->focus;
			my ($errline) = undef;
#print "-opening102 tempfid!\n";
			$xpopup2->update;
			if (open(TEMPFID,"<$systmp/e.out.tmp"))
			{
++$abortit;
#print "-opened2 tempfid!\n";
				while (<TEMPFID>)
				{
#print "-output2 line=$_=\n";
#print " x";
					$errline = $1  if (!defined($errline) && /line (\d+)/o);
					last  if ($closeit || $abortit > 1);
					$text2Scrolled->insert('end',$_);
					$text2Scrolled->see('end');
					$xpopup2->update;
				}
#print "-closed2 tempfid!!!\n";
				close TEMPFID;
				$MainWin->Unbusy;
				#$abortButton->configure(-state => 'disabled');
			}
			$MainWin->Unbusy;
			if (defined($errline))   #IF ERRORS, POSITION CURSOR TO LINE# OF 1ST ERROR!
			{
				#$errline .= '.0';
				my $errButton = $xpopup2btnFrame->Button(
					-padx => 11,
					-underline => 0,
					-text => 'Errors',
					-command => [\&gotoErr, $errline]);
				$errButton->pack(-side=>'left', -expand => 1, -padx=>'2m', -pady=>'1m');
				$errButton->focus;
			}
		}
	}
}

sub perlFn2
{
	my ($which) = shift;
#print "---perlFn2($which)--\n";
	my ($actualcurpos) = $textScrolled[$activeWindow]->index('insert');
	my ($curpos) = $textScrolled[$activeWindow]->index('insert linestart');
	eval {$curpos = $textScrolled[$activeWindow]->index('sel.first linestart');};
	#my ($startpos) = $curpos;
	my ($startpos) = $textScrolled[$activeWindow]->index('insert');
	my ($linesback) = 0;
	$linesback = 1  if ($actualcurpos =~ /\.0$/o);
	$startpos = $curpos;
	my ($highlighted) = undef;
	eval
	{
		$highlighted = $textScrolled[$activeWindow]->get('sel.first','sel.last');
	};

	my ($lastline, $lastchar);
	if ($highlighted)
	{
		$lastline = $textScrolled[$activeWindow]->get("$curpos linestart","$curpos lineend");
	}
	else
	{
		my ($curline) = $textScrolled[$activeWindow]->get("$curpos linestart","$curpos lineend");
		
		$lastline = $textScrolled[$activeWindow]->get("$curpos - $linesback line linestart","$curpos - $linesback line lineend")
				if ($curpos > 0.0);
#print "-loop0- lb=$linesback= ll=$lastline=\n";
		++$linesback;
		my $lookbackptr;
		while ($curpos > 0.0 && ($lastline !~ /\S/o || $lastline =~ /^\#/o))
		{
			$lookbackptr = $curpos - $linesback;
			last  unless ($lookbackptr >= 0);
			$lastline = $textScrolled[$activeWindow]->get("$curpos - $linesback line linestart","$curpos - $linesback line lineend");
#print "-loop!- lb=$linesback= lp=$lookbackptr= ll=$lastline=\n";
			++$linesback;
		}
#print "-ll=$lastline= lb=$linesback=\n";
		$lastchar = $textScrolled[$activeWindow]->get("insert - 1 char", 'insert');
		if (length($curline) && $curline =~ /\S/o)
		{
			if ($lastchar eq '{' || $actualcurpos !~ /\.0/o)
			{
				$startpos += 1.0;
				$startpos .= '.0';
				$curpos += 1.0;
				$curpos .= '.0';
			}
		}
	}
	my ($x) = '';
	my $spacesperTab = $tabspacing || 3;
	my $tspaces = ' ' x $spacesperTab;
	my $indentStr = $notabs ? $tspaces : "\t";
#	my $indentLen = length($indentStr);
	
	$x = $1  if ($lastline =~ /^(\s+)/);
#print "-lastline indented, x=$x= ll=$lastline=\n"  if ($lastline =~ /^(\s+)/);
#	$x =~ s/\t/   /g;
#	$x =~ s/   /\t/g;
	$x =~ s/\t/$tspaces/g;
	$x =~ s/$tspaces/\t/g  unless ($notabs);
	my ($xb) = $x;
#print "-addblock0: x=$x= xb=$xb= kandr=$kandrstyle= lc=$lastchar= ll=$lastline=\n";
#	$x = $indentStr . $x  if ($lastline =~ /\{\s*$/ || $lastchar eq '{');  #CHGD. TO NEXT 20070727 TO FIX INDENTING IN K&R BLOCKS:
	$x = $indentStr . $x  if ((!$kandrstyle && $lastline =~ /\{\s*$/o) || $lastchar eq '{');

	my $beginbb = $x;
	$beginbb = ''   if ($kandrstyle == 1);
	$beginbb = ' '  if ($kandrstyle == 2);

	my $endbb = $kandrstyle ? '' : "\n";
	
#print "-ll ends in curly: x=$x=\n"  if ($lastline =~ /\{\s*$/ || $lastchar eq '{');
	$tabcnt = length($x);
#print "-tabcnt =$tabcnt=\n";
	my ($curskip) = 0;

	local *addblock = sub
	{
		my ($sameline) = shift;
		my $inlen = length($insstr);
#print "-addblock1: instr=$instr= inlen=$inlen= beginbb=$beginbb= x=$x=\n";
		$insstr .= ($insstr ? $beginbb : $x) . "{\n";
#print "-addblock startpos=$startpos= tabcnt=$tabcnt= curpos=$curpos=\n";
#print "-BEFORE- insstr=$insstr= x=$x= sp=$startpos= x=$x= supertext=$SuperText=\n";
		$textScrolled[$activeWindow]->insert($startpos, $insstr);
		$curskip += $tabcnt + 2;
#print "---- kr=$kandrstyle= inlen=$inlen= style=$sameline=\n";
		if ($kandrstyle && $inlen)
		{
			$textScrolled[$activeWindow]->markSet('insert',$curpos);
		}
		else
		{
			$textScrolled[$activeWindow]->markSet('insert',"$curpos + 1 line");
		}
		eval {&doIndent(1,0);};
#1		if ($SuperText)
		{
			eval {$textScrolled[$activeWindow]->markSet('insert','sel.last linestart');};
		}
#1		else
#1		{
#1			eval {$textScrolled[$activeWindow]->markSet('insert','sel.last + 1 line linestart');};
#1		}
		$endpos = $textScrolled[$activeWindow]->index("insert linestart");
		if ($sameline == 2)
		{
			$insstr = "$x} ";
			$insstr .= $insstr2  if ($insstr2);
		}
		elsif ($sameline == 1)
		{
			$insstr = "$x}";
			$insstr .= $insstr2  if ($insstr2);
		}
		else
		{
			$insstr = "$x}\n";
			$insstr .= $x . $insstr2  if ($insstr2);
		}
#print "-AFTER- insstr=$insstr= x=$x= ep=$endpos=\n";
		$textScrolled[$activeWindow]->insert('insert', $insstr);
		$textScrolled[$activeWindow]->markSet('insert',$endpos);
		$textScrolled[$activeWindow]->tagRemove('sel','0.0','end');
		if ($kandrstyle && $inlen)
		{
			$textScrolled[$activeWindow]->tagAdd('sel', $curpos, $endpos);
		}
		else
		{
			$textScrolled[$activeWindow]->tagAdd('sel', "$curpos + 1 line", $endpos);
		}
	};

	&beginUndoBlock($textScrolled[$activeWindow])  unless ($which == 4 || $which == 8);
	if ($which == 1)        #BLOCK
	{
		$insstr = '';
		$insstr2 = '';
		&addblock();
		$curskip = $tabcnt + 1;
		$textScrolled[$activeWindow]->markSet('insert',"$startpos + $curskip char");
	}
	elsif ($which == 2)     #IF-THEN-ELSE
	{
		$insstr = $x . "if ()$endbb";
		$insstr2 = "else$endbb$beginbb"."{\n$x}\n";
		$curpos += 1.0;
		$curpos .= '.0';
		&addblock($kandrstyle);
		$curskip = $tabcnt + 4;
		$textScrolled[$activeWindow]->markSet('insert',"$startpos + $curskip char");
	}
	elsif ($which == 3)     #FOR
	{
		$insstr = $x . "for (;;)$endbb";
		$insstr2 = '';
		$curpos += 1.0;
		$curpos .= '.0';
		&addblock();
		$curskip = $tabcnt + 5;
#print "-startpos=$startpos= curskip=$curskip=\n";
		$textScrolled[$activeWindow]->markSet('insert',"$startpos + $curskip char");
	}
	elsif ($which == 4)     #SUB
	{
		&gettext("Subroutine Name:",16,'t',0,1);
#print "-???- tabcnt=$tabcnt=\n";
		return  if ($intext eq  '*cancel*');
		my $addblockOpt;
		if ($tabcnt)
		{
			$insstr = $x . "local *$intext = sub$endbb";
			$curskip = 13;
			$insstr2 = ";\n\n";
			$addblockOpt = 1;
		}
		else
		{
			$insstr = "sub $intext$endbb";
			$curskip = 4;
			$insstr2 = "\n";
		}
		$curpos += 1.0;
		$curpos .= '.0';
#print "-BEF- cs=$curskip=\n";
		&addblock($addblockOpt);
#print "-BEF- cs=$curskip=\n";
		$curskip += length($intext);
		$curskip++  if ($kandrstyle == 2);
		$curskip += $tabcnt + 1  unless ($kandrstyle);
#print "-???- STARTPOS=$startpos= CURSKIP=$curskip= tc=$tabcnt= l=".length($intext)."=\n";
#		--$startpos  if ($kandrstyle);
		$textScrolled[$activeWindow]->markSet('insert',"$startpos + $curskip char");
	}
	elsif ($which == 5)     #IF-THEN
	{
		$insstr = $x . "if ()$endbb";
		$insstr2 = "";
		#$insstr .= "\n"  unless ($noend);
		$curpos += 1.0;
		$curpos .= '.0';
		&addblock();
		$curskip = $tabcnt + 4;
		$textScrolled[$activeWindow]->markSet('insert',"$startpos + $curskip char");
	}
	elsif ($which == 6)     #WHILE
	{
		$insstr = $x . "while ()$endbb";
		$insstr2 = '';
		$curpos += 1.0;
		$curpos .= '.0';
		&addblock();
		$curskip = $tabcnt + 7;
		$textScrolled[$activeWindow]->markSet('insert',"$startpos + $curskip char");
	}
	elsif ($which == 7)     #UNLESS
	{
		$insstr = $x . "unless ()$endbb";
		$insstr2 = "";
		#$insstr .= "\n"  unless ($noend);
		$curpos += 1.0;
		$curpos .= '.0';
		&addblock();
		$curskip = $tabcnt + 8;
		$textScrolled[$activeWindow]->markSet('insert',"$startpos + $curskip char");
	}
	elsif ($which == 8)
	{
		&gettext("Starting indent:",3,'t');
		return  if ($intext eq  '*cancel*');
		&reallign();
	}
	elsif ($which == 9)  #DO-WHILE.
	{
		$insstr = $x . "do$endbb";
		$insstr2 = "while ();\n";
		$curpos += 1.0;
		$curpos .= '.0';
		&addblock(2);
		#$curskip = (3 * $tabcnt) + 14;
		$curskip = $tabcnt + 9;
		$textScrolled[$activeWindow]->markSet('insert', "insert + $curskip char");
	}
	elsif ($which == 10)  #FIX TABS => 2 CHARS.
	{
		&fixTabs(1,$tabspacing||3);
	}
	elsif ($which == 11)  #FIX SPACES(2) => TABS.
	{
		&fixTabs(2,$tabspacing||3);
	}
	&endUndoBlock($textScrolled[$activeWindow])  unless ($which == 4 || $which == 8);
}

sub shebang
{
	my $perlpath = (-x '/usr/bin/perl') ? '/usr/bin/perl' : `which perl`;
	chomp($perlpath);
	if ($perlpath)
	{
		$textScrolled[$activeWindow]->insert('insert', ('#!'.$perlpath." -w\n\n"));
	}
}

sub reallign
{
	my ($wholething, $selstart, $selend);

	my $spacesperTab = $tabspacing || 3;
	my $tspaces = ' ' x $spacesperTab;
	my $indentStr = $notabs ? $tspaces : "\t";
	my $curposn = $textScrolled[$activeWindow]->index('insert');
	eval
	{
		$wholething = $textScrolled[$activeWindow]->get('sel.first','sel.last');
		$selstart = $textScrolled[$activeWindow]->index('sel.first');
		$selend = $textScrolled[$activeWindow]->index('sel.last');
	};
	unless (defined($wholething))
	{
		$wholething = $textScrolled[$activeWindow]->get('0.0','end');
		$selstart = '0.0';
		$selend = $textScrolled[$activeWindow]->index('end');
	}


#PROGRAMMER NOTE:  WE DON'T NEED TO WORRY A/B OS-SPECIFIC LINEBREAKS, THEY'RE ALL "\n" HERE!:


	my (@lines) = split(/\n/o, $wholething);

	if (open (TEMPFID,">$systmp/e.reformat.tmp"))
	{
		print TEMPFID '#LINES: '.$selstart.' - '.$selend."\n";
		print TEMPFID $wholething;
		close TEMPFID;
		`chmod 777 $systmp/e.reformat.tmp`;
	}
	else
	{
		$statusLabel->configure(-text=>"Could not reformat -- $systmp/e.reformat.tmp unwritable!");
		return (1);
	}
	my $hereend;

	&beginUndoBlock($textScrolled[$activeWindow]);
	$current_indent = $intext;
	for (my $i=0;$i<=$#lines;$i++)
	{
#print "-INDENT=$current_indent=--H=$hereend= next line($i)=$lines[$i]=\n";
		next  if ($lines[$i] =~ /^\#\#*(print|for)/o);  #LEAVE OUR DEBUG STUFF ALONE!
		next  if ($lines[$i] =~ /^\#*print/o);  #LEAVE OUR DEBUG STUFF ALONE!
		#next  if ($lines[$i] =~ /^\s*\#/);     #ADDED 20010514 - LEAVE COMMENTED LINES ALONE!
		next  if ($lines[$i] =~ /^\#/o);        #ADDED 20010514 - LEAVE COMMENTED LINES w/# IN COL#1 ALONE!
		next  if ($lines[$i] =~ /^\=\w/o);      #ADDED 20010514 - LEAVE POD COMMANDS ALONE!
		if ($hereend)  #LEAVE HERE-STRINGS ALONE!
		{
#print "-???BEF???-H=$hereend= l=$lines[$i]=\n";
			$hereend = ''  if ($lines[$i] =~ /^$hereend$/);  #LEAVE HERE-STRING ENDTAGS ALONE!
#print "-???AFT???-H=$hereend= l=$lines[$i]=\n";
			next;
		}
#print "-B($i)=$lines[$i]=\n";
		$lines[$i] =~ s/^\s+//;
#print "-A($i) (ind=$current_indent) =$lines[$i]=\n\n";
		$lines[$i] =~ s/([\'\"])([^\1]*)?\1/my ($one,$two) = ($1,$2); 
				$two =~ s!\#!\x02\^1jSpR1tE\x02!o; "$one$two$one"/eg;
		$comment = '';
		$comment = $1  if ($lines[$i] =~ s/^(\#.*)$//);
		$comment = $2  if (!$comment && $lines[$i] =~ s/([^\$])(\#.*)$/$1/);

		$lines[$i] =~ s/([\"\'])([^\"\']*?)\1/
				my $one = $1;
				my ($str) = $2;
				$str =~ s|\{|\x02\^2jSpR1tE\x02|gso;   #PROTECT BRACES IN QUOTES.
				$str =~ s|\}|\x02\^3jSpR1tE\x02|gso;   #PROTECT BRACES IN QUOTES.
				$str =~ s|\;|\x02\^4jSpR1tE\x02|gso;   #PROTECT SEMICOLONS IN QUOTES.
#print "-??????- one=$one= str=$str=\n";
		"$one$str$one"/egs;

		$_ = $lines[$i];
		s/\{.*?\}//g;
#print "-ci=$current_indent= l=$_=\n";
		if ($current_indent && /\}\s*\;?\s*$/o)
		{
#print "---CI decremented!\n";
			$current_indent--;
			$cont = 0;
		}
		elsif ($current_indent && /\)\s*\;\s*$/o)
		{
			$cont = 0;
		}
		$lines[$i] = ($indentStr x $current_indent) . $lines[$i] 
				unless ($lines[$i] =~ s/^\s*(\w+\:)\s*([^\:].*)$/$1.($indentStr x $current_indent).$2/e);
		$cont = 0  if ($lines[$i] =~ /^\s*\{/);   #ADDED 20010514
		if ($cont)
		{
			$lines[$i] = "$indentStr$indentStr" . $lines[$i];
			$lines[$i] =~ s/(\S\s*)([\)\]])\s*\;\s*$/"$1\n".($indentStr x $current_indent)."$2;\n"/e;
			$cont = 0;
		}
		elsif ($lines[$i] =~ /^\s*\-(\w+)\s*\=\>/)  #SPECIAL CASE 2 HANDLE LAST OPTION LINE OF TK STUFF:
		{
			$lines[$i] = "$indentStr$indentStr" . $lines[$i];
			$lines[$i] =~ s/^([^\)]+)\)(.+)$/"$1\n".($indentStr x $current_indent).")$2\n"/e;
		}
#print "\n-???- ci=$current_indent= cont=$cont= lines($i)=$lines[$i]=\n";
		$hereend = $1  if ($lines[$i] =~ /\<\<[\'\"]?(\w+)/);  #CHECK `HERE-STRINGS.
		if ($lines[$i] =~ /\}\s*(else.*|elsif.*)\{\s*$/)   #HANDLE STUFF LIKE "} else {".
		{
#print "($i) case 1: BEF($current_indent) K&R=$kandrstyle= LINE=$lines[$i]=\n";
			my $elsepart = $1;
			$elsepart =~ s/\s+$//o;
			my $paddit = "\n";
			my $prev_ind = $current_indent;
			$current_indent--  if ($current_indent);
			$paddit = $kandrstyle ? '' : ("\n". ($indentStr x $current_indent));
			$paddit = ' '  if ($kandrstyle == 2);
			$lines[$i] = ($indentStr x $current_indent) . "}$paddit" 
					. $elsepart . $paddit  . "{";
			$current_indent = $prev_ind  if ($kandrstyle);
#print "($i) case 1: AFT($current_indent) els=$elsepart= LINE=$lines[$i]=\n";
		}
#print "---THIS line($i)=$lines[$i]= LAST=$lastline=\n";
		if (!$kandrstyle && $lines[$i] =~ /\S\s*\{\s*$/o)  #FIX K & R-STYLE BRACES.
		{
#print "($i) case 2\n";
			$lines[$i] =~ s/\s*\{\s*$//o;
			$lines[$i] .= "\n" . ($indentStr x $current_indent) . "{";
		}
		if ($lines[$i] =~ /^[^\{\s]+\s*\}/o)
		{
#print "($i) case 3\n";
			$lines[$i] =~ s/^[^\{]*\s*\}\s*(.*)$//;
			$current_indent--  if ($current_indent);
			$lines[$i] = ($indentStr x $current_indent) . "}\n"
					. ($indentStr x $current_indent) . $1;
		}
		#if ($lines[$i] =~ /^[^\{]*\}\s*(\S.*)$/)     #CHGD. TO NEXT 20050331 TO FIX DOUBLE-LEFT INDENT AFTER "};"
		if ($lines[$i] =~ /^[^\{]*\}\s*([^\;].*)$/o)
		{
			my $one = $1;
#print "($i) case 4 one=$one=\n";
      if ($one =~ /\S/o) {
				$current_indent--  if ($current_indent);
				if ($one =~ /^\;/)
				{
					$lines[$i] = ($indentStr x $current_indent) . "}$one";
				}
				elsif (!$kandrstyle)
				{
					$lines[$i] = ($indentStr x $current_indent) . "}\n"
							. ($indentStr x $current_indent) . $one;
				}
      }
		}
		#if ($lines[$i] =~ /\{\s*$/ || $lines[$i] =~ /^\s*\{/)
		if ($lines[$i] =~ /\{\s*$/ || $lines[$i] =~ /^\s*\{[^\}]+$/o)
		{
#print "-l($i)=$lines[$i]= INDENT+1 (was $current_indent)!\n";
			$current_indent++;
		}
		$cont = 0;
		#$cont = 1  if ($lines[$i] =~ /[\,\'\+\-\=\*\/\"\.\&\|]\s*$/);
		#CHGD TO NEXT LINE 20010514.
		$cont = 1  if ($lines[$i] =~ /[\,\'\+\-\=\*\/\"\.\&\|\(\)\[]\s*$/o);
#		$cont = 0  if ($lines[$i] =~ /^\s*\-/);
#		$lines[$i] = "$indentStr$indentStr".$lines[$i]  if ($lines[$i] =~ /^\s*\-\S/);
		$lines[$i] .= $comment;
		$lines[$i] =~ s/\x02\^1jSpR1tE\x02/\#/og;
		$lines[$i] =~ s/^\s+$//og;   #ADDED 20010514 - COMPLETELY BLANK EMPTY LINES.
#	$lines[$i] =~ s|\x02\^2jSpR1tE\x02|\{|gs;   #UNPROTECT BRACES IN QUOTES.
#	$lines[$i] =~ s|\x02\^3jSpR1tE\x02|\}|gs;   #UNPROTECT BRACES IN QUOTES.
#	$lines[$i] =~ s|\x02\^4jSpR1tE\x02|\;|gs;   #UNPROTECT SEMICOLONS IN QUOTES.
		#$lines[$i] = ($indentStr x $current_indent) . $lines[$i];
#print "- ci=$current_indent= cont=$cont= lines($i)=$lines[$i]=\n";
	}
	$textScrolled[$activeWindow]->markSet('insert',$selstart);
	$textScrolled[$activeWindow]->delete($selstart, $selend);
	$wholething = join("\n",@lines) . "\n";
	if ($kandrstyle)
	{
		my $paddit = $kandrstyle == 2 ? ' ' : '';
#$wholething = "
#}
#
#else{
#";
#$paddit = '';
		$wholething =~ s/\n([\t ]*)(if|while|unless|else|elsif|for)([^\#\n\;]*)(\#[^\n]*)?(\n[\t ]+)\{/
				my (@args) = (0, $1, $2, $3, $4, $5);
				my $padpre = ($args[2] =~ m#^els#o) ? ' ' : $args[1];
				my $padbefore = ($args[3] =~ m#[ \t]$#o) ? '' : $paddit;
				my $padafter = ($args[4] =~ m#\S#o) ? " $args[4]" : '';
				"${padpre}$args[2]$args[3]$padbefore\{$padafter"
		/egs;
	}
	$wholething =~ s/\x02\^2jSpR1tE\x02/\{/gso;   #UNPROTECT BRACES IN QUOTES.
	$wholething =~ s/\x02\^3jSpR1tE\x02/\}/gso;   #UNPROTECT BRACES IN QUOTES.
	$wholething =~ s/\x02\^4jSpR1tE\x02/\;/gso;   #UNPROTECT SEMICOLONS IN QUOTES.

	$textScrolled[$activeWindow]->insert('insert',$wholething);
$textScrolled[$activeWindow]->markSet('selstart',$selstart);
$textScrolled[$activeWindow]->markSet('selend',$selend);
eval { $textScrolled[$activeWindow]->tagAdd('sel', 'selstart', 'selend'); };
	$textScrolled[$activeWindow]->markSet('insert',$curposn);
	&endUndoBlock($textScrolled[$activeWindow]);
	$statusLabel->configure(-text=>"..Realligned.");
}

sub fixTabs
{
	my $opt = shift;
	my $tabcnt = shift;
	my $spaces = ' ' x $tabcnt;
	my ($wholething, $selstart, $selend);

	my $curposn = $textScrolled[$activeWindow]->index('insert');
	eval
	{
		$wholething = $textScrolled[$activeWindow]->get('sel.first','sel.last');
		$selstart = $textScrolled[$activeWindow]->index('sel.first');
		$selend = $textScrolled[$activeWindow]->index('sel.last');
	};
	unless (defined($wholething))
	{
		$wholething = $textScrolled[$activeWindow]->get('0.0','end');
		$selstart = '0.0';
		$selend = $textScrolled[$activeWindow]->index('end');
	}
	my (@lines) = split(/\n/o, $wholething);

	if ($opt == 1)  #tabs to spaces:
	{
		for (my $i=0;$i<=$#lines;$i++)
		{
			while ($lines[$i] =~ s/^( *)\t/$1$spaces/o) {};
		}
	}
	else   #spaces => tabs:
	{
		for (my $i=0;$i<=$#lines;$i++)
		{
			while ($lines[$i] =~ s/^(\t*)$spaces/$1\t/o) {};
		}
	}
	$wholething = join("\n", @lines) . "\n";
	$textScrolled[$activeWindow]->markSet('insert',$selstart);
	$textScrolled[$activeWindow]->delete($selstart, $selend);
	$textScrolled[$activeWindow]->insert('insert',$wholething);
	$textScrolled[$activeWindow]->markSet('insert',$curposn);
	$statusLabel->configure(-text=>"..Realligned.");
}

sub FetchAbortedOutput
{
	$abortButton->configure(-text => 'Abort Output.');
	$okButton->focus;
	my ($errline) = undef;
#print "-opening2 tempfid!\n";
	$xpopup2->update;
	if (open(TEMPFID,"<$systmp/e.out.tmp"))
	{
++$abortit;
#print "-opened2 tempfid!\n";
		while (<TEMPFID>)
		{
#print "-output2 line=$_=\n";
#print " x";
			$errline = $1  if (!defined($errline) && /line (\d+)/o);
			last  if ($closeit || $abortit > 1);
#print "-about to insert a line ($closeit)!\n";
			$text2Scrolled->insert('end',$_);
			$text2Scrolled->see('end');
			$xpopup2->update;
		}
#print "-closed2 tempfid!!!\n";
		close TEMPFID;
		$MainWin->Unbusy;
		unless ($closeit)
		{
			if ($abortit > 1)
			{
				$abortButton->configure(-text => 'Output aborted!');
			}
			else
			{
				$abortButton->configure(-text => 'Output done.');
			}
			$abortButton->configure(-state => 'disabled');
		}
	}
	$MainWin->Unbusy;
#	if (defined($errline))   #IF ERRORS, POSITION CURSOR TO LINE# OF 1ST ERROR!
#	{
#		#$errline .= '.0';
#		my $errButton = $xpopup2btnFrame->Button(
#			-padx => 11,
#			-underline => 0,
#			-text => 'Errors',
#			-command => [\&gotoErr, $errline]);
#		$errButton->pack(-side=>'left', -expand => 1, -padx=>'2m', -pady=>'1m');
#		$errButton->focus;
#	}
}

sub commentFn
{
	my $pod = shift;
	
	my $clipboard;
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');

	&gettext(($pod ? '=head2:' : 'Addtl String?:'),6,'t');
	return  if ($intext eq  '*cancel*');
	return  if ($pod && length($intext) < 1);

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
		my @l = split(/\n/o, $clipboard, -1);
	my $prefix = $pod ? '' : '#' . $intext;
	for (my $i=1;$i<=$#l;$i++)
	{
		$l[$i] = $prefix . $l[$i];
	}
	$clipboard = join("\n", @l);
	if ($pod)
	{
		$clipboard = "\n" . $clipboard  unless ($clipboard =~ /^\n/so);
		$clipboard = "\n\n=head2 $intext\n" . $clipboard;
		$clipboard .= "\n"  unless ($clipboard =~ /\n$/so);
		$clipboard .= "\n=cut\n";
	}
	&beginUndoBlock($textScrolled[$activeWindow]);
	$textScrolled[$activeWindow]->delete('sel.first linestart - 1 char','selend');
	$textScrolled[$activeWindow]->insert('insert',$clipboard);
	&endUndoBlock($textScrolled[$activeWindow]);
	$textScrolled[$activeWindow]->tagAdd('sel','selstart + 2 char','selend + 1 char');
	$textScrolled[$activeWindow]->markSet('insert','selstart + 2 char');
}

sub findFns
{
	$srchstr = $srchTextVar = ($cmdfile{$activeTab}[$activeWindow] =~ /\.js$/io)
			? '^function\s+\w+' : '^sub\s+\w+';
	$srchstr = $srchTextVar = 'PROCEDURE '
		if ($cmdfile{$activeTab}[$activeWindow] =~ /\.mod$/io);

print "-findFns: srch=$srchTextVar= cmdfile($activeTab/$activeWindow)=$cmdfile{$activeTab}[$activeWindow]=\n";
	$srchopts = '-regexp';
	&GlobalSrchRep($whichTextWidget, 1);
}

1
