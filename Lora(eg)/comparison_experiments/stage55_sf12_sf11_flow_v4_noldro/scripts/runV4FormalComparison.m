function formal = runV4FormalComparison(options)
%RUNV4FORMALCOMPARISON Preregistered paired complete-pass SNR experiment.

arguments
    options.UseParallel (1,1) logical = true
end

root = v4SetupPaths();
config = sf12NoLdroSf11FlowConfig();
[parameters,manifest] = v4LoadFrozenReceiverParameters(config);
preregistered = struct('snrDb',config.snrDb.', ...
    'minimumPasses',5,'maximumPasses',20, ...
    'softBitErrorBudgetPerMethod',200, ...
    'checkpointEveryCompleteFrames',96, ...
    'stopOnlyAtCompletePassBoundary',true, ...
    'pairedByFrame',true,'formalSeedDomain','formal');

point = cell(numel(preregistered.snrDb),1);
useParallel = options.UseParallel && license('test','Distrib_Computing_Toolbox');
if useParallel
    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool('local',4); %#ok<NASGU>
    end
    parfor snrIndex = 1:numel(preregistered.snrDb)
        point{snrIndex} = v4RunFormalSnrPoint(root,config,parameters, ...
            manifest,preregistered,snrIndex);
    end
else
    for snrIndex = 1:numel(preregistered.snrDb)
        point{snrIndex} = v4RunFormalSnrPoint(root,config,parameters, ...
            manifest,preregistered,snrIndex);
    end
end
formal = struct('preregistered',preregistered,'points',{point}, ...
    'algorithmSignature',manifest.algorithmSignature, ...
    'parameterStatus',manifest.status);
save(fullfile(root,'results','formal','v4_formal_comparison_v2.mat'), ...
    'formal','-v7.3');
if useParallel
    delete(gcp('nocreate'));
end
end
