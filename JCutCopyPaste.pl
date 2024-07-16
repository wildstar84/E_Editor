#WRITTEN BY JIM TURNER (JWT) DUE TO COMMONALITY.
#
#PROVIDES THE 3 SUBROUTINES NEEDED TO DO CUT, COPY, AND PASTE OPERATIONS 
#WITH THE CLIPBOARD FROM PERL/TK PROGRAMS.  THE ROUTINES ARE:  
#"doCut()", "doCopy()", "doPaste(<clipboard>)" (where 'clipboard' is 'PRIMARY', 
#'CLIPBOARD', 'CLIPFILE', OR UNSPECIED (TRY ALL IN THAT ORDER)) and 
#"textfocusin()".
#
#usage:  require 'JCutCopyPaste.pl';
#...
#   1) Name your main window with the global variable "$MainWin".
#   2) When you define a TEXT or ENTRY widget or any derivitive, follow it with 
#   the binding:
#
#	$myText->bind('<FocusIn>' => [\&textfocusin]);
#
#The "do?????" routines can be called as callbacks from buttons, etc.
#
#THE PURPOSE OF TEXTFOCUSIN AND THE REQUIRED BINDING, ALLOWS CUTCOPYPASTE TO
#KEEP TRACK OF WHICH WIDGET HAS THE FOCUS ($ACTIVEWIDGET) FOR DOING THE
#CUTTING AND PASTING.  WHEN A TEXT OR ENTRY WIDGET RECEIVES THE FOCUS, 
#TEXTFOCUSIN SETS THE $ACTIVEWIDGET VARIABLE TO POINT TO THAT WIDGET.

sub doPaste
{
	my $pastebuffer = shift || '';

	if (defined $activewidget)
	{
		my $clipboard = '';

		eval
		{
			$activewidget->markSet('selstartmk','insert');
			$activewidget->markGravity('selstartmk','left');
			$activewidget->markSet('selendmk','insert');
			$activewidget->markGravity('selendmk','right');
		};
		#TRY EACH PASTE-BUFFER UNTIL DATA FOUND & PUT INTO $clipboard VARIABLE ACCORDING TO FOLLOWING RULES:
		#PRIMARY SPECIFIED:  TRY ONLY PRIMARY BUFFER.
		#CLIPBOARD SPECIFIED:  TRY CLIPBOARD, THEN CLIPFILE.
		#CLIPFILE SPECIFIED:  TRY ONLY CLIPFILE.
		#UNSPECIFIED (DEFAULT):  TRY PRIMARY, THEN CLIPBOARD, THEN LASTLY, THE CLIPFILE:

		#NOTE:  THE PURPOSE OF THE CLIPFILE IS TO BACK UP THE CLIPBOARD WITH THE LAST CONTENT OF THE
		#CLIPBOARD PLACED THERE (ONLY BY OUR Perl/Tk APPS) IF THE CLIPBOARD GETS CLEARED WITHIN THEM.
		#TO SUPPRESS THIS EXTRA CLIPBOARD FEATURE, UNSET THE CLIPBOARD_FID ENVIRONMENT VARIABLE.
		#I BELIEVE I CREATED THIS FEATURE BACK WHEN Perl/Tk DID NOT ALWAYS PROPERLY HANDLE PASTE-BUFFERS?

		#FIRST, TRY PASTE FROM PRIMARY, IFF UNSPECIFIED OR PRIMARY SPECIFIED (UNSPECIFIED TRIES PRIMARY THEN CLIPBOARD):
		eval { $clipboard = $MainWin->SelectionGet(-selection => 'PRIMARY') }
			if ($pastebuffer !~ /\S/o || $pastebuffer eq 'PRIMARY');
		#NEXT, TRY PASTE EITHER FROM CLIPBOARD, IF CLIPBOARD SPECIFED; OR FROM PRIMARY IF UNSPECIFIED AND PRIMARY HAS CONTENT:
		eval { $clipboard = $MainWin->SelectionGet(-selection => 'CLIPBOARD') }
			if ($pastebuffer eq 'CLIPBOARD' || ($pastebuffer !~ /\S/o && length($clipboard) <= 0));
		#LAST, TRY CLIPFILE UNLESS PRIMARY SPECIFIED OR CLIPFILE DOES NOT EXIST:
		if ($pastebuffer ne 'PRIMARY' && defined($ENV{CLIPBOARD_FID}) && length($clipboard) <= 0
				&& open(CLIPBRD,"<$ENV{CLIPBOARD_FID}"))
		{
			$clipboard = join('',<CLIPBRD>);
			close CLIPBRD;
			if (open(CLIPBRD,">$ENV{CLIPBOARD_FID}"))
			{
				binmode CLIPBRD;
				print CLIPBRD $clipboard;
				close CLIPBRD;
				eval
				{
					$MainWin->SelectionOwn(-selection => 'CLIPBOARD');
					$MainWin->clipboardClear;
					$MainWin->clipboardAppend('--',$clipboard);
				}  if (length($clipboard) > 0);  #COPY THE CLIPBOARD_FID CONTENT BACK INTO CLIPBOARD:
			}
		}
		$activewidget->tagDelete('sel');  #NEXT 2 ADDED 20100708 TO PREVENT COPIED/PASTED
		$activewidget->SelectionClear();  #TEXT FROM STAYING SELECTED IN BOTH PLACES!
		eval
		{
			$activewidget->insert('insert',$clipboard);
			#if ($activewidget->index('sel.first') =~ /\./)  #TEXT WIDGET
			#{
				$activewidget->tagAdd('sel', 'selstartmk', 'selendmk');
			#}
		}  if (length($clipboard) > 0);
	}
}

