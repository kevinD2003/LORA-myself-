%RUN_SENLORA_CONFIDENCE_DEMO Minimal SenLoRa confidence-symbol reproduction.
% This demo verifies the confidence-symbol detection chain from the paper:
% FFT-bin probability -> Gray-bit LLR -> soft Hamming decode ->
% symbol confidence -> adaptive threshold selection.

clear; clc;

cfg.sf = 7;
cfg.cr = 3;
cfg.alpha = 0.8;
cfg.probMode = "paper";
cfg.amendMode = "identity";
cfg.thresholdMode = "global";
cfg.maxIter = 5;

rng(7);
dataNibbles = randi([0 15], cfg.sf, 1);
targetBins = nibblesToDemoBins(dataNibbles, cfg);

% Strong symbols should be selected more often than weak symbols.
symbolSnrDb = [18 17 7 16 5 15 6]';
[payloadFft, preambleFft] = synthesizeDemoSpectra(targetBins, cfg.sf, symbolSnrDb);

[result, history] = iterativeSoftDemodBlockFromFft(payloadFft, preambleFft, cfg);

fprintf("SenLoRa confidence-symbol demo\n");
fprintf("SF=%d, CR=%d, symbols/block=%d\n", cfg.sf, cfg.cr, cfg.cr + 4);
fprintf("Target bins:       %s\n", mat2str(targetBins'));
fprintf("Symbol SNR (dB):   %s\n", mat2str(symbolSnrDb'));
fprintf("Confidence scores: %s\n", mat2str(result.confidence, 4));
fprintf("Block threshold:   %.4f\n", result.tauBlock);
fprintf("Global threshold:  %.4f\n", result.tauGlobal);
fprintf("Selected symbols:  %s\n", mat2str(result.confidentIdx'));
fprintf("Decoded nibbles:   %s\n", mat2str(result.decodedNibbles'));
fprintf("Iterations:        %d (converged=%d)\n", result.iterations, result.converged);
fprintf("History entries:   %d\n", numel(history));

figure("Name", "SenLoRa confidence-symbol detection");
bar(result.confidence, "FaceColor", [0.2 0.45 0.85]);
hold on;
yline(result.tauGlobal, "r--", "Global threshold");
yline(result.tauBlock, "k:", "Block threshold");
hold off;
grid on;
xlabel("Symbol index in interleaving block");
ylabel("sum |LLR|^2");
title("Confidence-symbol detection");
