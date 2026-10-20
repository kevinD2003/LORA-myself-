function phaseMatrix = prefecPacketOraclePhase(c,payloadPhysicalBins,layout,startSec,initialPhaseRad)
%PREFECPACKETORACLEPHASE Offline reproduction of frozen native phase only.
% Payload truth reproduces the waveform CSS-frequency term in evaluation;
% this helper must never be called by the actual Doppler receiver.
m = c.samplesPerSymbol;
bins = zeros(layout.physicalSymbolCount,1);
bins(layout.dataRows) = payloadPhysicalBins;
baseHz = zeros(layout.physicalSymbolCount,m);
for row = 1:layout.physicalSymbolCount
    baseHz(row,:) = v4SymbolFrequency(bins(row),c).';
end
total = layout.physicalSymbolCount*m;
time = startSec+(0:total-1).'/c.sampleRateHz;
orbit = v4Trajectory(time,c);
serial = reshape(baseHz.',[],1);
doppler = -(c.carrierFrequencyHz+serial).*orbit.radialVelocityMps/c.speedOfLightMps;
phase = initialPhaseRad+[0;cumsum(pi/c.sampleRateHz* ...
    (doppler(1:end-1)+doppler(2:end)))];
phaseMatrix = reshape(phase,m,layout.physicalSymbolCount).';
end
