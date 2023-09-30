my ($mycmd);
my $setState = $v ? 'disabled' : 'normal';

$perlMenubtn = $w_menu->Menubutton(
	-text => 'HTML',
	-underline => 0,
	@menuOps);
$perlMenubtn->command(
	-label => 'View',
	-underline =>0,
	-command => [\&perlFn,2]);
$perlMenubtn->command(
	-label => '<Parameter>',
	-underline =>0,
	-state => $setState,
	-command => [\&perlFn,1]);
$perlMenubtn->command(
	-label => 'Reformat',
	-underline =>0,
	-state => $setState,
	-command => [\&perlFn2,8]);

eval {$textScrolled[$activeWindow]->index('sel.first')};

$thismenu = $perlMenubtn;

foreach $i (qw(A B BR BODY CHECKBOX CENTER CODE DIV FONT FORM H1 H2 H3 H4 HEAD HR HTML I IEXCL LI MU NBSP OPTION P QUOTE RADIO SELECT SPAN STYLE TABLE TD TH TR TEXTAREA U UL !EVAL !IF !INCLUDE !LOOP !PERL !SELECTLIST))
{
	if ($i eq 'TABLE')
	{
		$perlMenubtn->cascade(	-label => 'More...', -underline =>0);
		my ($cm) = $perlMenubtn->cget(-menu);
		my ($cc) = $cm->Menu;
		$perlMenubtn->entryconfigure('More...', -menu => $cc);
		$thismenu = $cc;
	}
	$myeval = '		$thismenu->command(	-label => \''.$i.'\', -underline =>0, -state => $setState, -command => [\&perlFn,0,$i]); ';
	eval $myeval;
}

$perlMenubtn->pack(@menuPackOps);


