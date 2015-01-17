% DisplayTiming.m
%
% 2015-01-15 dxjones@gmail.com
%
%
% "delay" parameter controls number of extra FlipIntervals
% to wait before next Screen('Flip') command
%
% in my experience, when delay == 0, we avoid missed Flips
%
% depending on which iMac I test, different delay values
% reliably cause missed Flips.
%
% examples:
% iMac with resolution 2560x1440 missed flips with delay == 2
% iMac with resolution 1920x1080 missed flips with delay == 4

function delta = DisplayTiming(delay, finish)

if nargin < 1
    delay = 2;
elseif delay > 30
    delay = 30;
end

if nargin < 2
    finish = 0;
end
finish = 1;

try

Priority(9);

% select s = 1 to test external display
s = 0;

Screen('Preference', 'SkipSyncTests', 1);

w = Screen('OpenWindow', s);

FlipInterval = Screen('GetFlipInterval', w);
FlipInterval = 0.01667;
winfo = Screen('GetWindowInfo', w);
vblank = winfo.VBLStartline;
vtotal = winfo.VBLEndline;

% - - - - -
r = Screen('Rect', s);
ScreenHeight = RectHeight(r);
ScreenWidth = RectWidth(r);

fprintf('Screen Resolution = %d x %d\n', ScreenWidth, ScreenHeight);
fprintf('vblank = %d\n', vblank);
fprintf('vtotal = %d\n', vtotal);

if vtotal < vblank
    vtotal = ceil(1.125 * vblank);
end

%%
Screen('TextFont', w, 'Menlo');
FontSize = 18;
Screen('TextSize', w, FontSize);
Screen('TextStyle', w, 1);
Screen('DrawText', w, 'Display Timing', 0.02*ScreenWidth, 2*FontSize, 0);
Screen('TextStyle', w, 0);

menu = { ...
    '    Delay:'; ...
    '0 - 0 frames'; ...
    '1 - 1 frame'; ...
    '2 - 2 frames'; ...
    '3 - 3 frames'; ...
    '4 - 4 frames'; ...
    ' '; ...
    '    Flicker:'; ...
    '5 -  5 Hz'; ...
    '6 - 10 Hz'; ...
    '7 - 15 Hz'; ...
    '8 - 30 Hz'; ...
    '9 - Max'; ...
    ' '; ...
    'Esc - return to Main Menu'
    };
Nrows = size(menu, 1);
ty = 0.1*ScreenHeight;
for i = 1:Nrows
    Screen('DrawText', w, menu{i}, 0.02 * ScreenWidth, ty, 0);
    ty = ty + 1.5*FontSize;
end

info = { ...
    sprintf('width  = %d', ScreenWidth); ...
    sprintf('height = %d', ScreenHeight); ...
    sprintf('vblank = %d', vblank); ...
    sprintf('vtotal = %d', vtotal); ...
    sprintf('frame rate = %9.6f Hz', FrameRate); ...
    sprintf('interval   = %9.6f ms', FlipInterval*1000); ...
    sprintf('std dev    = %9.6f ms', 0.0); ...
    };
Nrows = size(info, 1);
ty = 0.9*ScreenHeight - Nrows * 1.5 * FontSize;
for i = 1:Nrows
    Screen('DrawText', w, info{i}, 0.02 * ScreenWidth, ty, 0);
    ty = ty + 1.5*FontSize;
end

%%

cx = ScreenWidth/2;
cy = ScreenHeight/2;
zx = cx - (vtotal/2);
zy = cy - (vtotal-vblank)/2;
radius = 0.45 * min(ScreenHeight, ScreenWidth);
% x0 = (ScreenWidth/2) - (vtotal/2);
% x1 = x0 + vtotal;
x0 = 0.20 * ScreenWidth;
x1 = 0.95 * ScreenWidth;
x_vblank = x0 + (x1-x0) * (vblank/vtotal);
y0 = 0.10 * ScreenHeight;
y1 = 0.90 * ScreenHeight;
y_vblank = y1 - (y1-y0) * (vblank/vtotal);
% - - - - -

    r = SetRect(x0, y0, x1, y1);
    Screen('FillRect', w, 255-16, r);
    Screen('FrameRect', w, 128, r);
%     Screen('DrawLine', w, 128, x0,y0, x0,y1);
%     Screen('DrawLine', w, 128, x1,y0, x1,y1);
%     Screen('DrawLine', w, 128, x0,y0, x1,y0);
%     Screen('DrawLine', w, 128, x0,y1, x1,y1);
    Screen('DrawLine', w, 128, x_vblank,y0, x_vblank,y1);
    Screen('DrawLine', w, 128, x0,y_vblank, x1,y_vblank);

