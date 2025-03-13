#!/usr/bin/perl -w

sub BindMouseWheel
{

	my($w) = @_;

	if ($^O eq 'MSWin32')  #BUMMER!:
	{
		$w->bind('<MouseWheel>' =>
		[ sub { $_[0]->yview('scroll', -($_[1] / 120) * 1, 'units') },
				Ev('D') ]
		);
	}
	else
	{

		# Support for mousewheels on Linux commonly comes through
		# mapping the wheel to buttons 4 and 5.  If you have a
		# mousewheel ensure that the mouse protocol is set to
		# "IMPS/2" in your /etc/X11/XF86Config (or XF86Config-4)
		# file:
		#
		# Section "InputDevice"
		#     Identifier  "Mouse0"
		#     Driver      "mouse"
		#     Option      "Device" "/dev/mouse"
		#     Option      "Protocol" "IMPS/2"
		#     Option      "Emulate3Buttons" "off"
		#     Option      "ZAxisMapping" "4 5"
		# EndSection

#DEPRECIATED:		$w->bind('<Alt-Left>' => sub
#DEPRECIATED:			{ 
#DEPRECIATED:				$_[0]->xview('scroll', -1, 'units');
#DEPRECIATED:				Tk->break;
#DEPRECIATED:			}
#DEPRECIATED:		);
#DEPRECIATED:		$w->bind('<Alt-Right>' => sub
#DEPRECIATED:			{ 
#DEPRECIATED:				$_[0]->xview('scroll', +1, 'units');
#DEPRECIATED:				Tk->break;
#DEPRECIATED:			}
#DEPRECIATED:		);
		#NEXT 2 ALLOW HORIZONTAL SCROLLING ON SINGLE-WHEEL MOUSE (Alt-Wheel):
		$w->bind('<Alt-Button-4>' => sub
			{ 
					$_[0]->xview('scroll', -1, 'units');
					Tk->break;
			}
		);
		$w->bind('<Alt-Button-5>' => sub
			{ 
					$_[0]->xview('scroll', +1, 'units');
					Tk->break;
			}
		);
		$w->bind('<Shift-Button-4>' => sub
		{
			$_[0]->yview('scroll', -1, 'pages') unless $Tk::strictMotif;
			Tk->break;
		}
		);

		$w->bind('<Shift-Button-5>' => sub
		{
			$_[0]->yview('scroll', +1, 'pages') unless $Tk::strictMotif;
			Tk->break;
		}
		);
		$w->bind('<Button-4>' => sub
		{
			$_[0]->yview('scroll', -1, 'units') unless $Tk::strictMotif;
		}
		);

		$w->bind('<Button-5>' => sub
		{
			$_[0]->yview('scroll', +1, 'units') unless $Tk::strictMotif;
		}
		);
		$w->bind('<Button-6>' => sub
		{
			$_[0]->xview('scroll', -1, 'units') unless $Tk::strictMotif;
		}
		);

		$w->bind('<Button-7>' => sub
		{
			$_[0]->xview('scroll', +1, 'units') unless $Tk::strictMotif;
		}
		);
	}

} # end BindMouseWheel

1