sub perlFn
{
	my ($runit) = shift;
	my ($mytag) = shift;

	if ($runit == 1)  #USER'S OWN TAG.
	{
		#######&doCopy();
		&gettext("HTML Tag Name:",20,'t',0,1);
		return  if ($intext eq  '*cancel*');
		my $tagname = $intext;
		$tagname =~ s/^\s*(\w+).*/$1/;
		eval {$textScrolled[$activeWindow]->insert('sel.first',"<!:$intext:>");};
		$@ ? $textScrolled[$activeWindow]->insert('insert',"<!:$intext>") : 
				$textScrolled[$activeWindow]->insert('sel.last',"<!:/$tagname>");
		return;
	}
	elsif ($runit == 2)   #FIRE UP NETSCAPE!
	{
		$_ = '';
		my $browser;   #ADDED 20021007 TO ALLOW USER TO SELECT BROWSER.
		unless (&writedata("$webtmp/e.src.htm"))
		{
			if (open(T, "<$ENV{HOME}/.myebrowser"))
			{
				$browser = <T>;
				chomp ($browser);
			}
			$_ = "$webtmp/e.src.htm";
			if ($bummer)
			{
				$browser ||= start;
				s/ /\%20/gso;
				s#\/#\\#gso;
				$_ = $browser . ' file:///' . $_;
			}
			else
			{
				$browser ||= $ENV{BROWSER} || 'firefox';
				$_ = $browser . ' ' . $_ . ' &';
			}
#print "-???- will run cmd=$_=";
			system $_;
#print "-???- DONE VIEWING!\n";
		}
		return;
	}
	else
	{
		#######&doCopy();
		eval {$textScrolled[$activeWindow]->index('sel.first')};
		$intext = '';
		if ($mytag =~ '(A|BODY|CHECKBOX|DIV|FONT|FORM|HR|OPTION|RADIO|SELECT|SPAN|TABLE|TD|TH|TEXTAREA|\!EVAL|\!IF|\!INCLUDE|\!LOOP|\!SELECTLIST)')
		{
			&gettext("$mytag Tag Info:",40,'t',0,1);
			return  if ($intext eq '*cancel*');
			$intext = ' '.$intext  if ($intext =~ /\S/ && $intext !~ /^\_/);
		}
		$pos = 1;
		eval {$pos = $textScrolled[$activeWindow]->index('sel.first');};
		my ($highlighted) = 0;
		$highlighted = 1  unless ($@);
		$pos =~ s/.*\.//o;
		#eval {$textScrolled[$activeWindow]->insert('sel.first',"<$mytag$intext>");};
		if ($mytag eq 'NBSP')
		{
			$textScrolled[$activeWindow]->insert('insert','&nbsp;');
			return;
		}
		if ($mytag eq 'MU')
		{
			$textScrolled[$activeWindow]->insert('insert','&micro;');
			return;
		}
		if ($mytag eq 'IEXCL')
		{
			$textScrolled[$activeWindow]->insert('insert','&iexcl;');
			return;
		}
		unless ($highlighted)
		{
			if ($mytag eq 'QUOTE')
			{
				$textScrolled[$activeWindow]->insert('insert','&quot;');
				return;
			}
			$textScrolled[$activeWindow]->insert('insert',"<$mytag$intext>");
			$textScrolled[$activeWindow]->markSet('mymark','insert - 1 char');
			&beginUndoHTMLBlock($textScrolled[$activeWindow]);
			if ($mytag =~ '(A|BODY|DIV|FONT|FORM|SELECT|SPAN|STYLE|TABLE|TD|TH|TR|TEXTAREA|\!EVAL|\!IF|\!LOOP)')
			{
				if ($mytag =~ /^!/o)
				{
					$textScrolled[$activeWindow]->insert('insert', 
						('<!/'.substr($mytag,1).'>'));
				}
				else
				{
					$textScrolled[$activeWindow]->insert('insert',"</$mytag>");
				}
			}
			&endUndoHTMLBlock($textScrolled[$activeWindow]);
			$textScrolled[$activeWindow]->markSet('insert','mymark + 1 char');
		}
		else
		{
			&beginUndoHTMLBlock($textScrolled[$activeWindow]);
print STDERR "-!!!- BEGIN UNDOBLOCK!\n"  if ($debug);
			my ($startpos) = $textScrolled[$activeWindow]->index('sel.first');
			my ($endpos) = $textScrolled[$activeWindow]->index('sel.last');
print STDERR "-???- st=$startpos= en=$endpos= ls=".$textScrolled[$activeWindow]->index('sel.first linestart')."= le=".$textScrolled[$activeWindow]->index('sel.last lineend')."=\n"
if ($debug);
			my ($startline) = $startpos;
			$startline =~ s/\..*//o;
			my ($endline) = $endpos;
			$endline =~ s/\..*//o;
	my $spacesperTab = $tabspacing || 3;
	my $tspaces = ' ' x $spacesperTab;
	my $indentStr = $notabs ? $tspaces : "\t";
			my ($x) = '';
			my ($x2) = '';
			if (($endline > $startline) && ($startpos =~ /\.0$/o) && ($endpos =~ /\.0$/o))
			{
				my ($lastline) = $textScrolled[$activeWindow]->get('sel.first','sel.first lineend');
				$x = $1  if ($lastline =~ /^(\s+)/o);
#				$x =~ s/\t/   /g;
#				$x =~ s/   /\t/g;
				$x =~ s/\t/$tspaces/g;
				$x =~ s/$tspaces/\t/g  unless ($notabs);
				my ($tabcnt) = length($x);
				$tabcnt /= $spacesperTab  if ($notabs);
				if ($mytag eq 'QUOTE')
				{
					eval {$textScrolled[$activeWindow]->insert('sel.first',"$x&quot;\n");};
				}
				else
				{
					eval {$textScrolled[$activeWindow]->insert('sel.first',"$x<$mytag$intext>\n");};
				}
				eval {&doIndent(1,0);};
#1				if ($SuperText)
				{
					$x2 = "\n";
				}
#1				else
#1				{
#1					$x = "\n" . $x;
#1				}
			}
			else
			{
				if ($mytag eq 'QUOTE')
				{
					eval {$textScrolled[$activeWindow]->insert('sel.first',"&quot;");};
				}
				else
				{
					eval {$textScrolled[$activeWindow]->insert('sel.first',"<$mytag$intext>");};
				}
			}
			#$textScrolled[$activeWindow]->insert('sel.first',"\n")  unless ($pos);
#POUNDED 20030920			$textScrolled[$activeWindow]->insert('sel.last',"\n")  unless ($pos);
			if ($mytag eq 'QUOTE')
			{
				$textScrolled[$activeWindow]->insert('sel.last',($x.'&quot;'.$x2));
			}
			elsif ($mytag =~ /^!/)
			{
				if ($intext =~ /^_/)   #TAG HAS A LABEL.
				{
					$intext =~ s/^(\S+).*/$1/;
					$textScrolled[$activeWindow]->insert('sel.last', 
						($x.'<!/'.substr($mytag,1).$intext.'>'.$x2));
				}
				else
				{
					$textScrolled[$activeWindow]->insert('sel.last', 
						($x.'<!/'.substr($mytag,1).'>'.$x2));
				}
			}
			else
			{
				$textScrolled[$activeWindow]->insert('sel.last',"$x</$mytag>$x2");
			}
#####			$textScrolled[$activeWindow]->markSet('sel.last', 'sel.last + 1 char');
			&endUndoHTMLBlock($textScrolled[$activeWindow]);
print STDERR "-!!!- END UNDOBLOCK!\n"  if ($debug);
		}
		return;
	}

	$xpopup2->destroy  if (Exists($xpopup2));
	$xpopup2 = $MainWin->Toplevel;
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
		-height => 10,
		-width  => 40);

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
		-text => 'Edit',
		-underline => 0,
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
	my $okButton = $xpopup2btnFrame->Button(
		-padx => 11,
		-underline => 0,
		-text => 'Ok',
		-command => sub {
		$textScrolled[$activeWindow]->Subwidget($textsubwidget)->focus;
		$xpopup2 => 'destroy';
		$MainWin->raise();
	});
	$okButton->pack(-side=>'left', -expand => 1, -padx=>'2m', -pady=>'1m');
	$bottomFrame->pack(
		-side => 'bottom',
		-fill	=> 'both',
		-expand	=> 'yes');

	$xpopup2->bind('<Escape>'   => [$okButton	=> Invoke]);
	$okButton->focus;
	my ($errline) = undef;
	if (open(TEMPFID,"$hometmp/e.out.tmp"))
	{
		while (<TEMPFID>)
		{
			$errline = $1  if (!defined($errline) && /line (\d+)/);
			$text2Scrolled->insert('end',$_);
		}
		close TEMPFID;
	}
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