% - - - - -

N = 1 + vtotal;
beam = false(N,1);
vt = zeros(N,1);
m = zeros(N,1);
bp = zeros(N,1);
t_pre = zeros(N,1);
t_post = zeros(N,1);
t_mid = zeros(N,1);

vt_pre = zeros(N,1);
vt_post = zeros(N,1);
vt_mid = zeros(N,1);

% main loop includes random delays to get a variety of beam positions
% "beamcount" controls how many different beam positions we need
% Caution: main loop will become very slow if beamcount > 0.95 * vtotal

beamcount = 0.75 * vtotal;

flicker = 0;
FlickerHeight = 0.09 * ScreenWidth;
FlickerRectLeft = SetRect(0.02*ScreenWidth, cy, 0.11*ScreenWidth, cy + FlickerHeight);
FlickerRectRight = SetRect(0.11*ScreenWidth, cy, 0.20*ScreenWidth-1, cy + FlickerHeight);

five_hertz = false;
Duration = 15;          % Flicker for 10 seconds
NominalFrameRate = 60;  % roughly 60 Hz
FlickerFrequency = 15;
FrameCount= round(NominalFrameRate / (2*FlickerFrequency));
FlipTotal = (Duration * NominalFrameRate) / FrameCount;

delta = zeros(FlipTotal,1);

VBL_timestamp = 0;
FlipCount = 0;
tstart = GetSecs;
while true
    if nnz(beam) >= beamcount
        break
    end
    if five_hertz && FlipCount > FlipTotal
        break
    end
    if KbCheck
        break
    end
    
    % simple animation shows progress through loop
    if five_hertz
        p = FlipCount / FlipTotal;
    else
        p = nnz(beam) / beamcount;
    end
    ProgressBar(p, w, ScreenWidth, ScreenHeight);
    
    Screen('FillRect', w, flicker, FlickerRectLeft);
    flicker = 255 - flicker;
    Screen('FillRect', w, flicker, FlickerRectRight);
   
    if finish
        Screen('DrawingFinished', w, 1);
    end
 
    if five_hertz
        if VBL_timestamp ~= 0
            when = VBL_timestamp + (FrameCount - 0.75) * FlipInterval;
            now = GetSecs;
            WaitSecs(when - now);
        end
    else
        % wait a random delay
        WaitSecs(rand * FlipInterval);

        % possibly wait several frames
        if delay > 0
            WaitSecs(delay*FlipInterval);
        end
    end
    
    % wait for a beampos we haven't seen before
    while true
        t0 = GetSecs;
        beampos = Screen('GetWindowInfo', w, 1);
        t1 = GetSecs;
        b = 1 + beampos;
        if ~beam(b)
            beam(b) = true;
            break
        end
        if five_hertz
            break
        end
    end
    
    % Flip
    
    when = 0;

    VBL_prev = VBL_timestamp;
    [VBL_timestamp Stim_timestamp Flip_timestamp Missed Beampos_after_Flip ] = Screen('Flip', w, when, 1);
    if FlipCount > 0
        delta(FlipCount) = VBL_timestamp - VBL_prev;
    end
    FlipCount = FlipCount + 1;
    
    % Calculate Flip Time
    % (normally, this calculation would be done before the Flip)
    
    t_pre(b) = t0;
    t_post(b) = t1;
    t_mid(b) = (t0 + t1) / 2;
    
    vt_pre(b) = CalculateFlipTime(t_pre(b), beampos, vblank, vtotal, FlipInterval);
    vt_post(b) = CalculateFlipTime(t_post(b), beampos, vblank, vtotal, FlipInterval);
    vt_mid(b) = CalculateFlipTime(t_mid(b), beampos, vblank, vtotal, FlipInterval);
    
    FlipDelta = VBL_timestamp - vt_mid(b);
    
    % record actual VBL, etc.
    vt(b) = VBL_timestamp;
    m(b) = Missed;
    bp(b) = Beampos_after_Flip;
    
