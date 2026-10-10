function config = lora_css_awgn_config()
%LORA_CSS_AWGN_CONFIG Reproduction design and simulation configuration.
%
% Paper target
%   M. A. Ben Temim, G. Ferre, and R. Tajan, "A New LoRa-like
%   Transceiver Suited for LEO Satellite Communications," Sensors,
%   vol. 22, no. 5, Art. 1830, 2022, Fig. 4.
%
% Reproduction scope
%   - Standard, uncoded LoRa CSS only (no DCSS).
%   - Complex baseband AWGN channel: y[n] = x[n] + w[n].
%   - Perfect synchronization.
%   - No Doppler, CFO, STO, fading, multipath, interference, FEC,
%     interleaving, whitening, CRC, header, or LoRaWAN framing.
%   - Natural binary mapping between each SF-bit word and symbol index.
%
% Discrete signal model
%   M = 2^SF samples per symbol and Fs = B. The unit-power up-chirp is
%       c[n] = exp(j*2*pi*(n^2/(2M) - n/2)), n = 0,...,M-1.
%   Symbol s is generated as
%       x_s[n] = c[n] * exp(j*2*pi*s*n/M).
%   Multiplication by conj(c[n]) followed by an M-point FFT places the
%   noiseless peak in bin s (zero-based).
%
% SNR convention
%   SNR = E{|x[n]|^2}/E{|w[n]|^2}. Since E{|x[n]|^2}=1,
%   E{|w[n]|^2}=10^(-SNR_dB/10), with half that variance in each real
%   component.
%
% Monte Carlo implementation
%   The waveform modulator, AWGN channel, dechirper, and FFT detector are
%   implemented and tested directly. The full SF7-SF12 sweep uses the
%   exactly equivalent FFT-domain sufficient statistics:
%     * correct bin: CN(sqrt(M*SNR), 1);
%     * M-1 wrong bins: independent CN(0, 1).
%   The maximum wrong-bin power is sampled from its exact order-statistic
%   CDF. This avoids allocating M waveform samples per trial and does not
%   use fitted or shifted BER data.
%
% Zero-error convention
%   BER is recorded as NaN when no errors are observed. The plot uses the
%   one-error upper-bound marker 1/totalBits, never BER=0 on a log axis.

config.paperDoi = "10.3390/s22051830";
config.paperFigure = 4;
config.bandwidthHz = 125e3;
config.sampleRateHz = config.bandwidthHz;
config.spreadingFactors = 7:12;
config.snrStepDb = 0.25;
config.snrDb = -26:config.snrStepDb:-5.5;
config.randomSeed = 2022;

% Adaptive Monte Carlo concentrates work at the low-BER tail. Each point
% stops after 200 observed bit errors or 3e8 simulated bits. A batch
% contains 1e5 symbols. The SNR sweep for each SF stops after obtaining a
% statistically supported BER point at or below 1e-6.
config.targetBitErrors = 200;
config.maxBitsPerPoint = 3e8;
config.batchSymbols = 100000;
config.targetBerFloor = 1e-6;
config.minimumTailBitErrors = 50;

config.channel = "complex baseband AWGN";
config.mapping = "natural binary";
config.detector = "noncoherent dechirp plus FFT peak";
config.monteCarloMode = ...
    "adaptive error-count Monte Carlo using exact FFT-domain statistics";
config.zeroErrorPolicy = ...
    "BER=NaN; plot one-error upper bound 1/total_bits";
end
