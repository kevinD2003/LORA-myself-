function output = runSenloraSymmetricV6Validation(options)
%RUNSENLORASYMMETRICV6VALIDATION Paired V3/V6 orbit validation.

arguments
    options.Phase (1,1) string {mustBeMember(options.Phase, ...
        ["mechanism","review","formal"])} = "mechanism"
    options.PacketCount (1,1) double {mustBeInteger,mustBePositive} = 20
    options.PairIndices (1,:) double {mustBeInteger,mustBePositive} = 1:9
    options.WorkerCount (1,1) double {mustBeInteger,mustBePositive} = 2
    options.Tag (1,1) string = ""
    options.StopAfterPacket (1,1) double ...
        {mustBeInteger,mustBePositive} = 1000
end

addpath(fullfile(fileparts(mfilename('fullpath')),'..','senlora_symmetric_v2'));
addpath(fullfile(fileparts(mfilename('fullpath')),'..','senlora_symmetric_v3'));
paths = exp1SetupPaths();
addpath(fullfile(paths.projectRoot,'review_first_v1'));
config = exp1Config();
plan = senloraSymmetricV6Config(config);
parameters = v4LoadMethodAlignedR3ParametersV1();
parentAudit = exp1ValidateFrozenParent(config);
[sourcePaths,sourceHashes] = localImplementationSources(paths,config);
if isempty(regexp(char(options.Tag),'^[A-Za-z0-9_-]*$','once'))
    error('EXP5V6:Tag','Validation tag must be a simple name.');
