#WRITTEN BY JIM TURNER (JWT) DUE TO COMMONALITY.
#
#PROVIDES THE 3 SUBROUTINES NEEDED TO DO CUT, COPY, AND PASTE OPERATIONS
#WITH THE CLIPBOARD FROM PERL/TK PROGRAMS.  THE ROUTINES ARE:  "doCut()",
#"doCopy()", "doPaste('clipboard')" (where 'clipboard' is 'PRIMARY', 'CLIPFILE'
#-if CLIPBOARD_FID is set, 
#'CLIPBOARD', 'SECONDARY', or other Unix clipboard; DEFAULT='CLIPBOARD'), 
#and "textfocusin()".
#
#usage:  require 'JCutCopyPaste.pl';
#...
#When you define a TEXT or ENTRY widget or any derivitive, follow it with 
#the binding:
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
	my ($pasteboard) = shift;

	if (defined($activewidget))
	{
		my ($clipboard) = '';

		eval
		{
			$activewidget->markSet('selstartmk','insert');
			$activewidget->markGravity('selstartmk','left');
			$activewidget->markSet('selendmk','insert');
			$activewidget->markGravity('selendmk','right');
		};
		if ($pasteboard !~ /\S/o || $pasteboard eq 'PRIMARY')
		{
			eval {$clipboard = $MainWin->SelectionGet(-selection => 'PRIMARY');};
			$pasteboard = 'CLIPBOARD';
		}
		eval
		{
			if ($clipboard !~ /\S/o || $pasteboard eq 'CLIPFILE')
			{
				if (defined($ENV{CLIPBOARD_FID}))
				{
					if (open(CLIPBRD,"<$ENV{CLIPBOARD_FID}"))
					{
						$clipboard = join('',<CLIPBRD>);
						close CLIPBRD;
						#$activewidget->insert('insert',$clipboard);
						if (open(CLIPBRD,">$ENV{CLIPBOARD_FID}"))
						{
							binmode CLIPBRD;
							print CLIPBRD $clipboard;
							close CLIPBRD;
							if ($clipboard =~ /\S/o)
							{
								$MainWin->SelectionOwn(-selection => 'CLIPBOARD');
								$MainWin->clipboardClear;
								$MainWin->clipboardAppend('--',$clipboard);
							}
						}
					}
				}
			}
		};
		eval
		{
			if ($clipboard !~ /\S/o)
			{
				$clipboard = $MainWin->SelectionGet(-selection => $pasteboard);
			}
		};
		$activewidget->tagDelete('sel');  #NEXT 2 ADDED 20100708 TO PREVENT COPIED/PASTED
		$activewidget->SelectionClear();  #TEXT FROM STAYING SELECTED IN BOTH PLACES!
		if ($clipboard =~ /\S/o)
		{
			eval
			{
				$activewidget->insert('insert',$clipboard);
				#if ($activewidget->index('sel.first') =~ /\./)  #TEXT WIDGET
				{
					$activewidget->tagAdd('sel', 'selstartmk', 'selendmk');
				}
			};
		}
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
					($activewidget->index('sel.last')
					- $activewidget->index('sel.first')));
			}
			$MainWin->clipboardAppend('--',$clipboard);
			if (defined($ENV{CLIPBOARD_FID}))
			{
				if (open(CLIPBRD,">$ENV{CLIPBOARD_FID}"))
				{
					binmode CLIPBRD;
					print CLIPBRD $clipboard;
					close CLIPBRD;
				}
			};
		}
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
					($activewidget->index('sel.last')
					- $activewidget->index('sel.first')));
			}
			$MainWin->clipboardAppend('--',$clipboard);
			if (defined($ENV{CLIPBOARD_FID}))
			{
				if (open(CLIPBRD,">$ENV{CLIPBOARD_FID}"))
				{
					binmode CLIPBRD;
					print CLIPBRD $clipboard;
					close CLIPBRD;
				}
			};
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

