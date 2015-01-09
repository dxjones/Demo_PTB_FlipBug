# Demo_PTB_FlipBug

This Matlab code demonstrates an apparent timing bug in Psychtoolbox Screen('Flip') command.

This was posted to the Psychtoolbox Forum 2015-01-09.

# Summary

I am looking for help tracking down a frustrating Flip timing bug.

The misbehaviour only occurs when more than one FlipInterval has elapsed since the last Screen('Flip') command.

I think the difficulty arises from the complex logic inside Screen('Flip') that tries to calculate whether it should sleep (and for how long) before executing the actual Flip.

If there was a way to force Screen('Flip') to do a busy-wait-loop instead of sleeping, that might be useful for investigating this apparent bug.

Here is my situation:

	PsychtoolboxVersion = 3.0.12 - Flavor: beta - Corresponds to SVN Revision 5727.
	iMac "Late 2013" (OSX 10.9.5, 3.5GHz i7, 16 GB ram, NVIDIA GTX 780M 4MB vram.
	Kernel Driver installed.

# First, the good news, the part that works:

I get very accurate "beam positions" using this command:

    beampos = Screen('GetWindowInfo', w, 1);

I also get extremely precise "VBL timestamps" using this command:

    [VBL_timestamp Stim_timestamp Flip_timestamp Missed Beampos_after_Flip ] = Screen('Flip', w, 0,1);

These commands tell me the correct "Flip Interval", VBL start line, and VBL end line.

	FlipInterval = Screen('GetFlipInterval', w);
	winfo = Screen('GetWindowInfo', w);
	vblank = winfo.VBLStartline;
	vtotal = winfo.VBLEndline;

My iMac display resolution is 2560x1440, with vblank = 1440 and vtotal = 1480.

I wrote a tight loop that waits a random fraction of a Flip Interval,
and then queries the beam position and calls Screen('Flip').

When the beam position before I call Flip is early in the frame (0-1040), the Flip occurs in the same video frame.
When the beam position is later in the frame (1040-1480), within a few msec of the VBL_Startline, the Flip is "missed" and it occurs in the next video frame.
All of this works as expected.


# Now for the bad news, the part that doesn't work:

When I add this single line inside my loop, most of the Screen('Flip') commands will miss their deadline.

	WaitSecs(2*FlipInterval);

But the missed Flips are not random:
Flips will still succeed if the beam position is 0-300,
but Flips will usually fail when beam position is 300-1480.

The boundary between successful and failed Flips seems to be shifted by 740 beam positions, which is exactly 1/2 of vtotal.
This corresponds to a time-shift of 0.5 * FlipInterval, or about 8.3 msec.
This makes me very suspicious that the missed Flips could be due to a bug.

The remarkable precision of the beam positions and VBL timestamps gives me some confidence that this bug could be found and fixed.

Any thoughts Mario?



As the program runs, it draws a crude scatter plot using PTB,
with the x-axis showing "beam position before Flip",
and the y-axis showing "beam position after Flip".
Successful Flips are shown in green; missed Flips are shown in red.

Set "ShowBug" to false to see good behvaiour, without missed Flips.
Set "ShowBug" to true to see bad behaviour, with missed Flips.

The program will keep going until it has sampled 80% of all possible beam positions.

Type "escape" to finish the program early.

The beam position and timing data are plotted in 3 Matlab figures.


# Evidence

I have included PDFs showing Matlab plots that illustrate this Flip timing bug.