%     fprintf('Beampos_after_Flip = %d\n', Beampos_after_Flip);
    
    % - - - - -
    px = x0 + (x1-x0) * (b/vtotal);
    py = y1 - (y1-y0) * (Beampos_after_Flip / vtotal);


    if FlipDelta < (FlipInterval/2)
        color = [0 255 0 255];
        Screen('FillRect', w, color, [px 0.95*ScreenHeight px+1 0.98*ScreenHeight]);
    else
        color = [255 0 0 255];
        Screen('FillRect', w, color, [px 0.92*ScreenHeight px+1 0.95*ScreenHeight]);
    end
    Screen('FillRect', w, color, [px-2 py-3 px+2 py+3]);
    
%     fprintf('[ %4d %4d %4d %4d ]\n', px-2, py-3, px+2, py+3);
    
    % - - - - -
end
tstop = GetSecs;

elapsed = tstop - tstart
fps = FlipCount / elapsed
interval = 1000 / fps

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

scanline = 0:vtotal;

scanlines_per_msec = (vtotal+1) / (1000 * FlipInterval);


%%
% Figure 1 shows Beampos before/after Flip
%
% Notice Beampos after Flip is almost always ...
%   between vblank and vtotal, occasionally wraps around
%

% adjust returned beampos to wrap around past the end of vtotal
% X = bp < (vtotal/2);
% bp( X ) = bp( X ) + (1+vtotal);

figure(1);
subplot(3,1,1);
plot(vtotal*[0 1],[0 0],'k:', ...
    vtotal*[0 1], vblank*[1 1],'k:',...
    vtotal*[0 1], vtotal*[1 1],'k:', ...
    [0 0], vtotal*[0 1],'k:', ...
    vblank*[1 1], vtotal*[0 1], 'k:', ...
    vtotal*[1 1], vtotal*[0 1], 'k:', ...
    scanline(beam),bp(beam),'r.');

xlabel('Beampos before Flip');
ylabel('Beampos after Flip');
title(sprintf('Beam position before and after Flip, delay = %d', delay));
text(vtotal/2, vblank, 'VBLANK');
text(vtotal/2, vtotal, 'VTOTAL');
axis([0 vtotal 0 vtotal+20]);

%%
% Figure 2 shows accuracy of Calculated Flip Time
%
% Notice blue data points are very close to zero

delta_pre = vt - vt_pre;
delta_post = vt - vt_post;
delta_mid = vt - vt_mid;

figure(1);
subplot(3,1,3);
plot(vtotal*[0 1],[0 0],'k:', ...
    vtotal*[0 1],1000*FlipInterval*[1 1],'k:', ...
    vtotal*[0 1],(vtotal+1)*[1 1],'k:', ...
    vblank*[1 1],1000*FlipInterval*[-1 2],'k:', ...
    vtotal*[1 1],1000*FlipInterval*[-1 2],'k:', ...
    scanline(beam),1000*delta_pre(beam),'g.', ...
    scanline(beam),1000*delta_mid(beam),'b.', ...
    scanline(beam),1000*delta_post(beam),'r.');
axis([0 vtotal -0.5 0.5]);
xlabel('Beampos before Flip');
ylabel('Flip Time Prediction Error (msec)');
title(sprintf('Flip Time Prediction Error vs Beam Position, delay = %d', delay));

%%
% Figure 3 highlights missed Flips

figure(1);
subplot(3,1,2);
plot(vtotal*[0 1],[0 0],'k:', ...
    vtotal*[0 1],1000*FlipInterval*[1 1],'k:', ...
    vtotal*[0 1],(vtotal+1)*[1 1],'k:', ...
    vblank*[1 1],1000*FlipInterval*[-1 2],'k:', ...
    vtotal*[1 1],1000*FlipInterval*[-1 2],'k:', ...
    scanline(beam),1000*delta_pre(beam),'g.', ...
    scanline(beam),1000*delta_mid(beam),'b.', ...
    scanline(beam),1000*delta_post(beam),'r.');
axis([0 vtotal 1000*FlipInterval-0.5 1000*FlipInterval+0.5]);
xlabel('Beampos before Flip');
ylabel('Flip Time Prediction Error (msec)');
title(sprintf('Flip Time Prediction vs Beam Position ... (Missed Flips), delay = %d', delay));

set(1, 'PaperPosition', [0.25 0.25 8 10.5]);
filename = sprintf('fig-%d.pdf', delay);
print(filename, '-dpdf');

end

function ProgressBar(percent, w, ScreenWidth, ScreenHeight)
    r = SetRect(0.2 * ScreenWidth, 0.02 * ScreenHeight, (0.2 + (percent * 0.75)) * ScreenWidth, 0.08 * ScreenHeight);
    Screen('FillRect', w, 0, r);
end

