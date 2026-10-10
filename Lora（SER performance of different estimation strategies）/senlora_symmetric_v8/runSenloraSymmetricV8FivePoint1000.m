function output = runSenloraSymmetricV8FivePoint1000(options)
%RUNSENLORASYMMETRICV8FIVEPOINT1000 Fresh 1000-packet five-point run.

arguments
    options.WorkerCount (1,1) double {mustBeInteger,mustBePositive} = 4
end

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','scripts'));
paths = exp1SetupPaths();
addpath(here);
config = exp1Config();
c = config.parent;
plan = senloraSymmetricV8Config(config);
parameters = v4LoadMethodAlignedR3ParametersV1();
targetTimeSec = [-366;-274.5;-183;-91.5;0];
packetCount = 1000;
rootSeed = 1032500000;
pointCount = numel(targetTimeSec);
shape = [pointCount,packetCount];

manifestPath = fullfile(here,'v8_frozen_receiver_manifest.json');
theoryPath = fullfile(fileparts(paths.projectRoot),'Lora(theory)', ...
    'ideal_stage55_ser','results','ideal_ser_theory.csv');
localValidateFrozenManifest(manifestPath,here,plan);
theory = readtable(theoryPath);
theoryRow = theory(abs(theory.snrDb+21)<1e-12,:);
if height(theoryRow)~=1
    error('EXP5V8:FivePointTheory','Expected one theory row at -21 dB.');
end
theorySer = theoryRow.ser;

root = fullfile(paths.resultsRoot,'senlora_symmetric_v8','five_point_1000');
if ~isfolder(root)
    mkdir(root);
end
checkpointPath = fullfile(root,'FIVE_POINT_1000_CHECKPOINT.mat');
signature = localSignature(plan,config,parameters,targetTimeSec, ...
    packetCount,rootSeed,manifestPath,theoryPath);
if isfile(checkpointPath)
    state = load(checkpointPath);
    localValidateCheckpoint(state,signature,shape);
else
    state = struct('signature',signature, ...
        'senloraErrors',nan(shape), ...
        'idealErrors',nan(shape), ...
        'firstErrors',nan(shape), ...
        'acceptedBlocks',zeros(shape,'uint8'), ...
        'maximumResidualBins',nan(shape), ...
        'cfoRmseBins',nan(shape), ...
        'rateGain',nan(shape), ...
        'failed',false([shape,2]), ...
        'failureMessage',strings([shape,2]), ...
        'usesForbiddenInput',false(shape), ...
        'payloadSeed',zeros(shape), ...
        'noiseSeed',zeros(shape), ...
        'completed',false(shape));
    state.stateDigest = localDigest(state);
end

if any(~state.completed,'all')
    pool = gcp('nocreate');
    if isempty(pool)
        parpool('local',options.WorkerCount);
    elseif pool.NumWorkers~=options.WorkerCount
        error('EXP5V8:WorkerCount', ...
            'The existing parallel pool has the wrong worker count.');
    end
end

