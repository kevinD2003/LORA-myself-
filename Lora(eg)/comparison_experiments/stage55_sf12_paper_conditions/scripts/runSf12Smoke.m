function records = runSf12Smoke(options)
%RUNSF12SMOKE Four paired packets per Case at the representative SNR.

arguments
    options.PacketsPerCase (1,1) double {mustBeInteger,mustBePositive} = 4
    options.SnrDb (1,1) double = -21
end
root = sf12SetupPaths();
cfg = sf12PaperCommonConfig();
records = table();
for caseName = ["case1","case2"]
    for packet = 1:options.PacketsPerCase
        r = sf12PairedFrameSimulation(cfg,caseName,options.SnrDb, ...
            packet,"validation",1);
        row = struct2table(rmfield(r,{ ...
            'paperFirstEffectiveDataIndex','stage55FirstEffectiveDataIndex', ...
            'payloadSymbols','trueDataCfoHz','paperEstimatedCfoHz', ...
            'stage55EstimatedCfoHz','stage55AcceptedMask'}));
        records = [records;row]; %#ok<AGROW>
    end
end
folder = fullfile(root,'results','validation');
if ~isfolder(folder), mkdir(folder); end
writetable(records,fullfile(folder,'sf12_smoke_packets.csv'));
save(fullfile(folder,'sf12_smoke_packets.mat'),'records','cfg');
end
