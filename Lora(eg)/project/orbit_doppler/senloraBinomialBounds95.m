function [lower95,upper95] = senloraBinomialBounds95(errorCount,totalCount)
%SENLORABINOMIALBOUNDS95 Two-sided 95% Clopper-Pearson bounds.

arguments
    errorCount (1,1) double {mustBeInteger,mustBeNonnegative}
    totalCount (1,1) double {mustBeInteger,mustBeNonnegative}
end

if errorCount > totalCount
    error("SenLoRa:InvalidBinomialCounts", ...
        "errorCount must not exceed totalCount.");
end
if totalCount == 0
    lower95 = NaN;
    upper95 = NaN;
    return
end

alpha = 0.05;
if errorCount == 0
    lower95 = 0;
    upper95 = 1-(alpha/2)^(1/totalCount);
elseif errorCount == totalCount
    lower95 = (alpha/2)^(1/totalCount);
    upper95 = 1;
else
    lower95 = betainv(alpha/2,errorCount,totalCount-errorCount+1);
    upper95 = betainv(1-alpha/2,errorCount+1,totalCount-errorCount);
end
end