for blockStart = 1:10:packetCount
    packetIds = blockStart:min(packetCount,blockStart+9);
    [pointRows,packetColumns] = find(~state.completed(:,packetIds));
    if isempty(pointRows)
        continue
    end
    jobPoints = pointRows;
    jobPackets = packetIds(packetColumns).';
    jobCount = numel(jobPoints);
    jobSenlora = nan(jobCount,1);
    jobIdeal = nan(jobCount,1);
    jobFirst = nan(jobCount,1);
    jobAccepted = zeros(jobCount,1,'uint8');
    jobResidual = nan(jobCount,1);
    jobCfoRmse = nan(jobCount,1);
    jobGain = nan(jobCount,1);
    jobFailed = false(jobCount,2);
    jobMessage = strings(jobCount,2);
    jobForbidden = false(jobCount,1);
    jobPayloadSeed = zeros(jobCount,1);
    jobNoiseSeed = zeros(jobCount,1);
    parfor job = 1:jobCount
        packet = localEvaluate(jobPoints(job),jobPackets(job), ...
            targetTimeSec,rootSeed,config,plan,parameters);
        jobSenlora(job) = packet.senloraErrors;
        jobIdeal(job) = packet.idealErrors;
        jobFirst(job) = packet.firstErrors;
        jobAccepted(job) = packet.acceptedBlocks;
        jobResidual(job) = packet.maximumResidualBins;
        jobCfoRmse(job) = packet.cfoRmseBins;
        jobGain(job) = packet.rateGain;
        jobFailed(job,:) = packet.failed;
        jobMessage(job,:) = packet.failureMessage;
        jobForbidden(job) = packet.usesForbiddenInput;
        jobPayloadSeed(job) = packet.payloadSeed;
        jobNoiseSeed(job) = packet.noiseSeed;
    end
    for job = 1:jobCount
        point = jobPoints(job);
        packetId = jobPackets(job);
        state.senloraErrors(point,packetId) = jobSenlora(job);
        state.idealErrors(point,packetId) = jobIdeal(job);
        state.firstErrors(point,packetId) = jobFirst(job);
        state.acceptedBlocks(point,packetId) = jobAccepted(job);
        state.maximumResidualBins(point,packetId) = jobResidual(job);
        state.cfoRmseBins(point,packetId) = jobCfoRmse(job);
        state.rateGain(point,packetId) = jobGain(job);
        state.failed(point,packetId,:) = reshape(jobFailed(job,:),[1,1,2]);
        state.failureMessage(point,packetId,:) = ...
            reshape(jobMessage(job,:),[1,1,2]);
        state.usesForbiddenInput(point,packetId) = jobForbidden(job);
        state.payloadSeed(point,packetId) = jobPayloadSeed(job);
        state.noiseSeed(point,packetId) = jobNoiseSeed(job);
        state.completed(point,packetId) = true;
    end
    state.stateDigest = localDigest(state);
    localSaveCheckpoint(checkpointPath,state);
    fprintf(['Five-point-1000 frames=%d/%d; errors SenLoRa/Ideal=%d/%d; ' ...
        'failures=%d\n'],sum(state.completed,'all'),numel(state.completed), ...
        sum(state.senloraErrors,'all','omitnan'), ...
        sum(state.idealErrors,'all','omitnan'), ...
        sum(state.failed,'all'));
end

if ~all(state.completed,'all')
    error('EXP5V8:FivePointIncomplete','Five-point run is incomplete.');
end
[raw,summary,paired] = localTables(state,targetTimeSec,c,theorySer, ...
    plan,rootSeed);
checks = localChecks(state,summary,c,theorySer,plan,rootSeed);
writetable(raw,fullfile(root,'FIVE_POINT_1000_RAW_PACKETS.csv'));
writetable(summary,fullfile(root,'FIVE_POINT_1000_SUMMARY.csv'));
writetable(paired,fullfile(root,'FIVE_POINT_1000_PAIRED_DIFFERENCES.csv'));
save(fullfile(root,'FIVE_POINT_1000_RESULT.mat'),'-struct','state','-v7.3');
save(fullfile(root,'FIVE_POINT_1000_CHECKS.mat'),'checks','summary', ...
    'paired','-v7.3');
localPlot(summary,root);
output = struct('status','FIVE_POINT_1000_COMPLETE', ...
    'summary',summary,'paired',paired,'checks',checks,'root',root);
end

function packet = localEvaluate( ...
        pointIndex,packetId,targetTimeSec,rootSeed,config,plan,parameters)
c = config.parent;
key = struct('planVersion',plan.identity,'phase','five-point-1000', ...
    'track','negative-five-point','channel','AWGN', ...
    'comparisonMode','frozen-v8-vs-ideal','snrDb',plan.snrDb, ...
    'replicateId',packetId,'packetId',packetId, ...
    'eventType','single-native-frame','eventIndex',pointIndex, ...
    'sampleIndex',0);
ledger = v4EventRandomLedger(rootSeed,key);
packet = struct('senloraErrors',NaN,'idealErrors',NaN, ...
    'firstErrors',NaN,'acceptedBlocks',uint8(0), ...
    'maximumResidualBins',NaN,'cfoRmseBins',NaN,'rateGain',NaN, ...
    'failed',false(1,2),'failureMessage',strings(1,2), ...
    'usesForbiddenInput',false,'payloadSeed',ledger.payloadSeed, ...
    'noiseSeed',ledger.noiseSeed);
try
    frame = senloraSymmetricV8GenerateFrame( ...
        config,targetTimeSec(pointIndex),plan.snrDb,ledger);
    common = v4CommonBootstrap(frame.observation.rxPhysical( ...
        frame.observation.layout.bootstrapRows,:),c, ...
        SearchStepBins=parameters.searchStepBins);