sub perlFn2
{
	my ($which) = shift;

	my ($actualcurpos) = $textScrolled[$activeWindow]->index('insert');
	my ($curpos) = $textScrolled[$activeWindow]->index('insert linestart');
	eval {$curpos = $textScrolled[$activeWindow]->index('sel.first linestart');};
	#my ($startpos) = $curpos;
	my ($startpos) = $textScrolled[$activeWindow]->index('insert');
#print "<BR>startpos was =$startpos=\n";
	my ($linesback) = 0;
	$linesback = 1  if ($actualcurpos =~ /\.0$/o);
	$startpos = $curpos;
#print "<BR>startpos  is =$startpos= lb=$linesback=\n";
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
		#$lastline = $textScrolled[$activeWindow]->get("$curpos - 1 line linestart","$curpos - 1 line lineend");
		#LAST LINE CHGD TO NEXT 6 20010514.
#print "-cp=$curpos= lb=$linesback=\n";
		#my ($linesback) = 1;
		my ($curline) = $textScrolled[$activeWindow]->get("$curpos linestart","$curpos lineend");
#print "--- curline=$curline=\n";
		do
		{
			$lastline = $textScrolled[$activeWindow]->get("$curpos - $linesback line linestart","$curpos - $linesback line lineend");
#print "-loop- lb=$linesback= ll=$lastline=\n";
			++$linesback;
		} while ($curpos > 0.0 && $lastline !~ /\S/);
#print "-ll=$lastline= lb=$linesback=\n";
		$lastchar = $textScrolled[$activeWindow]->get("insert - 1 char", 'insert');
#print "-???- lc=$lastchar= actual=$actualcurpos=\n";
		if (length($curline) && $curline =~ /\S/)
		{
			if ($lastchar eq '{' || $actualcurpos !~ /\.0/)
			{
#print "------ adding 1!\n";
				$startpos += 1.0;
				$startpos .= '.0';
				$curpos += 1.0;
				$curpos .= '.0';
			}
		}
	}
	my ($x) = '';
	$x = $1  if ($lastline =~ /^(\s+)/);
