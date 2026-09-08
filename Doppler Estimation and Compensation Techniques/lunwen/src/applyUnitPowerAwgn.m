function [received, noiseVariance] = applyUnitPowerAwgn(signal, snrDb, cfg)
%APPLYUNITPOWERAWGN Add AWGN using explicit 0 dBW transmit-signal power.
% Never replace the third argument with 'measured'. Noise power must not
% track the instantaneous Rician fading realization.

arguments
    signal double
    snrDb (1,1) double {mustBeFinite}
    cfg (1,1) struct
end

signalPowerDbw = cfg.channel.explicitSignalPowerDbw;
% LoRa is complex baseband even when the dechirped symbol is constant.
% Force complex storage so awgn adds circular complex noise on every path.
signal = complex(signal);
[received, noiseVariance] = awgn(signal, snrDb, signalPowerDbw);
end