catch exception
    packet.failed(:) = true;
    packet.failureMessage(:) = string(exception.message);
    return
end

try
    senlora = senloraSymmetricV8Decode( ...
        frame.observation,common,config,plan);
    truth = frame.truth.payloadPhysicalBins(:);
    packet.senloraErrors = sum( ...
        senlora.detectedPhysicalBins(:)~=truth);
    packet.firstErrors = sum( ...
        senlora.firstPassDetectedPhysicalBins(:)~=truth);
    packet.acceptedBlocks = uint8(sum(senlora.blockAccepted));
    packet.maximumResidualBins = max(abs(senlora.selectedResidualBins));
    packet.cfoRmseBins = sqrt(mean( ...
        (senlora.estimatedCfoBins(:)-frame.truth.dataCfoBins(:)).^2));
    packet.rateGain = senlora.rateGain;
    packet.usesForbiddenInput = ...
        localFlag(senlora,'usesPayloadTruth') || ...
        localFlag(senlora,'usesOrbitTruth') || ...
        localFlag(senlora,'usesCaseIdentity') || ...
        localFlag(senlora,'usesSnrInput') || ...
        localFlag(senlora,'usesTargetSer') || ...
        localFlag(senlora,'usesExplicitMidambles');
catch exception
    packet.senloraErrors = NaN;
    packet.firstErrors = NaN;
    packet.acceptedBlocks = uint8(0);
    packet.maximumResidualBins = NaN;
    packet.cfoRmseBins = NaN;
    packet.rateGain = NaN;
    packet.failed(1) = true;
    packet.failureMessage(1) = string(exception.message);
end

try
    ideal = exp1IdealDecode(frame,config);
    packet.idealErrors = sum( ...
        ideal.detectedPhysicalBins(:)~=frame.truth.payloadPhysicalBins(:));
catch exception
    packet.idealErrors = NaN;
    packet.failed(2) = true;
    packet.failureMessage(2) = string(exception.message);
end
end

function value = localFlag(result,name)
value = isfield(result,name) && logical(result.(name));
end

function signature = localSignature( ...
        plan,config,parameters,targetTimeSec,packetCount,rootSeed, ...
        manifestPath,theoryPath)
names = {'runSenloraSymmetricV8FivePoint1000', ...
    'senloraSymmetricV8Config','senloraSymmetricV8GenerateFrame', ...
    'senloraSymmetricV8Decode','senloraSymmetricV8JointBlockDecode', ...
    'senloraSymmetricV8BlockLikelihood', ...
    'senloraSymmetricV8BlendBootstrap','exp1IdealDecode', ...
    'v4CommonBootstrap','v4EventRandomLedger','v4DecodePayload'};
explicitPaths = strings(numel(names),1);
for index = 1:numel(names)
    path = which(names{index});
    if isempty(path)
        error('EXP5V8:Dependency','Cannot resolve %s.',names{index});
    end
    explicitPaths(index) = string(path);
end
required = string(matlab.codetools.requiredFilesAndProducts( ...
    which('runSenloraSymmetricV8FivePoint1000')));
allPaths = unique([required(:);explicitPaths]);
inScope = startsWith(allPaths,string(config.projectRoot)+filesep, ...
    'IgnoreCase',true) | startsWith(allPaths, ...
    string(config.parentRoot)+filesep,'IgnoreCase',true);
sourcePaths = sort(allPaths(inScope));
sourceHashes = strings(size(sourcePaths));
for index = 1:numel(sourcePaths)
    sourceHashes(index) = exp1Sha256(sourcePaths(index));
end
parameterPaths = [string(fullfile(fileparts(which( ...
    'v4LoadMethodAlignedParametersV1')), ...
    'method_aligned_selected_parameters_v1.json')); ...
    string(parameters.sourcePath)];
parameterPaths = unique(parameterPaths,'stable');
parameterHashes = strings(size(parameterPaths));
for index = 1:numel(parameterPaths)
    parameterHashes(index) = exp1Sha256(parameterPaths(index));
