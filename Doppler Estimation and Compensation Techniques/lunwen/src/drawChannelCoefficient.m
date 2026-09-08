function coefficient = drawChannelCoefficient(cfg, packetCount, sampleCount)
%DRAWCHANNELCOEFFICIENT Draw the channel coefficient for one packet batch.

arguments
    cfg (1,1) struct
    packetCount (1,1) double {mustBeInteger, mustBePositive}
    sampleCount (1,1) double {mustBeInteger, mustBePositive} = 1
end

model = string(cfg.channel.model);
switch model
    case "rician"
        coefficient = ricianBlockCoefficient( ...
            packetCount, cfg.channel.ricianKDb);
    case "awgn_only"
        coefficient = ones(sampleCount, packetCount);
    case "rician_sample"
        kLinear = 10^(cfg.channel.ricianKDb/10);
        lineOfSight = sqrt(kLinear/(kLinear + 1));
        scatterScale = sqrt(1/(2*(kLinear + 1)));
        coefficient = lineOfSight + scatterScale*( ...
            randn(sampleCount, packetCount) + ...
            1j*randn(sampleCount, packetCount));
    otherwise
        error('drawChannelCoefficient:UnknownModel', ...
            'Unknown channel model: %s.', model);
end
end
