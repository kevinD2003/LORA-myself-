function detectedSymbol = lora_css_demodulate_dynamic_channel(rx, sf)
%LORA_CSS_DEMODULATE_DYNAMIC_CHANNEL Detect without Doppler compensation.
%   DETECTEDSYMBOL = LORA_CSS_DEMODULATE_DYNAMIC_CHANNEL(RX, SF) forwards
%   the Doppler-distorted waveform to the original noncoherent
%   dechirp-FFT peak detector. No Doppler correction or FFT-bin shift is
%   performed.

detectedSymbol = lora_css_demodulate(rx, sf);
end