end
signature = struct('identity','V8-FIVE-POINT-1000-V1', ...
    'receiverIdentity',plan.identity, ...
    'receiverVersion',plan.receiverVersion, ...
    'phase','five-point-1000','rootSeed',rootSeed, ...
    'snrDb',plan.snrDb,'targetTimeSec',targetTimeSec, ...
    'packetsPerPoint',packetCount,'d0Bins',plan.driftBlendStartBins, ...
    'd1Bins',plan.driftBlendEndBins, ...
    'commonSearchStepBins',parameters.searchStepBins, ...
    'executionSourcePaths',sourcePaths, ...
    'executionSourceSha256',sourceHashes, ...
    'parameterSourcePaths',parameterPaths, ...
    'parameterSourceSha256',parameterHashes, ...
    'frozenManifestPath',string(manifestPath), ...
    'frozenManifestSha256',exp1Sha256(manifestPath), ...
    'theoryPath',string(theoryPath), ...
    'theorySha256',exp1Sha256(theoryPath));
end

function localValidateFrozenManifest(path,sourceRoot,plan)
manifest = jsondecode(fileread(path));
if isfield(manifest,'parametersFrozen') && ~manifest.parametersFrozen
    error('EXP5V8:FrozenManifest','Manifest is not frozen.');
end
if ~strcmp(manifest.officialEntry,'senloraSymmetricV8Decode') || ...
        manifest.parameters.d0Bins~=plan.driftBlendStartBins || ...
        manifest.parameters.d1Bins~=plan.driftBlendEndBins || ...
        manifest.formalStarted
    error('EXP5V8:FrozenManifest','Frozen manifest identity mismatch.');
end
sourceNames = {'senloraSymmetricV8Config.m', ...
    'senloraSymmetricV8Decode.m','senloraSymmetricV8JointBlockDecode.m', ...
    'senloraSymmetricV8BlockLikelihood.m', ...
    'senloraSymmetricV8BlendBootstrap.m', ...
    'senloraSymmetricV8GenerateFrame.m'};
for index = 1:numel(sourceNames)
    field = matlab.lang.makeValidName(sourceNames{index});
    actual = exp1Sha256(fullfile(sourceRoot,sourceNames{index}));
    if ~strcmpi(manifest.sourceSha256.(field),actual)
        error('EXP5V8:FrozenManifest', ...
            'Frozen source mismatch: %s.',sourceNames{index});
    end
end
end

function localValidateCheckpoint(state,signature,shape)
required = {'signature','senloraErrors','idealErrors','firstErrors', ...
    'acceptedBlocks','maximumResidualBins','cfoRmseBins','rateGain', ...
    'failed','failureMessage','usesForbiddenInput','payloadSeed', ...
    'noiseSeed','completed','stateDigest'};
for index = 1:numel(required)
    if ~isfield(state,required{index})
        error('EXP5V8:Checkpoint','Missing field %s.',required{index});
    end
end
if ~strcmp(jsonencode(state.signature),jsonencode(signature)) || ...
        ~isequal(size(state.senloraErrors),shape) || ...
        ~isequal(size(state.failed),[shape,2]) || ...
        ~isequal(size(state.completed),shape) || ...
        ~strcmp(state.stateDigest,localDigest(state))
    error('EXP5V8:Checkpoint','Five-point checkpoint is incompatible.');
end
end

function localSaveCheckpoint(path,state)
temporary = path+".tmp.mat";
save(temporary,'-struct','state','-v7.3');
probe = load(temporary);
if ~strcmp(probe.stateDigest,localDigest(probe))
    error('EXP5V8:CheckpointWrite','Checkpoint digest verification failed.');
end
[moved,message] = movefile(temporary,path,'f');
if ~moved
    error('EXP5V8:CheckpointWrite','%s',message);
end
end

function hash = localDigest(state)
digest = java.security.MessageDigest.getInstance('SHA-256');
bytes = getByteStreamFromArray({state.signature,state.senloraErrors, ...
    state.idealErrors,state.firstErrors,state.acceptedBlocks, ...
    state.maximumResidualBins,state.cfoRmseBins,state.rateGain, ...
    state.failed,state.failureMessage,state.usesForbiddenInput, ...
    state.payloadSeed,state.noiseSeed,state.completed});
digest.update(typecast(uint8(bytes(:)),'int8'));
hash = lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end

function [raw,summary,paired] = ...
        localTables(state,targetTimeSec,c,theorySer,plan,rootSeed)
