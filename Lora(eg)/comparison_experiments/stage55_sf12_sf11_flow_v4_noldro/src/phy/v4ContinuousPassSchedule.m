function schedule = v4ContinuousPassSchedule(config,options)
%V4CONTINUOUSPASSSCHEDULE Complete common-timeline frames over one pass.

arguments
    config (1,1) struct
    options.PassStartTimeSec (1,1) double = NaN
    options.PassEndTimeSec (1,1) double = NaN
end
[window,~] = v4VisibilityWindow(config);
startTime = options.PassStartTimeSec;
endTime = options.PassEndTimeSec;
if ~isfinite(startTime), startTime = -window.deltaTimeOutSec; end
if ~isfinite(endTime), endTime = window.deltaTimeOutSec; end
if endTime <= startTime
    error('V4:PassBounds','Pass end must be after pass start.');
end
frameDuration = config.commonTimelineSymbolCount*config.symbolDurationSec;
span = endTime-startTime;
frameCount = floor(span/frameDuration+10*eps(max(1,span/frameDuration)));
index = (1:frameCount).';
frameStart = startTime+(index-1)*frameDuration;
frameEnd = frameStart+frameDuration;
frameCenter = (frameStart+frameEnd)/2;
visibleDuration = zeros(frameCount,1);
for interval = 1:size(window.intervalsSec,1)
    visibleDuration = visibleDuration+max(0,min(frameEnd, ...
        window.intervalsSec(interval,2))-max(frameStart,window.intervalsSec(interval,1)));
end
visibleFraction = min(1,max(0,visibleDuration/frameDuration));
tolerance = 100*eps(max(1,frameDuration));
fullyVisible = visibleFraction >= 1-tolerance;
fullyBlind = visibleFraction <= tolerance;
metricEligible = fullyVisible;
schedule = struct('passStartTimeSec',startTime,'passEndTimeSec',endTime, ...
    'frameDurationSec',frameDuration, ...
    'noMidambleFrameDurationSec',config.noMidambleFrameSymbolCount* ...
        config.symbolDurationSec, ...
    'frameCount',frameCount,'frameIndex',index, ...
    'frameStartTimeSec',frameStart,'frameCenterTimeSec',frameCenter, ...
    'frameEndTimeSec',frameEnd,'visibleFraction',visibleFraction, ...
    'fullyVisible',fullyVisible,'fullyBlind',fullyBlind, ...
    'transitionFrame',~fullyVisible & ~fullyBlind, ...
    'metricEligible',metricEligible,'window',window);
end

