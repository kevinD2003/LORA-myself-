function [rx, diagnostics] = apply_lora_dynamic_doppler( ...
        tx, symbol, sf, startTimeSec, orbitConfig, options)
%APPLY_LORA_DYNAMIC_DOPPLER Apply single-symbol Doppler phase and AWGN.
%   [RX, DIAGNOSTICS] = APPLY_LORA_DYNAMIC_DOPPLER(TX, SYMBOL, SF,
%   STARTTIMESEC, ORBITCONFIG) applies the full instantaneous-RF Doppler
%   model to one M-sample LoRa symbol, where M = 2^SF and Fs = B.
%
%   Name-value options:
%     BandwidthHz - LoRa bandwidth and sample rate (default 250e3).
%     SNRdB       - Sample-power SNR in dB; Inf disables AWGN.
%     Mode        - "full_rf" (default),
%                   "carrier_only_approximation", or "no_doppler".
%
%   Doppler phase is obtained by trapezoidal integration of Doppler
%   frequency. No Doppler compensation or FFT-bin shift is applied.

arguments
    tx {mustBeNumeric}
    symbol
    sf
    startTimeSec (1, 1) double
    orbitConfig (1, 1) struct
    options.BandwidthHz (1, 1) double = 250e3
    options.SNRdB (1, 1) double = Inf
    options.Mode (1, 1) string = "full_rf"
end

basebandFrequencyHz = lora_symbol_instantaneous_frequency( ...
    symbol, sf, options.BandwidthHz);
m = numel(basebandFrequencyHz);

if ~isvector(tx) || numel(tx) ~= m
    error("lora:InvalidWaveformLength", ...
        "TX must contain exactly 2^SF samples for one LoRa symbol.");
end
if any(~isfinite(tx), "all")
    error("lora:InvalidWaveform", ...
        "All transmitted waveform samples must be finite.");
end
if ~isfinite(startTimeSec)
    error("lora:InvalidStartTime", ...
        "The symbol start time must be finite.");
end
if isnan(options.SNRdB) || options.SNRdB == -Inf
    error("lora:InvalidSnr", ...
        "SNRdB must be finite or positive infinity.");
end

allowedModes = [ ...
    "full_rf", ...
    "carrier_only_approximation", ...
    "no_doppler"];
if ~any(options.Mode == allowedModes)
    message = "Mode must be 'full_rf', " + ...
        "'carrier_only_approximation', or 'no_doppler'.";
    error("lora:InvalidDopplerMode", message);
end

requiredFields = ["carrierFrequencyHz", "speedOfLightMps"];
for fieldName = requiredFields
    if ~isfield(orbitConfig, fieldName)
        error("lora:MissingOrbitConfiguration", ...
            "Orbit configuration field '%s' is required.", fieldName);
    end
end

tx = tx(:);
inputSignalPower = mean(abs(tx).^2);
if abs(inputSignalPower - 1) > 1e-10
    error("lora:NonUnitSignalPower", ...
        "The transmitted waveform must have unit average sample power.");
end

sampleRateHz = options.BandwidthHz;
sampleTimeSec = startTimeSec + (0:m-1).'/sampleRateHz;
orbit = lora_orbit_doppler_trajectory(sampleTimeSec, orbitConfig);

if options.Mode == "full_rf"
    instantaneousRfHz = orbitConfig.carrierFrequencyHz + ...
        basebandFrequencyHz;
elseif options.Mode == "carrier_only_approximation"
    instantaneousRfHz = repmat( ...
        orbitConfig.carrierFrequencyHz, m, 1);
else
    instantaneousRfHz = zeros(m, 1);
end

if options.Mode == "no_doppler"
    dopplerFrequencyHz = zeros(m, 1);
else
    dopplerFrequencyHz = -instantaneousRfHz.* ...
        orbit.radialVelocityMps/orbitConfig.speedOfLightMps;
end
phaseIncrementRad = pi/sampleRateHz*( ...
    dopplerFrequencyHz(1:end-1) + dopplerFrequencyHz(2:end));
dopplerPhaseRad = [0; cumsum(phaseIncrementRad)];
phaseRotation = exp(1i*dopplerPhaseRad);
noiselessRx = tx.*phaseRotation;

if isinf(options.SNRdB)
    noiseVariance = 0;
    noise = complex(zeros(m, 1));
else
    noiseVariance = 10^(-options.SNRdB/10);
    noise = sqrt(noiseVariance/2)*( ...
        randn(m, 1) + 1i*randn(m, 1));
end
rx = noiselessRx + noise;

diagnostics = struct( ...
    "sampleRateHz", sampleRateHz, ...
    "sampleTimeSec", sampleTimeSec, ...
    "basebandFrequencyHz", basebandFrequencyHz, ...
    "instantaneousRfHz", instantaneousRfHz, ...
    "radialVelocityMps", orbit.radialVelocityMps, ...
    "dopplerFrequencyHz", dopplerFrequencyHz, ...
    "dopplerPhaseRad", dopplerPhaseRad, ...
    "phaseRotation", phaseRotation, ...
    "noiseVariance", noiseVariance, ...
    "inputSignalPower", inputSignalPower, ...
    "noiselessOutputPower", mean(abs(noiselessRx).^2), ...
    "mode", options.Mode, ...
    "integrationRule", "trapezoidal");
end