pointCount = size(state.senloraErrors,1);
packetCount = size(state.senloraErrors,2);
rawRows = cell(pointCount*packetCount,18);
row = 0;
for point = 1:pointCount
    for packetId = 1:packetCount
        row = row+1;
        rawRows(row,:) = {point,targetTimeSec(point),packetId, ...
            state.payloadSeed(point,packetId),state.noiseSeed(point,packetId), ...
            double(state.senloraErrors(point,packetId)), ...
            double(state.idealErrors(point,packetId)), ...
            double(state.firstErrors(point,packetId)), ...
            double(state.senloraErrors(point,packetId))/c.payloadSymbolCount, ...
            double(state.idealErrors(point,packetId))/c.payloadSymbolCount, ...
            double(state.acceptedBlocks(point,packetId)), ...
            state.maximumResidualBins(point,packetId), ...
            state.cfoRmseBins(point,packetId),state.rateGain(point,packetId), ...
            state.failed(point,packetId,1),state.failed(point,packetId,2), ...
            state.usesForbiddenInput(point,packetId),rootSeed};
    end
end
raw = cell2table(rawRows,'VariableNames',{ ...
    'pointIndex','orbitStartSec','packetId','payloadSeed','noiseSeed', ...
    'senloraRawErrors','idealRawErrors','firstRawErrors','senloraSer', ...
    'idealSer','acceptedBlocks','maximumResidualBins','cfoRmseBins', ...
    'rateGain','senloraFailed','idealFailed','usesForbiddenInput','rootSeed'});

summaryRows = cell(pointCount,21);
pairedRows = cell(pointCount,7);
stream = RandStream('mt19937ar','Seed',rootSeed+2718);
for point = 1:pointCount
    senlora = double(state.senloraErrors(point,:)).';
    ideal = double(state.idealErrors(point,:)).';
    senloraFailed = reshape(state.failed(point,:,1),[],1);
    idealFailed = reshape(state.failed(point,:,2),[],1);
    senlora(senloraFailed) = NaN;
    ideal(idealFailed) = NaN;
    accepted = double(state.acceptedBlocks(point,:)).';
    residual = state.maximumResidualBins(point,:).';
    cfoRmse = state.cfoRmseBins(point,:).';
    gain = state.rateGain(point,:).';
    accepted(senloraFailed) = NaN;
    residual(senloraFailed) = NaN;
    cfoRmse(senloraFailed) = NaN;
    gain(senloraFailed) = NaN;
    difference = (senlora-ideal)/c.payloadSymbolCount;
    bounds = localPairedBounds(difference,stream,10000);
    validSenlora = sum(isfinite(senlora));
    validIdeal = sum(isfinite(ideal));
    validPaired = sum(isfinite(difference));
    senloraTotal = sum(senlora,'omitnan');
    idealTotal = sum(ideal,'omitnan');
    summaryRows(point,:) = {point,targetTimeSec(point),packetCount, ...
        validSenlora,validIdeal,senloraTotal,idealTotal, ...
        localSer(senloraTotal,validSenlora,c.payloadSymbolCount), ...
        localSer(idealTotal,validIdeal,c.payloadSymbolCount),theorySer, ...
        senloraTotal>=idealTotal,senloraTotal>0,idealTotal>0, ...
        mean(accepted,'omitnan'),min(accepted,[],'omitnan'), ...
        max(residual,[],'omitnan'),sqrt(mean(cfoRmse.^2,'omitnan')), ...
        mean(gain,'omitnan'), ...
        sum(state.failed(point,:,:),'all'), ...
        sum(state.usesForbiddenInput(point,:)),plan.snrDb};
    pairedRows(point,:) = {targetTimeSec(point),validPaired, ...
        mean(difference,'omitnan'),bounds(1),bounds(2),bounds(1)>0,10000};
end
summary = cell2table(summaryRows,'VariableNames',{ ...
    'pointIndex','orbitStartSec','packets','validSenloraPackets', ...
    'validIdealPackets','senloraRawErrors','idealRawErrors', ...
    'senloraSer','idealSer','exactTheorySer', ...
    'senloraNotBetterThanIdeal','senloraNonzero','idealNonzero', ...
    'meanAcceptedBlocks','minimumAcceptedBlocks','maximumResidualBins', ...
    'cfoRmseBins','meanGain','receiverFailures','forbiddenUseCount','snrDb'});
paired = cell2table(pairedRows,'VariableNames',{ ...
    'orbitStartSec','validPairedPackets','meanPairedSerDifference', ...
    'lower95','upper95','significantlyWorse','bootstrapDraws'});
end

