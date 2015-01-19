% MeasureFlipInterval.m
%
% 2015-01-19 dxjones@gmail.com
%

function MeasureFlipInterval(finish, skip)

% default parameters
if nargin < 1, finish = 1, end
if nargin < 2, skip = 0, end

% number of samples used to estimate Flip Interval
N = 200;

Computer = Screen('Computer');
if strcmp('iMac13,1', Computer.hw.model)    % iMac "Late 2012"
    ExpectedFlipInterval = 16.685 / 1000;
else
    ExpectedFlipInterval = 16.667 / 1000;
end

try

% select s = 1 to test external display
s = 0;

Priority(9);

Screen('Preference', 'SkipSyncTests', skip);

w = Screen('OpenWindow', s);

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

%%
% post-processing

tlo = 0.9 * ExpectedFlipInterval;
thi = 1.1 * ExpectedFlipInterval;
X = (t >= tlo) & (t <= thi);
[tx ix] = sort(t(X));
bx = b(ix);

%%

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


%% print output results

fprintf('Screen Resolution = %d x %d\n', ScreenWidth, ScreenHeight);
fprintf('vblank = %d\n', vblank);
fprintf('vtotal = %d\n', vtotal);
fprintf('finish = %d ... ' , finish);
if finish
    fprintf('DrawingFinished called\n');
else
    fprintf('no DrawingFinished\n');
end



fprintf('elapsed time = %10.6f seconds\n', sum(t));
fprintf('number of flips = %4d\n', FlipTotal);
fprintf('    valid flips = %4d\n', nnz(X));
fprintf('     fast flips = %4d\n', nnz(t < tlo));
fprintf('     slow flips = %4d\n', nnz(t > thi));
fprintf('Statistics for all flips:\n');
fprintf('median = %10.6f msec\n', 1000 * median(t));
fprintf('min =    %10.6f msec\n', 1000 * min(t));
fprintf('max =    %10.6f msec\n', 1000 * max(t));
fprintf('mean =   %10.6f\n', 1000 * mean(t));
fprintf('std =    %10.6f\n', 1000 * std(t));
fprintf('Statistics for valid flips:\n');
fprintf('median = %10.6f msec\n', 1000 * median(tx));
fprintf('min =    %10.6f msec\n', 1000 * min(tx));
fprintf('max =    %10.6f msec\n', 1000 * max(tx));
fprintf('mean =   %10.6f\n', 1000 * mean(tx));
fprintf('std =    %10.6f\n', 1000 * std(tx));
if any(t > thi)
fprintf('List of slow flips ...\n');
z = (1:FlipTotal)';
z(t > thi)
end


end

function ProgressBar(percent, w, ScreenWidth, ScreenHeight)
    r = SetRect(0.2 * ScreenWidth, 0.45 * ScreenHeight, (0.2 + (percent * 0.6)) * ScreenWidth, 0.55 * ScreenHeight);
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

