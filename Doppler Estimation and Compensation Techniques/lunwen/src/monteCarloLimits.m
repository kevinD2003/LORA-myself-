function limits = monteCarloLimits(cfg, mode)
%MONTECARLOLIMITS Return the locked full or smoke stopping conditions.

arguments
    cfg (1,1) struct
    mode (1,1) string
end

mode = string(mode);
if mode == "full"
    source = cfg.monteCarlo;
elseif mode == "smoke"
    source = cfg.smoke;
else
    error('monteCarloLimits:UnknownMode', 'Unknown mode: %s', mode);
end
limits.batchPackets = source.batchPackets;
limits.minimumPackets = source.minimumPackets;
limits.maximumPackets = source.maximumPackets;
limits.minimumSymbolErrors = source.minimumSymbolErrors;
end
