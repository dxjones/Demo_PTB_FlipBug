% CatchGraphicsError.m

function CatchGraphicsError(me, func)
    
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

    fprintf('[caught PTB error in "%s"]\n', func);
    
    rethrow(me);
end
