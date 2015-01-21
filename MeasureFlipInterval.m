% MeasureFlipInterval.m
%
% 2015-01-21 dxjones@gmail.com
%
% This program reliably measures the "Flip Interval",
% (time between vertical blanking events in the video refresh cycle)
%
% It also measures the delay between the moment the vertical blanking
% begins (VBL_timestamp) and the moment the Screen('Flip',...) command
% returns control to the main program.  On some computers, this delay is
% very brief; on others it is often close to 3 msec, which is very long.
%
% This program has been tested using:
%   Psychtoolbox version 3.0.12 - Flavor: beta - Corresponds to SVN Revision 5797
% and various iMac computers running Mac OSX 10.9.x and 10.10.x
%
% Feedback is welcome:  David Jones, dxjones@gmail.com
%

function MeasureFlipInterval(skip, finish)

%% default parameters
if nargin < 1, skip = 0; end
if nargin < 2, finish = 1; end

% number of samples used to estimate Flip Interval
Nsamples = 500;

% select s = 1 to test external display
s = 0;

Computer = Screen('Computer');
if strcmp('iMac11,3', Computer.hw.model)
    ComputerModel = 'iMac (27-inch, Mid 2010)';
    ExpectedFlipInterval = 16.6797 / 1000;
elseif strcmp('iMac13,1', Computer.hw.model)
    ComputerModel = 'iMac (21.5-inch, Late 2012)';
    ExpectedFlipInterval = 16.6850 / 1000;
elseif strcmp('iMac14,2', Computer.hw.model)
    ComputerModel = 'iMac (27-inch, Late 2013)';
    ExpectedFlipInterval = 16.6807 / 1000;
elseif strcmp('MacBookPro11,3', Computer.hw.model)
    ComputerModel = 'MacBook Pro (Retina, 15-inch, Mid 2014)';
    ExpectedFlipInterval = 16.6695 / 1000;
else
    ComputerModel = 'unknown';
    ExpectedFlipInterval = 16.6667 / 1000;
end

%% initialize data arrays

t = zeros(Nsamples,1);
d = zeros(Nsamples,1);
b = zeros(Nsamples,1);

%% adjust Psychtoolbox Preferences

PTB = [];
PTB.Verbosity = Screen('Preference', 'Verbosity', 3);
PTB.VisualDebugLevel = Screen('Preference', 'VisualDebugLevel', 1);
PTB.SkipSyncTests = Screen('Preference', 'SkipSyncTests', skip);

try

Priority(9);
HideCursor;

t0 = GetSecs;
w = Screen('OpenWindow', s);
t1 = GetSecs;
tstartup = t1 - t0;

r = Screen('Rect', s);
ScreenHeight = RectHeight(r);
ScreenWidth = RectWidth(r);

FlipInterval = Screen('GetFlipInterval', w);
winfo = Screen('GetWindowInfo', w);
vblank = winfo.VBLStartline;
vtotal = winfo.VBLEndline;

if vtotal < vblank
    vtotal = ceil(1.125 * vblank);
end

%% try to finish any tasks that may steal CPU
% 1. Matlab garbage collection
% 2. Matlab event queue
% 3. relinquish CPU for 500 msec, for OSX to do its thing

java.lang.System.gc();
drawnow;
WaitSecs(0.5);

% Initially, we are not synchronized with display refresh cycle.
% Therefore, the very first flip is often missed, which is normal.
% Make sure we complete this asynchronous flip outside the main loop.

Screen('Flip', w);

%% main loop

FlipCount = 0;
VBL_timestamp = 0;
while true
    if KbCheck || FlipCount > Nsamples
        break
    end
    
    % do some very simple graphics
    ProgressBar(FlipCount / Nsamples, w, ScreenWidth, ScreenHeight);
    
    if finish
        Screen('DrawingFinished', w, 1);
    end
    
    % Flip
    when = 0;
    VBL_prev = VBL_timestamp;
    [VBL_timestamp Stim_timestamp Flip_timestamp Missed Beampos_after_Flip ] = Screen('Flip', w, when, 1);
    Time_after_Flip = GetSecs;
    
    if FlipCount > 0
        t(FlipCount) = VBL_timestamp - VBL_prev;
        b(FlipCount) = Beampos_after_Flip;
        d(FlipCount) = Time_after_Flip - VBL_timestamp;
    end
    FlipCount = FlipCount + 1;
end

FinishGraphics;

catch e
    CatchGraphicsError(e);
end

