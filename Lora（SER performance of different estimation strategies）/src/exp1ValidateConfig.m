function exp1ValidateConfig(config)
%EXP1VALIDATECONFIG Fail fast on frozen-configuration drift.

p = config.parent;
checks = {
    p.physicalSf == 12, 'SF must be 12';
    p.bandwidthHz == 125e3, 'bandwidth must be 125 kHz';
    p.sampleRateHz == 125e3, 'sample rate must be 125 kHz';
    p.effectiveDataSf == 12, 'LDRO must remain off';
    p.cr == 3, 'engineering CR marker must remain CR3';
    p.informationBitCount == 768, 'information-bit count must be 768';
    p.payloadSymbolCount == 112, 'data-symbol count must be 112';
    p.bootstrapPilotCount == 8, 'bootstrap count must be 8';
    p.paperMidambleCount == 37, 'Paper midamble count must be 37';
    p.commonTimelineSymbolCount == 157, 'common timeline must be 157T';
    abs(p.symbolDurationSec-0.032768) < 1e-15, 'symbol duration drift';
    abs(p.fftBinSpacingHz-30.517578125) < 1e-12, 'physical-bin drift';
    isequal(config.orbitStartSec,[-366 -274.5 -183 -91.5 0]), ...
        'orbit anchors drift';
    isequal(config.snrDb,[-24 -21.12]), 'formal SNR matrix drift'};
for row = 1:size(checks,1)
    if ~checks{row,1}
        error('EXP1:FrozenConfig','%s.',checks{row,2});
    end
end
if ~isfolder(config.parentRoot)
    error('EXP1:ParentMissing','Frozen parent directory is missing: %s', ...
        config.parentRoot);
end
end