function value = localSer(errors,validPackets,symbolsPerPacket)
if validPackets==0
    value = NaN;
else
    value = errors/(validPackets*symbolsPerPacket);
end
end

function checks = localChecks(state,summary,c,theorySer,plan,rootSeed)
allPointsNonzero = all(summary.senloraNonzero & summary.idealNonzero);
allOrdered = all(summary.senloraNotBetterThanIdeal);
if allPointsNonzero && allOrdered && ~any(state.failed,'all') && ...
        ~any(state.usesForbiddenInput,'all')
    status = 'FIVE_POINT_1000_PASS';
else
    status = 'FIVE_POINT_1000_ACCEPTANCE_FAIL';
end
senloraValues = state.senloraErrors;
idealValues = state.idealErrors;
senloraValues(state.failed(:,:,1)) = NaN;
idealValues(state.failed(:,:,2)) = NaN;
validSenlora = sum(isfinite(senloraValues),'all');
validIdeal = sum(isfinite(idealValues),'all');
senloraErrors = sum(senloraValues,'all','omitnan');
idealErrors = sum(idealValues,'all','omitnan');
checks = struct('status',status, ...
    'rootSeed',rootSeed,'packetsPerPoint',size(state.completed,2), ...
    'totalFrames',numel(state.completed), ...
    'validSenloraFrames',validSenlora,'validIdealFrames',validIdeal, ...
    'senloraRawErrors',senloraErrors,'idealRawErrors',idealErrors, ...
    'senloraSer',localSer(senloraErrors,validSenlora,c.payloadSymbolCount), ...
    'idealSer',localSer(idealErrors,validIdeal,c.payloadSymbolCount), ...
    'exactTheorySer',theorySer, ...
    'allPointsNonzero',allPointsNonzero, ...
    'allSenloraNotBetterThanIdeal',allOrdered, ...
    'receiverFailures',sum(state.failed,'all'), ...
    'allForbiddenFlagsFalse',~any(state.usesForbiddenInput,'all'), ...
    'maximumPacketErrors',max(senloraValues,[],'all','omitnan'), ...
    'parametersFrozen',plan.parametersFrozen,'formalStarted',false);
end

function bounds = localPairedBounds(difference,stream,draws)
difference = difference(isfinite(difference));
n = numel(difference);
if n==0
    bounds = [NaN NaN];
    return
end
samples = zeros(draws,1);
for draw = 1:draws
    index = randi(stream,n,n,1);
    samples(draw) = mean(difference(index));
end
bounds = prctile(samples,[2.5 97.5]);
end

function localPlot(summary,root)
displayFloor = 1e-6;
x = summary.orbitStartSec;
f = figure('Visible','off','Color','w','Position',[100 100 1080 680]);
hold on
localMeasuredLine(x,summary.senloraSer,displayFloor, ...
    'o','v',9,[0 0.4470 0.7410],'SenLoRa V8');
localMeasuredLine(x,summary.idealSer,displayFloor, ...
    '^','x',7,[0.8500 0.3250 0.0980],'Empirical Ideal');
semilogy(x,summary.exactTheorySer,'-k','LineWidth',1.6, ...
    'DisplayName','Exact AWGN theory');
set(gca,'YScale','log');grid on;grid minor
xlim([-380 10]);ylim([displayFloor 1]);
xticks(x);xticklabels(compose('%.1fs',x));xtickangle(25);
yticks(10.^(-6:0));xlabel('Frame start time (s)');ylabel('SER');
title({'SenLoRa V8 five-point fresh 1000-packet run', ...
    'Raw measured points; exact theory is time-invariant', ...
    'A zero-error point, if observed, is marked and fails acceptance'});
legend('Location','northeast');
exportgraphics(f,fullfile(root,'FIVE_POINT_1000_SER.png'),'Resolution',220);
close(f);
end

function localMeasuredLine( ...
        x,raw,floorValue,marker,floorMarker,floorSize,color,name)
connected = raw;
connected(raw<floorValue) = NaN;
semilogy(x,connected,['-' marker],'Color',color,'LineWidth',1.4, ...
    'MarkerSize',7,'DisplayName',name);
zero = raw==0;
if any(zero)
    semilogy(x(zero),repmat(floorValue,sum(zero),1),floorMarker, ...
        'Color',color,'MarkerSize',floorSize,'LineWidth',1.4, ...
        'HandleVisibility','off');
end
end