end
pairs = unique(options.PairIndices(:).','stable');
if any(pairs>numel(plan.negativeOrbitStartSec))
    error('EXP5V6:PairIndex','Pair index exceeds the orbit grid.');
end
n = options.PacketCount;
maximumPacket = min(n,options.StopAfterPacket);
root = fullfile(paths.resultsRoot,'senlora_symmetric_v6',char(options.Phase));
if strlength(options.Tag)>0
    root = fullfile(root,char(options.Tag));
end
if ~isfolder(root),mkdir(root);end
checkpointPath = fullfile(root,'VALIDATION_CHECKPOINT.mat');
signature = struct('receiverVersion',plan.receiverVersion, ...
    'planIdentity',plan.identity,'phase',char(options.Phase), ...
    'packetCount',n,'pairIndices',pairs,'tag',char(options.Tag), ...
    'seedRoot',localSeedRoot(plan,options.Phase), ...
    'projectDigest',exp1ImplementationDigest(config), ...
    'parentManifestSha256',parentAudit.manifestSha256, ...
    'executionSourcePaths',sourcePaths, ...
    'executionSourceSha256',sourceHashes, ...
    'validationSha256',exp1Sha256(which( ...
        'runSenloraSymmetricV6Validation')), ...
    'v6DecodeSha256',exp1Sha256(which('senloraSymmetricV6Decode')), ...
    'v6ConfigSha256',exp1Sha256(which('senloraSymmetricV6Config')), ...
    'v3DecodeSha256',exp1Sha256(which('senloraSymmetricV3Decode')));

shape = [numel(pairs),2,n];
if isfile(checkpointPath)
    loaded = load(checkpointPath);
    if ~isfield(loaded,'signature') || ...
            ~strcmp(jsonencode(loaded.signature),jsonencode(signature)) || ...
            ~isequal(size(loaded.v6Errors),shape) || ...
            ~isequal(size(loaded.v3Errors),shape) || ...
            ~isequal(size(loaded.parentErrors),shape) || ...
            ~isequal(size(loaded.failed),shape) || ...
            ~isequal(size(loaded.loboVerified),shape) || ...
            ~isequal(size(loaded.override),shape) || ...
            ~isequal(size(loaded.completed),[numel(pairs),n]) || ...
            ~isequal(size(loaded.case1Exact),[numel(pairs),n]) || ...
            ~strcmp(loaded.stateDigest,localDigest(loaded))
        error('EXP5V6:Checkpoint','Validation checkpoint is invalid.');
    end
    v6Errors = loaded.v6Errors;
    v3Errors = loaded.v3Errors;
    parentErrors = loaded.parentErrors;
    failed = loaded.failed;
    loboVerified = loaded.loboVerified;
    override = loaded.override;
    case1Exact = loaded.case1Exact;
    completed = loaded.completed;
else
    v6Errors = zeros(shape,'uint16');
    v3Errors = zeros(shape,'uint16');
    parentErrors = zeros(shape,'uint16');
    failed = false(shape);
    loboVerified = false(shape);
    override = false(shape);
    case1Exact = false(numel(pairs),n);
    completed = false(numel(pairs),n);
end

if any(~completed(:,1:maximumPacket),'all')
    pool = gcp('nocreate');
    if isempty(pool)
        parpool('local',options.WorkerCount);
    elseif pool.NumWorkers~=options.WorkerCount
        error('EXP5V6:WorkerCount','Existing pool has wrong worker count.');
    end
end

for blockStart = 1:5:maximumPacket
    packetIds = blockStart:min(maximumPacket,blockStart+4);
    [rows,columns] = find(~completed(:,packetIds));
    if isempty(rows),continue;end
    jobPairs = pairs(rows);
    jobPackets = packetIds(columns).';
    jobs = numel(rows);
    jobV6 = zeros(jobs,2,'uint16');
    jobV3 = zeros(jobs,2,'uint16');
    jobParent = zeros(jobs,2,'uint16');
    jobFailed = false(jobs,2);
    jobLobo = false(jobs,2);
    jobOverride = false(jobs,2);
    jobExact = false(jobs,1);
    phase = options.Phase;
    parfor job = 1:jobs
        packet = localEvaluate(jobPairs(job),jobPackets(job), ...
            phase,config,plan,parameters);
        jobV6(job,:) = packet.v6Errors;
        jobV3(job,:) = packet.v3Errors;
        jobParent(job,:) = packet.parentErrors;
        jobFailed(job,:) = packet.failed;
        jobLobo(job,:) = packet.loboVerified;
        jobOverride(job,:) = packet.override;
        jobExact(job) = packet.case1Exact;
    end
    for job = 1:jobs
        row = rows(job);
        packetId = jobPackets(job);
        v6Errors(row,:,packetId) = jobV6(job,:);
        v3Errors(row,:,packetId) = jobV3(job,:);
        parentErrors(row,:,packetId) = jobParent(job,:);
        failed(row,:,packetId) = jobFailed(job,:);
        loboVerified(row,:,packetId) = jobLobo(job,:);
        override(row,:,packetId) = jobOverride(job,:);
        case1Exact(row,packetId) = jobExact(job);
        completed(row,packetId) = true;
    end
    state = struct('signature',signature,'v6Errors',v6Errors, ...
        'v3Errors',v3Errors,'parentErrors',parentErrors, ...
        'failed',failed,'loboVerified',loboVerified, ...
        'override',override, ...
        'case1Exact',case1Exact,'completed',completed);
    state.stateDigest = localDigest(state);
    temporaryPath = [checkpointPath '.tmp.mat'];
    save(temporaryPath,'-struct','state','-v7.3');
    probe = load(temporaryPath);
    if ~strcmp(probe.stateDigest,localDigest(probe))
        error('EXP5V6:CheckpointWrite','Checkpoint verification failed.');
    end
    [moved,message] = movefile(temporaryPath,checkpointPath,'f');
    if ~moved,error('EXP5V6:CheckpointMove','%s',message);end
    fprintf('V6 %s pair-packets=%d/%d errors V6/V3=%d/%d failed=%d\n', ...
        options.Phase,sum(completed,'all'),numel(completed), ...
        sum(v6Errors,'all'),sum(v3Errors,'all'),sum(failed,'all'));
end

if ~all(completed,'all')
    output = struct('status','V6_VALIDATION_IN_PROGRESS', ...
        'completedPairPackets',sum(completed,'all'), ...
        'totalPairPackets',numel(completed), ...
        'failedPackets',sum(failed,'all'), ...
        'checkpointPath',checkpointPath);
    return
end

summary = table(pairs(:),reshape( ...
    plan.negativeOrbitStartSec(pairs),[],1), ...
    'VariableNames',{'pairIndex','negativeOrbitStartSec'});
summary.negativeV6Errors = reshape(sum(double(v6Errors(:,1,:)),3),[],1);
summary.positiveV6Errors = reshape(sum(double(v6Errors(:,2,:)),3),[],1);
summary.negativeV3Errors = reshape(sum(double(v3Errors(:,1,:)),3),[],1);
summary.positiveV3Errors = reshape(sum(double(v3Errors(:,2,:)),3),[],1);
summary.negativeParentErrors = reshape(sum(double(parentErrors(:,1,:)),3),[],1);
summary.positiveParentErrors = reshape(sum(double(parentErrors(:,2,:)),3),[],1);
summary.negativeOverrides = reshape(sum(override(:,1,:),3),[],1);
summary.positiveOverrides = reshape(sum(override(:,2,:),3),[],1);
summary.failedPackets = reshape(sum(failed,[2 3]),[],1);
summary.loboVerifiedPackets = reshape(sum(loboVerified,[2 3]),[],1);
summary.packetsPerSide = repmat(n,numel(pairs),1);
case1Row = find(pairs==1,1);
if isempty(case1Row)
    exact = NaN;
else
    exact = sum(case1Exact(case1Row,:));
end
metrics = struct('phase',char(options.Phase), ...
    'v6RawErrors',sum(v6Errors,'all'), ...
    'v3RawErrors',sum(v3Errors,'all'), ...
    'case1ExactPackets',exact,'case1TotalPackets',n, ...
    'failedPackets',sum(failed,'all'), ...
    'allLoboVerified',all(loboVerified,'all'), ...
    'overridePackets',sum(override,'all'), ...
    'complete',all(completed,'all'));
writetable(summary,fullfile(root,'VALIDATION_SUMMARY.csv'));
save(fullfile(root,'VALIDATION_RESULT.mat'),'summary','metrics', ...
    'signature','v6Errors','v3Errors','parentErrors', ...
    'failed','loboVerified','override','case1Exact','completed','-v7.3');
output = struct('summary',summary,'metrics',metrics,'root',root);
end

function seedRoot = localSeedRoot(plan,phase)
switch phase
    case "mechanism"
        seedRoot = plan.mechanismRootSeed;
    case "review"
        seedRoot = plan.reviewRootSeed;
    case "formal"
        seedRoot = plan.formalRootSeed;
    otherwise
        error('EXP5V6:SeedPhase','Unknown validation phase.');
end
end

function packet = localEvaluate(pairIndex,packetId,phase,config,plan,parameters)
negative = plan.negativeOrbitStartSec(pairIndex);
starts = [negative,-negative-plan.frameDurationSec];
seedCell = pairIndex;
if phase=="formal",seedCell = 100+pairIndex;end
ledger = senloraSymmetricV3SeedPlan(config,plan,char(phase), ...
    seedCell,plan.snrDb,packetId);
errors = zeros(1,2,'uint16');
v3Errors = zeros(1,2,'uint16');
parentErrors = zeros(1,2,'uint16');
failed = false(1,2);
loboVerified = false(1,2);
override = false(1,2);
case1Exact = true;
for side = 1:2
    try
        frame = exp1GenerateFrame(config,starts(side),plan.snrDb,ledger);
        common = v4CommonBootstrap( ...
            frame.observation.rxPhysical(1:8,:),config.parent, ...
            SearchStepBins=parameters.searchStepBins);
        result = senloraSymmetricV6Decode( ...
            frame.observation,common,config,plan);
        truth = frame.truth.payloadPhysicalBins(:);
        errors(side) = uint16(sum(result.detectedPhysicalBins(:)~=truth));
        v3Errors(side) = uint16(sum( ...
            result.v3CandidateDetectedPhysicalBins(:)~=truth));
        parent = result.frozenParentHypothesis;
        parentErrors(side) = uint16(sum( ...
            parent.detectedPhysicalBins(:)~=truth));
        override(side) = result.decision.v6StaticOverride;
        loboVerified(side) = result.decision.leaveOneBlockOut && ...
            ~result.decision.selfBlockUsedForFit;
        if pairIndex==1 && side==1
            case1Exact = isequal(result.detectedPhysicalBins(:), ...
                parent.detectedPhysicalBins(:)) && isequal( ...
                result.hardDecodedDataBits(:),parent.hardDecodedDataBits(:));
        end
    catch exception
        failed(side) = true;
        errors(side) = uint16(config.parent.payloadSymbolCount);
        v3Errors(side) = errors(side);
        parentErrors(side) = errors(side);
        if pairIndex==1 && side==1,case1Exact = false;end
        warning('EXP5V6:PacketFailure', ...
            'Pair %d packet %d side %d: %s', ...
            pairIndex,packetId,side,exception.message);
    end
end
packet = struct('v6Errors',errors,'v3Errors',v3Errors, ...
    'parentErrors',parentErrors,'failed',failed, ...
    'loboVerified',loboVerified,'override',override, ...
    'case1Exact',case1Exact);
end

function hash = localDigest(state)
digest = java.security.MessageDigest.getInstance('SHA-256');
bytes = getByteStreamFromArray({state.signature,state.v6Errors, ...
    state.v3Errors,state.parentErrors,state.failed, ...
    state.loboVerified,state.override, ...
    state.case1Exact,state.completed});
digest.update(typecast(uint8(bytes(:)),'int8'));
hash = lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end

function [sourcePaths,sourceHashes] = localImplementationSources(paths,config)
entry = which('runSenloraSymmetricV6Validation');
required = string(matlab.codetools.requiredFilesAndProducts(entry));
explicitNames = {'runSenloraSymmetricV6Validation', ...
    'senloraSymmetricV6Config','senloraSymmetricV6Decode', ...
    'senloraSymmetricV3Config','senloraSymmetricV3Decode', ...
    'senloraSymmetricV3SeedPlan','senloraSymmetricV2Config', ...
    'senloraSymmetricV2Decode','exp1Config','exp1GenerateFrame', ...
    'exp1Stage55Decode','v4CommonBootstrap', ...
    'v4LoadMethodAlignedR3ParametersV1','reviewStaticHypothesis', ...
    'exp1ImplementationDigest','exp1Sha256','v4EventRandomLedger'};
explicitPaths = strings(numel(explicitNames),1);
for index = 1:numel(explicitNames)
    explicitPaths(index) = string(which(explicitNames{index}));
    if strlength(explicitPaths(index))==0
        error('EXP5V6:DependencyMissing', ...
            'Cannot resolve validation dependency %s.',explicitNames{index});
    end
end
allPaths = unique([required(:);explicitPaths]);
inScope = startsWith(allPaths,string(paths.projectRoot)+filesep, ...
    'IgnoreCase',true) | ...
    startsWith(allPaths,string(config.parentRoot)+filesep, ...
    'IgnoreCase',true);
sourcePaths = sort(allPaths(inScope));
if isempty(sourcePaths)
    error('EXP5V6:DependencySet', ...
        'Validation dependency set is empty.');
end
sourceHashes = strings(size(sourcePaths));
for index = 1:numel(sourcePaths)
    sourceHashes(index) = exp1Sha256(sourcePaths(index));
end
end
