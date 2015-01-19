% MeasureFlipInterval.m
%
% 2015-01-19 dxjones@gmail.com
%

function MeasureFlipInterval(finish, skip)

% default parameters
if nargin < 1, finish = 1; end
if nargin < 2, skip = 0; end

% number of samples used to estimate Flip Interval
N = 500;

% select s = 1 to test external display
s = 0;

Computer = Screen('Computer');
if strcmp('iMac13,1', Computer.hw.model)
    ComputerModel = 'iMac "Late 2012"';
    ExpectedFlipInterval = 16.6850 / 1000;
elseif strcmp('iMac14,2', Computer.hw.model)
    ComputerModel = 'iMac "Late 2013"';
    ExpectedFlipInterval = 16.6807 / 1000;
else
    ComputerModel = 'unknown';
    ExpectedFlipInterval = 16.6667 / 1000;
end

%%
% adjust Psychtoolbox Preferences

PTB = [];
PTB.Verbosity = Screen('Preference', 'Verbosity', 0);
PTB.VisualDebugLevel = Screen('Preference', 'VisualDebugLevel', 0);
PTB.SkipSyncTests = Screen('Preference', 'SkipSyncTests', skip);

try

Priority(9);

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

%%

FlipTotal = N;

t = zeros(FlipTotal,1);
b = zeros(FlipTotal,1);

% try to finish any tasks that may steal CPU
% 1. Matlab garbage collection
% 2. Matlab event queue
% 3. relinquish CPU for 500 msec, for OSX to do its thing

java.lang.System.gc();
drawnow;
WaitSecs(0.5);

% since we are not yet synchronized with refresh cycle,
% the very first flip is often missed, which is expected
% so let's get this flip outside main loop

Screen('Flip', w);

% main loop

FlipCount = 0;
VBL_timestamp = 0;
while true
    if KbCheck || FlipCount > FlipTotal
        break
    end
    
    p = FlipCount / FlipTotal;
    ProgressBar(p, w, ScreenWidth, ScreenHeight);
    
    if finish
        Screen('DrawingFinished', w, 1);
    end
    
    % Flip
    
    when = 0;

    VBL_prev = VBL_timestamp;
    [VBL_timestamp Stim_timestamp Flip_timestamp Missed Beampos_after_Flip ] = Screen('Flip', w, when, 1);
    
    if FlipCount > 0
        t(FlipCount) = VBL_timestamp - VBL_prev;
        b(FlipCount) = Beampos_after_Flip;
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


%%
% post-processing

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
fprintf('number of flips = %4d\n', FlipTotal);
fprintf('    valid flips = %4d\n', nnz(X));
fprintf('     fast flips = %4d\n', nnz(t < tlo));
fprintf('     slow flips = %4d\n', nnz(t > thi));
fprintf('\n');
fprintf('Statistics for all flips:\n');
TimingStatistics(t);

% if only a subset of flips were valid, show their statistics
if nnz(X) ~= FlipTotal
    fprintf('Statistics for valid flips:\n');
    TimingStatistics(tx);
end

if any(t > thi)
    fprintf('List of slow flips ...\n');
    z = (1:FlipTotal)';
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

function ProgressBar(percent, w, ScreenWidth, ScreenHeight)
    r = SetRect(0.1 * ScreenWidth, 0.45 * ScreenHeight, (0.1 + (percent * 0.8)) * ScreenWidth, 0.55 * ScreenHeight);
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

function CatchGraphicsError(me, func)
    FinishGraphics;
    fprintf('[caught PTB error in "%s"]\n', func);
    rethrow(me);
end