sub doCopy
{
	if (defined($activewidget))
	{
		eval
		{
			$MainWin->SelectionOwn(-selection => 'CLIPBOARD');
			$MainWin->clipboardClear;
			if ($activewidget->index('sel.first') =~ /\./o)  #TEXT WIDGET
			{
				$clipboard = $activewidget->get('sel.first','sel.last');
#JWT:AS OF LATEST Perl/Tk v1.804.033-1, THIS HACK SEEMS TO NO LONGER BE NECESSARY!
#if (length($clipboard) > 7999)   #HACK AROUND TK BUG THAT CRASHES APP IF TRY TO PAST >7999 CHARACTERS?!?!?!
#{
#	$clipboard = substr($clipboard,0,7999);
#	my $selStart = $activewidget->index('sel.first');
#	my $newSelEnd = $activewidget->index('sel.first + 7999 char');
#	$MainWin->SelectionOwn(-selection => 'PRIMARY');
#	eval { $MainWin->SelectionClear($newSelEnd, 'end'); };
#	$activewidget->tagAdd('sel', $selStart, $newSelEnd);
#	$activewidget->see($newSelEnd);
#}
			}
			else  #ENTRY WIDGET
			{
				$clipboard = $activewidget->get;
				$clipboard = substr($clipboard,$activewidget->index('sel.first'),
					($activewidget->index('sel.last') - $activewidget->index('sel.first')));
			}
			$MainWin->clipboardAppend('--',$clipboard);
			if (defined($ENV{CLIPBOARD_FID}) && open(CLIPBRD,">$ENV{CLIPBOARD_FID}"))
			{
				#COPY SELECTION TO OUR CLIPBOARD FILE:
				binmode CLIPBRD;
				print CLIPBRD $clipboard;
				close CLIPBRD;
			}
		};
	}
}

sub doCut
{
	if (defined($activewidget))
	{
		eval
		{
			$MainWin->SelectionOwn(-selection => 'CLIPBOARD');
			$MainWin->clipboardClear;
			if ($activewidget->index('sel.first') =~ /\./)  #TEXT WIDGET
			{
				$clipboard = $activewidget->get('sel.first','sel.last');
#JWT:AS OF LATEST Perl/Tk v1.804.033-1, THIS HACK SEEMS TO NO LONGER BE NECESSARY!
#if (length($clipboard) > 7999)   #HACK AROUND TK BUG THAT CRASHES APP IF TRY TO PAST >7999 CHARACTERS?!?!?!
#{
#	$clipboard = substr($clipboard,0,7999);
#	my $selStart = $activewidget->index('sel.first');
#	my $newSelEnd = $activewidget->index('sel.first + 7999 char');
#	$MainWin->SelectionOwn(-selection => 'PRIMARY');
#	eval { $MainWin->SelectionClear($newSelEnd, 'end'); };
#	$activewidget->tagAdd('sel', $selStart, $newSelEnd);
#	$activewidget->see($newSelEnd);
#}
			}
			else  #ENTRY WIDGET
			{
				$clipboard = $activewidget->get;
				$clipboard = substr($clipboard,$activewidget->index('sel.first'),
						($activewidget->index('sel.last') - $activewidget->index('sel.first')));
			}
			$MainWin->clipboardAppend('--',$clipboard);
			if (defined($ENV{CLIPBOARD_FID}) && open(CLIPBRD,">$ENV{CLIPBOARD_FID}"))
			{
				#COPY SELECTION TO OUR CLIPBOARD FILE:
				binmode CLIPBRD;
				print CLIPBRD $clipboard;
				close CLIPBRD;
			}
			$activewidget->delete('sel.first','sel.last');
		};
	}
}

sub textfocusin
{
	$activewidget = shift;
}

sub getactive
{
	return $activewidget;
}

1;

