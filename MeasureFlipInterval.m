% MeasureFlipInterval.m
%
% 2015-01-19 dxjones@gmail.com
%

function MeasureFlipInterval(finish)

if nargin < 1
    finish = 1;
end

% number of samples used to estimate Flip Interval
N = 200;

try

% select s = 1 to test external display
s = 0;

java.lang.System.gc();
drawnow;
WaitSecs(0.5);

Priority(9);

Screen('Preference', 'SkipSyncTests', 1);

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

% hocus-pocus to make sure we close all windows
wlist = Screen('Windows');
Screen('CloseAll');
Priority(0);

catch e
    CatchGraphicsError(e, 'BeginGraphics');

    % hocus-pocus to make sure we close all windows
    wlist = Screen('Windows');
    Screen('CloseAll');
    Priority(0);
end

%%

if finish
    label = 'DrawingFinished called';
    color = 'bo';
else
    label = 'DrawingFinished not called';
    color = 'ro';
end
figure(1+finish);
plot(1:FlipTotal, sort(t) * 1000, color);
xlabel('Flip Count');
ylabel('Flip Interval (msec)');
title('Measure Flip Interval');
% ylim([0 35]);
if finish
    label = 'DrawingFinished called';
else
    label = 'DrawingFinished not called';
end
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
fprintf('number of flips = %d\n', FlipTotal);
fprintf('median = %10.6f msec\n', 1000 * median(t));
fprintf('min =    %10.6f msec\n', 1000 * min(t));
fprintf('max =    %10.6f msec\n', 1000 * max(t));
fprintf('mean =   %10.6f\n', 1000 * mean(t));
fprintf('std =    %10.6f\n', 1000 * std(t));


end

function ProgressBar(percent, w, ScreenWidth, ScreenHeight)
    r = SetRect(0.2 * ScreenWidth, 0.45 * ScreenHeight, (0.2 + (percent * 0.6)) * ScreenWidth, 0.55 * ScreenHeight);
    Screen('FillRect', w, 0, r);
end