% restore PTB settings
Screen('Preference', 'Verbosity', PTB.Verbosity);
Screen('Preference', 'VisualDebugLevel', PTB.VisualDebugLevel);
Screen('Preference', 'SkipSyncTests', PTB.SkipSyncTests);


%% post-processing

% find flip intervals within 10% of expected value
tlo = 0.9 * ExpectedFlipInterval;
thi = 1.1 * ExpectedFlipInterval;
X = (t >= tlo) & (t <= thi);
tx = t(X);

% prepare for scatter plot of sequential pairs of flip intervals
t1 = tx(1:end-1);
t2 = tx(2:end);

% sort the valid flip intervals
[tx ix] = sort(tx);
bx = b(ix);

%% plots results

if finish
    label = 'DrawingFinished called';
    color = 'bo';
    fig = 0;
else
    label = 'DrawingFinished not called';
    color = 'ro';
    fig = 10;
end

figure(fig + 1);
plot(tx * 1000, color);
xlabel('Flip Count');
ylabel('Flip Interval (msec)');
title('Measure Flip Interval');
legend(label, 'Location', 'NorthWest');

figure(fig + 2);
plot(sort(bx), color);
xlabel('Flip Count');
ylabel('Beam Position After Flip');
title('Measure Flip Interval');
legend(label, 'Location', 'NorthWest');

figure(fig + 3);
plot(t1, t2, 'go');
xlabel('First Flip Interval');
ylabel('Second Flip Interval');
title('Measure Flip Interval');
legend(label, 'Location', 'NorthWest');

%% print results

fprintf('\n');
fprintf('MeasureFlipInterval(finish = %d, skip = %d)\n', finish, skip);
fprintf('\n');
fprintf('Computer Model = %s, %s\n', Computer.hw.model, ComputerModel);
fprintf('Screen Resolution = %d x %d, vblank = %d, vtotal = %d\n', ...
    ScreenWidth, ScreenHeight, vblank, vtotal);
fprintf('Screen(''DrawingFinished'',...) ');
if finish
    fprintf('called\n');
else
    fprintf('*NOT* called\n');
end

fprintf('time in PTB startup = %10.6f seconds\n', tstartup);
fprintf('time in main loop   = %10.6f seconds\n', sum(t));
fprintf('number of flips = %4d\n', Nsamples);
fprintf('    valid flips = %4d\n', nnz(X));
fprintf('     fast flips = %4d\n', nnz(t < tlo));
fprintf('     slow flips = %4d\n', nnz(t > thi));
fprintf('\n');
fprintf('Statistics for delays after Flip (GetSecs - VBL_timestamp)\n');
TimingStatistics(d);
fprintf('Statistics for all flips:\n');
TimingStatistics(t);

% if only a subset of flips were valid, show their statistics
if nnz(X) ~= Nsamples
    fprintf('Statistics for valid flips:\n');
    TimingStatistics(tx);
end

if any(t > thi)
    fprintf('List of slow flips ...\n');
    z = (1:Nsamples)';
    z(t > thi)
end


end

function TimingStatistics(t)
    tmedian = 1000 * median(t);
    tmin = 1000 * min(t);
    tmax = 1000 * max(t);
    tmean = 1000 * mean(t);
    tstd = 1000 * std(t);
    tpercent = 100 * (tstd / tmean);
    fprintf('median =  %10.6f msec\n', tmedian);
    fprintf('min =     %10.6f msec\n', tmin);
    fprintf('max =     %10.6f msec\n', tmax);
    fprintf('mean =    %10.6f msec\n', tmean);
    fprintf('std = +/- %10.6f msec\n', tstd);
    fprintf('      +/- %7.3f percent\n', tpercent);
    fprintf('\n');
end

function ProgressBar(fraction, w, ScreenWidth, ScreenHeight)
    r = SetRect(0.1 * ScreenWidth, 0.45 * ScreenHeight, (0.1 + (fraction * 0.8)) * ScreenWidth, 0.55 * ScreenHeight);
    Screen('FillRect', w, 0, r);
end

function FinishGraphics()
    Priority(0);
    ShowCursor;
    Screen('Close');    % Free all textures and offscreen windows
    Screen('CloseAll');
    Screen('Windows');  % Better workaround for black screen problem
    %pause(0.5);
    %Screen('CloseAll');
    KbQueueStop;
    ListenChar(0);
    KbQueueRelease;
end

function CatchGraphicsError(e)
    FinishGraphics;
    fprintf('[caught PTB error]\n');
    rethrow(e);
end
