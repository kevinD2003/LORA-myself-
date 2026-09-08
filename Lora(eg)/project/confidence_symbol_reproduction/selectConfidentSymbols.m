function mask = selectConfidentSymbols(confidence, tauBlock, tauGlobal, mode)
%SELECTCONFIDENTSYMBOLS Select confidence symbols using adaptive thresholds.

arguments
    confidence (:,1) double
    tauBlock (1,1) double
    tauGlobal (1,1) double
    mode (1,1) string = "global"
end

switch mode
    case "global"
        mask = confidence >= tauGlobal;
    case "block"
        mask = confidence >= tauBlock;
    case "both"
        mask = confidence >= tauGlobal & confidence >= tauBlock;
    otherwise
        error("SenLoRa:UnknownThresholdMode", ...
            "Unknown threshold mode: %s.", mode);
end

end
