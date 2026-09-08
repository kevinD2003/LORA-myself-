function formalPoint = v3RunFormalSnrPoint(root,config,parameters,manifest,preregistered,snrIndex)
%V3RUNFORMALSNRPOINT Checkpointed complete-pass sampling for one SNR.

snrDb = preregistered.snrDb(snrIndex);
schedule = v3ContinuousPassSchedule(config);
safeSnr = sprintf('%+03ddB',snrDb);
checkpointPath = fullfile(root,'results','formal', ...
    ['snr_' safeSnr '_v2_checkpoint.mat']);
signature = sprintf('%s|formal-v2|snr=%d|min=%d|max=%d|budget=%d', ...
    manifest.algorithmSignature,snrDb,preregistered.minimumPasses, ...
    preregistered.maximumPasses,preregistered.softBitErrorBudgetPerMethod);
if isfile(checkpointPath)
    state = v3LoadCheckpoint(checkpointPath,signature);
else
    state = struct('completedPasses',0,'records',table(), ...
        'passDiagnostics',repmat(struct('passIndex',0,'snrDb',0, ...
        'symbolCfoSquaredErrorSum',zeros(3,2,112), ...
        'symbolCfoObservationCount',zeros(3,2)),0,1), ...
        'stoppingReason','incomplete');
end
while state.completedPasses < preregistered.maximumPasses && ...
        strcmp(state.stoppingReason,'incomplete')
    passIndex = state.completedPasses+1;
    [passRecords,passDiagnostic] = v3RunCompletePass( ...
        config,parameters,schedule,snrDb,snrIndex,passIndex);
    if isempty(state.records)
        state.records = passRecords;
    else
        state.records = [state.records;passRecords];
    end
    state.completedPasses = passIndex;
    state.passDiagnostics(passIndex) = passDiagnostic;
    totals = groupsummary(state.records,'methodName','sum','softBitErrors');
    budgetReached = all(totals.sum_softBitErrors >= ...
        preregistered.softBitErrorBudgetPerMethod);
    if passIndex >= preregistered.minimumPasses && budgetReached
        state.stoppingReason = 'minimum complete passes and error budget reached';
    elseif passIndex >= preregistered.maximumPasses
        state.stoppingReason = 'maximum complete passes reached';
    else
        state.stoppingReason = 'incomplete';
    end
    v3WriteCheckpointAtomic(checkpointPath,state,signature);
    fprintf('V3 formal SNR %d dB pass %d/%d: %s\n',snrDb,passIndex, ...
        preregistered.maximumPasses,state.stoppingReason);
    if ~strcmp(state.stoppingReason,'incomplete')
        break
    end
end
formalPoint = struct('snrDb',snrDb,'completedPasses',state.completedPasses, ...
    'stoppingReason',state.stoppingReason,'records',state.records, ...
    'passDiagnostics',state.passDiagnostics, ...
    'signature',signature,'algorithmSignature',manifest.algorithmSignature, ...
    'preregistered',preregistered);
matPath = fullfile(root,'results','formal',['snr_' safeSnr '_formal_v2.mat']);
csvPath = fullfile(root,'results','formal',['snr_' safeSnr '_records_v2.csv']);
save(matPath,'formalPoint','-v7.3');
writetable(state.records,csvPath);
end
