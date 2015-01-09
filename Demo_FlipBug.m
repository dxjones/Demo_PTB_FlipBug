% Demo_FlipBug.m
%
% 2015-01-08 dxjones@gmail.com
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

function Demo_FlipBug(delay)

if nargin < 1
    delay = 0;
elseif delay > 30
    delay = 30;
end

try

Priority(9);

% select s = 1 to test external display
s = 0;

w = Screen('OpenWindow', s);

FlipInterval = Screen('GetFlipInterval', w);
winfo = Screen('GetWindowInfo', w);
vblank = winfo.VBLStartline;
vtotal = winfo.VBLEndline;

% - - - - -
r = Screen('Rect', s);
ScreenHeight = RectHeight(r);
ScreenWidth = RectWidth(r);
cx = ScreenWidth/2;
cy = ScreenHeight/2;
zx = cx - (vtotal/2);
zy = cy - (vtotal-vblank)/2;
radius = 0.45 * min(ScreenHeight, ScreenWidth);
x0 = (ScreenWidth/2) - (vtotal/2);
x1 = x0 + vtotal;
x_vblank = x0 + (x1-x0) * (vblank/vtotal);
y0 = 0.10 * ScreenHeight;
y1 = y0 + 0.80 * ScreenHeight;
y_vblank = y1 - (y1-y0) * (1/1.5);
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

beamcount = 0.80 * vtotal;

VBL_timestamp = 0;
while true
    if nnz(beam) >= beamcount
        break
    end
    if KbCheck
        break
    end
    
    % simple animation shows progress through loop
    y = nnz(beam);
    Screen('DrawLine', w, 0, 100,y, 400,y);
 
    % wait a random delay
    WaitSecs(rand * FlipInterval);
    
    if delay > 0
        WaitSecs(delay*FlipInterval);
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
%         break
    end
    
    % Flip
    
    when = 0;
%     when = GetSecs + 0.010;
    [VBL_timestamp Stim_timestamp Flip_timestamp Missed Beampos_after_Flip ] = Screen('Flip', w, when,1);
    
    % Calculate Flip Time
    % (normally, this would be done before the Flip)
    
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
    
    % - - - - -
    px = x0 + (x1-x0) * (b/vtotal);
    py = y1 - (y1-y0) * ((Beampos_after_Flip - vblank) / (1.5*(vtotal - vblank)));

    Screen('DrawLine', w, 128, x0,y0, x0,y1);
    Screen('DrawLine', w, 128, x1,y0, x1,y1);
    Screen('DrawLine', w, 128, x0,y0, x1,y0);
    Screen('DrawLine', w, 128, x0,y1, x1,y1);
    Screen('DrawLine', w, 128, x_vblank,y0, x_vblank,y1);
    Screen('DrawLine', w, 128, x0,y_vblank, x1,y_vblank);

    if FlipDelta < (FlipInterval/2)
        color = [0 255 0 255];
    else
        color = [255 0 0 255];
        Screen('FillRect', w, color, [px-1 y1+10 px+1 y1+110]);
    end
    Screen('FillRect', w, color, [px-1 py-3 px+1 py+3]);
    % - - - - -
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

scanline = 0:vtotal;

scanlines_per_msec = (vtotal+1) / (1000 * FlipInterval);

% guess at beampos deadline for successful flips
% vdeadline = 0.75 * vblank;


%%
% Figure 1 shows Beampos before/after Flip
%
% Notice Beampos after Flip is almost always ...
%   between vblank and vtotal, occasionally wraps around
%

% adjust returned beampos to wrap around past the end of vtotal
X = bp < (vtotal/2);
bp( X ) = bp( X ) + (1+vtotal);

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
axis([0 vtotal vblank-20 vtotal+20]);

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
axis([0 vtotal -0.2 0.2]);
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
axis([0 vtotal 1000*FlipInterval-0.2 1000*FlipInterval+0.2]);
xlabel('Beampos before Flip');
ylabel('Flip Time Prediction Error (msec)');
title(sprintf('Flip Time Prediction vs Beam Position ... (Missed Flips), delay = %d', delay));

set(1, 'PaperPosition', [0.25 0.25 8 10.5]);
filename = sprintf('fig-%d.pdf', delay);
print(filename, '-dpdf');

end

