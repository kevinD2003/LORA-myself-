function coefficient = ricianBlockCoefficient(packetCount, kDb)
%RICIANBLOCKCOEFFICIENT Unit-average-power flat Rician coefficient per packet.

arguments
    packetCount (1,1) double {mustBeInteger, mustBePositive}
    kDb (1,1) double {mustBeFinite}
end

validateattributes(packetCount, {'numeric'}, ...
    {'scalar', 'integer', 'positive'});
kLinear = 10^(kDb/10);
lineOfSight = sqrt(kLinear/(kLinear + 1));
scatterScale = sqrt(1/(2*(kLinear + 1)));
coefficient = lineOfSight + scatterScale*( ...
    randn(1, packetCount) + 1j*randn(1, packetCount));
end
