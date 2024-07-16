$perlMenubtn = $w_menu->Menubutton(
	-text => 'C',
	-underline => 0,
	@menuOps);
$perlMenubtn->command(
	-label => 'Check',
	-underline =>0,
	-command => [\&c_Fn,0]);
$perlMenubtn->command(
	-label => 'Run',
	-underline =>0,
	-command => [\&c_Fn,1]);
$perlMenubtn->command(
	-label => 'Comment',
	-underline =>1,
	-command => [\&commentFn]);
$perlMenubtn->command(
	-label => 'Comment (C++)',
	-underline =>10,
	-command => [\&commentFnCPP]);
$perlMenubtn->pack(@menuPackOps);

if (defined($v))
{
	$perlMenubtn->entryconfigure('Comment', -state => 'disabled');
	$perlMenubtn->entryconfigure('Comment (C++)', -state => 'disabled');
}

sub c_Fn
{
	my ($runit) = shift;

	`rm $hometmp/*.o`;
	`rm a.out`;
	`echo "" >$hometmp/e.out.tmp`;
	$MainWin->Busy;
	$_ = '';
	system "gcc $ENV{C_OPTIONS} $hometmp/e.src.c  >$hometmp/e.out.tmp 2>&1"  unless (&writedata("$hometmp/e.src.c"));

	$compileResult = $?;
#print "-rununit=$runit= err=$compileResult=\n";
	if ($runit && !$compileResult)
	{
#print "-2rununit=$runit=\n";
		if (-e 'a.out')
		{
			system "a.out >$hometmp/e.out.tmp 2>&1 &";
			(@childpid) = `ps -ef|grep e.src.tmp`;
			$childpid = $childpid[1];
			$childpid =~ s/\D+(\d+)\s+\d+\s+\d+.*$/$1/;
		}
	}
	#elsif (!compileResult)
	#{
#print "-4: cr=$compileResult=\n";
		`echo "Syntax OK!\n" >>$hometmp/e.out.tmp`  unless ($runit || $compileResult);
	#}
	$xpopup2->destroy  if (Exists($xpopup2));
	$xpopup2 = $MainWin->Toplevel;
	$xpopup2->title('GCC syntax-check results:');
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
	$fileMenubtn->command(-label => 'Close',   -underline =>0, -command => [$xpopup2 => 'destroy']);
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

	$text2Scrolled->bind('<FocusIn>' => [\&textfocusin]);
	my $okButton = $xpopup2btnFrame->Button(
		-padx => 11,
		-underline => 0,
		-text => 'Ok',
		-command => sub {$xpopup2->destroy;});
	$okButton->pack(-side=>'left', -expand => 1, -padx=>'2m', -pady=>'1m');
	$abortButton = $xpopup2btnFrame->Button(
		-padx => 11,
		-underline => 0,
		-text => 'Abort',
		-command => sub {
			print "-abort=$childpid=\n"; 
			`kill -9 $childpid`;
			$abortButton->configure(-state => 'disabled');
		});
	$abortButton->pack(-side=>'left', -expand => 1, -padx=>'2m', -pady=>'1m') 
			if ($runit == 1);
	$bottomFrame->pack(
		-side => 'bottom',
		-fill	=> 'both',
		-expand	=> 'yes');

	$xpopup2->bind('<Escape>'   => [$okButton	=> Invoke]);
	$okButton->focus;
	if (open(TEMPFID,"$hometmp/e.out.tmp"))
	{
		while (<TEMPFID>)
		{
			$text2Scrolled->insert('end',$_);
		}
		close TEMPFID;
	}
	$MainWin->Unbusy;
}

sub commentFn
{
	my $clipboard;
	my ($firstpos) = $textScrolled[$activeWindow]->index('sel.first');
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');
print "--first=$firstpos= last=$lastpos=\n";
	$textScrolled[$activeWindow]->markSet('selstart','sel.first');
	if ($lastpos =~ /\.0$/o)
	{
		$textScrolled[$activeWindow]->markSet('selend','sel.last - 1 char');
	}
	else
	{
		$textScrolled[$activeWindow]->markSet('selend','sel.last');
	}
	$textScrolled[$activeWindow]->markSet('_prev','insert');
	$textScrolled[$activeWindow]->markSet('insert','selend');
	$clipboard = $textScrolled[$activeWindow]->get('sel.first','sel.last');
	$clipboard =~ s#\/\*#\/\:#gso;
	$clipboard =~ s#\*\/#\:\/#gso;
	$clipboard .= ($lastpos =~ /\.0$/o) ? "*/\n" : ' */';
	$_ = ($firstpos =~ /\.0$/o && $lastpos =~ /\.0$/o) ? "/*\n" : '/* ';
	$clipboard = $_ . $clipboard;
	$textScrolled[$activeWindow]->delete('sel.first','sel.last');
	$textScrolled[$activeWindow]->insert('insert',$clipboard);
	$_ = length($clipboard);
	$textScrolled[$activeWindow]->tagAdd('sel',"insert - $_ char",'insert');
	$textScrolled[$activeWindow]->markSet('insert','sel.last');
}

sub commentFnCPP
{
	my $clipboard;
	eval { $textScrolled[$activeWindow]->markSet('selstart','sel.first linestart - 2 char'); };
	if ($@)
	{
		$textScrolled[$activeWindow]->insert('insert', '//');
		$textScrolled[$activeWindow]->tagAdd('sel','insert - 2 char','insert lineend');
		return;
	}
	my ($lastpos) = $textScrolled[$activeWindow]->index('sel.last');
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
	my $prefix = '//';
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
	$textScrolled[$activeWindow]->delete('sel.first linestart - 1 char','selend');
	$textScrolled[$activeWindow]->insert('insert',$clipboard);
	$textScrolled[$activeWindow]->tagAdd('sel','selstart + 2 char','selend + 1 char');
	$textScrolled[$activeWindow]->markSet('insert','selstart + 2 char');
}

sub findFns
{
	$srchTextVar = ($cmdfile[$activeWindow] =~ /\.(?:js|ht\w+)$/io)
			? '^function\s+\w+' : '^sub\s+\w+';
	$srchopts = '-regexp';

	&GlobalSrchRep($whichTextWidget, 1);
}

sub beginUndoPerlBlock
{
	my $whichTextWidget = shift;

	if ($textsubwidget =~ /supertext/io)   #ADDED 20080411 TO BLOCK CHANGES FOR UNDO.
	{
		eval { $whichTextWidget->_BeginUndoBlock };
	}
	else
	{
		eval { $whichTextWidget->addGlobStart };
	}
}

sub endUndoPerlBlock
{
	my $whichTextWidget = shift;

	if ($textsubwidget =~ /supertext/io)   #ADDED 20080411 TO BLOCK CHANGES FOR UNDO.
	{
		eval { $whichTextWidget->_EndUndoBlock };
	}
	else
	{
		eval { $whichTextWidget->addGlobEnd };
	}
}

1
