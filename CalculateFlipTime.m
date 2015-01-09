% CalculateFlipTime.m
%
% t = CalculateFlipTime(now, beampos, vblank, vtotal, FlipInterval)
%
% Use "beampos" to calculate "Flip" time of current video frame.
%
% If beampos < vblank, then Flip time is in the future.
% If beampos > vblank, then Flip time is in the past.
%
% If Flip time is at least 3 msec in the future,
% the next Flip command should succeed, without missing the deadline.
%
% Example code for screen with 1920 x 1080 resolution
%
% vblank = 1080;    % number of visible lines on screen
% vtotal = 1110;    % number of scan lines
%                   % (includes vertical blanking interval)
% FlipInterval = Screen('GetFlipInterval', w);
% t_before = GetSecs;
% beampos = Screen('GetWindowInfo', w, 1);
%   t_after = GetSecs;
% VBL_early = CalculateFlipTime(t_before, beampos, vblank, vtotal, FlipInterval);
%   VBL_late = CalculateFlipTime(t_after, beampos, vblank, vtotal, FlipInterval);
%   t_mid = (t_before + t_after) / 2;
%   VBL_estimate = CalculateFlipTime(t_mid, beampos, vblank, vtotal, FlipInterval);
%
% [VBL_timestamp Stim_timestamp Flip_timestamp Missed Beampos ] = Screen('Flip', w);
%
% Notes:
% 1. There are (vtotal+1) scanlines, numbered from 0 to vtotal
% 2. Time difference between t_before and t_after usually less than 0.15 msec 
% 3. VBL_early under-estimates the Flip time by roughly 0.05 msec
%   ... therefore, this is a "conservative" estimate
% 4. VBL_after is roughly 0.05 msec *after* Flip time, so it is not useful
% 5. VBL_estimate gives un-biased estimate of Flip time within +/- 0.04 msec
% 6. VBL_timestamp will near VBL_estimate (if Flip deadline is not missed)
% 7. The next Flip will be missed if current "beampos" is too close to "vblank"
%   ... this occurs when delta < 2.5 msec or fraction < 0.15

function t = CalculateFlipTime(now, beampos, vblank, vtotal, FlipInterval)
    fraction = (vblank - beampos + 1) / (vtotal + 1);
    delta = FlipInterval * fraction;
    t = now + delta;
end