#print "-lastline indented, x=$x=\n"  if ($lastline =~ /^(\s+)/);
	$x =~ s/\t/   /g;
	$x =~ s/   /\t/g;
	my ($xb) = $x;
	$x = "\t" . $x  if ($lastline =~ /\{\s*$/ || $lastchar eq '{');
#print "-ll ends in curly: x=$x=\n"  if ($lastline =~ /\{\s*$/ || $lastchar eq '{');
	$tabcnt = length($x);
#print "-tabcnt =$tabcnt=\n";
	my ($curskip) = 0;

	&gettext("Starting indent:",3,'t');
	return  if ($intext eq  '*cancel*');
	&reallign();
}

sub reallign
{
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

	if (open (TEMPFID,">$hometmp/e.reformat.tmp"))
	{
		print TEMPFID '#LINES: '.$selstart.' - '.$selend."\n";
		print TEMPFID $wholething;
		close TEMPFID;
		`chmod 777 $hometmp/e.reformat.tmp`;
	}
	else
	{
		$statusLabel->configure(-text=>"Could not reformat -- $hometmp/e.reformat.tmp unwritable!");
		return (1);
	}
	my $hereend;
	
	$current_indent = $intext;
	&beginUndoHTMLBlock($textScrolled[$activeWindow]);
	for (my $i=0;$i<=$#lines;$i++)
	{
#print "---next line($i)=$lines[$i]=\n";
		next  if ($lines[$i] =~ /^\#\#*(print|for)/o);  #LEAVE OUR DEBUG STUFF ALONE!
		next  if ($lines[$i] =~ /^\#*print/o);  #LEAVE OUR DEBUG STUFF ALONE!
		next  if ($lines[$i] =~ /^\s*\#/o);     #ADDED 20010514 - LEAVE COMMENTED LINES ALONE!
		next  if ($lines[$i] =~ /^\=\w/o);      #ADDED 20010514 - LEAVE POD COMMANDS ALONE!
		if ($hereend)  #LEAVE HERE-STRINGS ALONE!
		{
			$hereend = ''  if ($lines[$i] =~ /^$hereend/);  #LEAVE HERE-STRING ENDTAGS ALONE!
			next;
		}
		$lines[$i] =~ s/^\s+//o;
		$lines[$i] =~ s/([\'\"])([^\1]*)?\1/my ($one,$two) = ($1,$2); 
				$two =~ s!\#!\x02!; "$one$two$one"/eg;
		$comment = '';
		$comment = $1  if ($lines[$i] =~ s/^(\#.*)$//o);
		$comment = $2  if (!$comment && $lines[$i] =~ s/([^\$])(\#.*)$/$1/);

		$_ = $lines[$i];
		s/\{.*?\}//g;
		$current_indent--  if ($current_indent && /\}\s*$/o);
#print "\n-???- ci=$current_indent= lines($i)=$lines[$i]=\n";
		$lines[$i] = ("\t" x $current_indent) . $lines[$i] 
				unless ($lines[$i] =~ s/^\s*(\w+\:)\s*(.*)$/$1.("\t" x $current_indent).$2/e);
		$cont = 0  if ($lines[$i] =~ /^\s*\-/o);
		$cont = 0  if ($lines[$i] =~ /^\s*\{/o);   #ADDED 20010514
		$lines[$i] = "\t\t" . $lines[$i]  if ($cont);
		$hereend = $1  if ($lines[$i] =~ /\<\<[\'\"]?(\w+)/o);  #CHECK `HERE-STRINGS.
		if ($lines[$i] =~ /\}\s*(else.*|elsif.*)\{\s*$/o)   #HANDLE STUFF LIKE "} else {".
		{
#print "($i) case 1\n";
			$current_indent--  if ($current_indent);
			$lines[$i] = ("\t" x $current_indent) . "}\n" 
					. ("\t" x $current_indent) . $1 . "\n"  
					. ("\t" x $current_indent) . "{";
		}
		#if ($lines[$i] =~ /\S\s*\{[^\}]*$/)  #FIX K & R-STYLE BRACES.
#print "---THIS line($i)=$lines[$i]=\n";
		if ($lines[$i] =~ /\S\s*\{\s*$/o)  #FIX K & R-STYLE BRACES.
		{
#print "($i) case 2\n";
			$lines[$i] =~ s/\s*\{\s*$//o;
			$lines[$i] .= "\n" . ("\t" x $current_indent) . "{";
		}
		if ($lines[$i] =~ /^[^\{\s]+\s*\}/o)
		{
#print "($i) case 3\n";
			$lines[$i] =~ s/^[^\{]*\s*\}\s*(.*)$//o;
			$current_indent--  if ($current_indent);
			$lines[$i] = ("\t" x $current_indent) . "}\n" 
					. ("\t" x $current_indent) . $1;
		}
		if ($lines[$i] =~ /^[^\{]*\}\s*(\S.*)$/o)
		{
#print "($i) case 4\n";
			$current_indent--  if ($current_indent);
			$lines[$i] = ("\t" x $current_indent) . "}\n" 
					. ("\t" x $current_indent) . $1;
		}
		if ($lines[$i] =~ /\{\s*$/o || $lines[$i] =~ /^\s*\{/o)
		{
			$current_indent++;
		}
		$cont = 0;
		#$cont = 1  if ($lines[$i] =~ /[\,\'\+\-\=\*\/\"\.\&\|]\s*$/);
		#CHGD TO NEXT LINE 20010514.
		$cont = 1  if ($lines[$i] =~ /[\,\'\+\-\=\*\/\"\.\&\|\(\)]\s*$/o);
		$cont = 0  if ($lines[$i] =~ /^\s*\-/);
		$lines[$i] = "\t\t".$lines[$i]  if ($lines[$i] =~ /^\s*\-\S/o);
		$lines[$i] .= $comment;
		$lines[$i] =~ s/\x02/\#/go;
		$lines[$i] =~ s/^\s+$//go;   #ADDED 20010514 - COMPLETELY BLANK EMPTY LINES.
		#$lines[$i] = ("\t" x $current_indent) . $lines[$i];
#print "- ci=$current_indent= cont=$cont= lines($i)=$lines[$i]=\n";
	}
	&endUndoHTMLBlock($textScrolled[$activeWindow]);
	$textScrolled[$activeWindow]->markSet('insert',$selstart);
	$textScrolled[$activeWindow]->delete($selstart, $selend);
	$wholething = join("\n",@lines) . "\n";
	$textScrolled[$activeWindow]->insert('insert',$wholething);
	$textScrolled[$activeWindow]->markSet('insert',$curposn);
	$statusLabel->configure(-text=>"..Realligned.");
}

sub beginUndoHTMLBlock
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

sub endUndoHTMLBlock
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

1
