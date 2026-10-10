function output = runSenloraSymmetricV8RicianPaperComparison(options)
%RUNSENLORASYMMETRICV8RICIANPAPERCOMPARISON Replay AWGN Paper entry at K10.
arguments
    options.WorkerCount (1,1) double {mustBeInteger,mustBePositive} = 4
    options.StopAfterPacket (1,1) double {mustBeInteger,mustBePositive} = 1000
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','scripts'));
paths = exp1SetupPaths();
addpath(here);
config = exp1Config();
c = config.parent;
plan = senloraSymmetricV8Config(config);
parameters = v4LoadMethodAlignedR3ParametersV1();
baselineRoot = fullfile(paths.resultsRoot,'senlora_symmetric_v8', ...
    'case_snr_rician_k10');
baselinePath = fullfile(baselineRoot,'RICIAN_CASE_SNR_RESULT.mat');
rawPath = fullfile(baselineRoot,'RICIAN_CASE_SNR_RAW_PACKETS.csv');
summaryPath = fullfile(baselineRoot,'RICIAN_CASE_SNR_SUMMARY.csv');
baseline = readtable(rawPath);
baselineSummary = readtable(summaryPath);
localValidateBaseline(baselinePath,baseline,baselineSummary,c);
root = fullfile(paths.resultsRoot,'senlora_symmetric_v8', ...
    'case_snr_rician_k10_paper_comparison');
if ~isfolder(root), mkdir(root); end
signature = localSignature(config,plan,parameters, ...
    [string(baselinePath);string(rawPath);string(summaryPath)]);
checkpointPath = fullfile(root,'RICIAN_PAPER_CHECKPOINT.mat');
n = height(baseline);
if isfile(checkpointPath)
    state = load(checkpointPath);
    if ~isequaln(state.signature,signature) || ...
            ~isequal(size(state.completed),[n,1]) || ...
            ~strcmp(state.stateDigest,localDigest(state))
        error('EXP5V8:PaperCheckpoint','Incompatible Paper checkpoint.');
    end
else
    state = struct('signature',signature,'completed',false(n,1), ...
        'paperErrors',nan(n,1),'paperIdealErrors',nan(n,1), ...
        'paperCfoRmseBins',nan(n,1),'paperStatic',false(n,1), ...
        'midambleCount',zeros(n,1),'midambleNoiseSeed',zeros(n,1), ...
        'failed',false(n,2),'failureMessage',strings(n,2), ...
        'usesForbiddenInput',false(n,1));
    state.stateDigest = localDigest(state);
end
pending = find(~state.completed & ...
    baseline.packetId<=min(options.StopAfterPacket,1000));
if ~isempty(pending)
    pool = gcp('nocreate');
    if isempty(pool)
        parpool('local',options.WorkerCount);
    elseif pool.NumWorkers~=options.WorkerCount
        error('EXP5V8:PaperWorkers','Existing worker count differs.');
    end
end
for batchStart = 1:100:numel(pending)
    jobs = pending(batchStart:min(batchStart+99,numel(pending)));
    rows = baseline(jobs,:);
    packets = cell(numel(jobs),1);
    parfor job = 1:numel(jobs)
        packets{job} = localEvaluate(rows(job,:),config,plan,parameters);
    end
    for job = 1:numel(jobs)
        index = jobs(job);
        p = packets{job};
        state.paperErrors(index) = p.paperErrors;
        state.paperIdealErrors(index) = p.paperIdealErrors;
        state.paperCfoRmseBins(index) = p.paperCfoRmseBins;
        state.paperStatic(index) = p.paperStatic;
        state.midambleCount(index) = p.midambleCount;
        state.midambleNoiseSeed(index) = p.midambleNoiseSeed;
        state.failed(index,:) = p.failed;
        state.failureMessage(index,:) = p.failureMessage;
        state.usesForbiddenInput(index) = p.usesForbiddenInput;
        state.completed(index) = true;
    end
    state.stateDigest = localDigest(state);
    temporary = checkpointPath+".tmp.mat";
    save(temporary,'-struct','state','-v7.3');
    probe = load(temporary);
    if ~strcmp(probe.stateDigest,localDigest(probe))
        error('EXP5V8:PaperCheckpointWrite','Checkpoint digest mismatch.');
    end
    [ok,message] = movefile(temporary,checkpointPath,'f');
    if ~ok, error('EXP5V8:PaperCheckpointWrite','%s',message); end
    fprintf(['Rician Paper: %d/20000 frames; Paper/Paper-Ideal ' ...
        'errors=%d/%d; failures=%d; forbidden=%d\n'], ...
        sum(state.completed),sum(state.paperErrors,'omitnan'), ...
        sum(state.paperIdealErrors,'omitnan'),sum(state.failed,'all'), ...
        sum(state.usesForbiddenInput));
end
output = struct('status','RICIAN_PAPER_IN_PROGRESS', ...
    'completedFrames',sum(state.completed),'totalFrames',n,'root',root);
if ~all(state.completed), return; end
[raw,summary] = localTables(state,baseline,baselineSummary,c);
writetable(raw,fullfile(root,'RICIAN_PAPER_RAW_PACKETS.csv'));
writetable(summary,fullfile(root,'RICIAN_PAPER_SUMMARY.csv'));
save(fullfile(root,'RICIAN_PAPER_RESULT.mat'),'-struct','state','-v7.3');
localPlot(summary,root);
output.status = 'RICIAN_PAPER_COMPLETE';
output.failedFrames = sum(state.failed,'all');
output.allForbiddenFlagsFalse = ~any(state.usesForbiddenInput);
output.summary = summary;
if output.failedFrames~=0 || ~output.allForbiddenFlagsFalse
    output.status = 'RICIAN_PAPER_COMPLETE_WITH_VALIDATION_FAILURE';
end
end

function packet = localEvaluate(row,config,plan,parameters)
c = config.parent;
key = struct('planVersion',plan.identity,'phase','case-ser-rician-k10', ...
    'track','two-case-native','channel','Rician-K10-packet-flat', ...
    'comparisonMode','frozen-v8-vs-ideal','snrDb',row.snrDb, ...
    'replicateId',row.packetId,'packetId',row.packetId, ...
    'eventType','single-native-frame','eventIndex',row.caseIndex, ...
    'sampleIndex',0);
seeds = v4EventRandomLedger(row.rootSeed,key);
if ~isequal([seeds.payloadSeed,seeds.noiseSeed,seeds.channelSeed], ...
        [row.payloadSeed,row.noiseSeed,row.channelSeed])
    error('EXP5V8:PaperSeed','Replay seeds differ from native baseline.');
end
midambleKey = key;
midambleKey.component = 'paper-explicit-midamble-noise';
seeds.midambleNoiseSeed = v4KeyedSeed(row.rootSeed,midambleKey);
packet = struct('paperErrors',c.payloadSymbolCount, ...
    'paperIdealErrors',c.payloadSymbolCount,'paperCfoRmseBins',NaN, ...
    'paperStatic',false,'midambleCount',0, ...
    'midambleNoiseSeed',seeds.midambleNoiseSeed, ...
    'failed',false(1,2),'failureMessage',strings(1,2), ...
    'usesForbiddenInput',false);
frame = senloraSymmetricV8GeneratePaperRicianFrame( ...
    config,row.orbitStartSec,row.snrDb,seeds);
if abs(frame.truth.channelPower-row.channelPower)>1e-12
    error('EXP5V8:PaperChannel','Replayed fading coefficient differs.');
end
common = v4CommonBootstrap(frame.observation.rxPhysical( ...
    frame.observation.layout.bootstrapRows,:),c, ...
    SearchStepBins=parameters.searchStepBins);
% Non-Ideal receives only observations/configuration. Truth is used below
% only after its decode has returned, for offline error/residual scoring.
try
    receiver = v4PaperMidamblePointUnifiedV6(frame.observation,common,c);
    detected = receiver.detectedPhysicalBins(:);
    if numel(detected)~=c.payloadSymbolCount || any(~isfinite(detected))
        error('EXP5V8:PaperOutput','Invalid detected-symbol output.');
    end
    packet.paperErrors = sum(detected~=frame.truth.payloadPhysicalBins(:));
    residual = receiver.estimatedCfoBins(:)-frame.truth.dataCfoBins(:);
    packet.paperCfoRmseBins = sqrt(mean(residual.^2));
    packet.paperStatic = receiver.modeEvidence.staticSelected;
    packet.midambleCount = sum(receiver.explicitMidambleAccepted);
    names = {'usesPayloadTruth','usesOrbitTruth','usesCaseIdentity', ...
        'usesSnrInput','usesTargetSer'};
    for index = 1:numel(names)
        if isfield(receiver,names{index}) && receiver.(names{index})
            packet.usesForbiddenInput = true;
        end
    end
    packet.usesForbiddenInput = packet.usesForbiddenInput || ...
        receiver.modeEvidence.usesTruth;
catch exception
    packet.paperErrors = c.payloadSymbolCount;
    packet.failed(1) = true;
    packet.failureMessage(1) = string(exception.identifier)+": "+exception.message;
end
try
    ideal = exp1IdealDecode(frame,config);
    packet.paperIdealErrors = sum( ...
        ideal.detectedPhysicalBins(:)~=frame.truth.payloadPhysicalBins(:));
catch exception
    packet.paperIdealErrors = c.payloadSymbolCount;
    packet.failed(2) = true;
    packet.failureMessage(2) = string(exception.identifier)+": "+exception.message;
end
end

function localValidateBaseline(path,raw,summary,c)
senloraSymmetricV8ValidateRicianReferenceSummary(summary,c);
state = load(path);
if ~all(state.completed,'all') || any(state.failed,'all') || ...
        any(state.usesForbiddenInput,'all') || ...
        ~strcmp(state.stateDigest,localBaseDigest(state)) || ...
        height(raw)~=20000 || height(summary)~=20
    error('EXP5V8:PaperBaseline','Native baseline is not complete/valid.');
end
sig = state.signature;
if sig.seedRoot~=1032900000 || sig.packetsPerCell~=1000 || ...
        ~isequal(sig.caseStartSec,[-366;0]) || ...
        ~isequal(sig.snrDb,(-30:-21).') || sig.ricianKDb~=10 || ...
        ~strcmp(sig.ricianCoherence,'packet-flat')
    error('EXP5V8:PaperBaseline','Native experiment conditions differ.');
end
for index = 1:numel(sig.executionSourcePaths)
    localCheckHash(sig.executionSourcePaths(index), ...
        sig.executionSourceSha256(index));
end
for index = 1:numel(sig.parameterSourcePaths)
    localCheckHash(sig.parameterSourcePaths(index), ...
        sig.parameterSourceSha256(index));
end
localCheckHash(sig.frozenManifestPath,sig.frozenManifestSha256);
localCheckHash(sig.paperPath,sig.paperSha256);
keys = raw{:,{'caseIndex','snrDb','packetId'}};
if any(~isfinite(keys),'all') || size(unique(keys,'rows'),1)~=20000 || ...
        any(~ismember(raw.caseIndex,[1;2])) || ...
        any(~ismember(raw.snrDb,(-30:-21).')) || ...
        any(~ismember(raw.packetId,(1:1000).')) || ...
        any(raw.rootSeed~=sig.seedRoot) || any(raw.payloadSymbols~=c.payloadSymbolCount)
    error('EXP5V8:PaperBaseline','Native raw keys/counts are invalid.');
end
linear = sub2ind(size(state.completed),raw.caseIndex,raw.snrDb+31,raw.packetId);
pairs = {'senloraRawErrors','senloraErrors';'idealRawErrors','idealErrors'; ...
    'payloadSeed','payloadSeed';'noiseSeed','noiseSeed'; ...
    'channelSeed','channelSeed';'channelPower','channelPower'};
for index = 1:size(pairs,1)
    values = state.(pairs{index,2});
    if any(~isfinite(raw.(pairs{index,1}))) || ...
            any(abs(raw.(pairs{index,1})-values(linear))>1e-12)
        error('EXP5V8:PaperBaseline','CSV/MAT mismatch: %s.',pairs{index,1});
    end
end
if any(raw.orbitStartSec~=sig.caseStartSec(raw.caseIndex)) || ...
        any(raw.senloraFailed | raw.idealFailed | raw.usesForbiddenInput)
    error('EXP5V8:PaperBaseline','Native raw flags/times differ.');
end
for ci = 1:2
    for snr = -30:-21
        r = raw(raw.caseIndex==ci & raw.snrDb==snr,:);
        s = summary(summary.caseIndex==ci & summary.snrDb==snr,:);
        if height(r)~=1000 || height(s)~=1 || s.packets~=1000 || ...
                s.validSenloraPackets~=1000 || s.validIdealPackets~=1000 || ...
                s.senloraRawErrors~=sum(r.senloraRawErrors) || ...
                s.idealRawErrors~=sum(r.idealRawErrors) || ...
                abs(s.senloraSer-s.senloraRawErrors/112000)>1e-12 || ...
                abs(s.idealSer-s.idealRawErrors/112000)>1e-12
            error('EXP5V8:PaperBaseline','Native summary mismatch.');
        end
    end
end
end

function localCheckHash(path,expected)
if ~isfile(path) || ~strcmpi(exp1Sha256(path),expected)
    error('EXP5V8:PaperSource','Dependency changed: %s.',path);
end
end

function signature = localSignature(config,plan,parameters,baselinePaths)
names = {'runSenloraSymmetricV8RicianPaperComparison', ...
    'senloraSymmetricV8GeneratePaperRicianFrame', ...
    'v4PaperMidamblePointUnifiedV6','v4PaperMidamblePointUnifiedV4', ...
    'v4PaperMidamblePointTrendDecodeV3','v4CommonBootstrap','exp1IdealDecode'};
explicit = strings(numel(names),1);
for index = 1:numel(names)
    explicit(index) = string(which(names{index}));
    if strlength(explicit(index))==0
        error('EXP5V8:PaperSource','Unresolved entry %s.',names{index});
    end
end
required = string(matlab.codetools.requiredFilesAndProducts(explicit(1)));
allPaths = unique([required(:);explicit]);
inScope = startsWith(allPaths,string(config.projectRoot)+filesep,'IgnoreCase',true) | ...
    startsWith(allPaths,string(config.parentRoot)+filesep,'IgnoreCase',true);
sourcePaths = sort(allPaths(inScope));
hashes = strings(size(sourcePaths));
for index = 1:numel(sourcePaths), hashes(index) = exp1Sha256(sourcePaths(index)); end
inputPaths = [baselinePaths;string(parameters.sourcePath)];
inputHashes = strings(size(inputPaths));
for index = 1:numel(inputPaths), inputHashes(index) = exp1Sha256(inputPaths(index)); end
signature = struct('identity','V8-RICIAN-K10-PAPER-REPLAY-V1', ...
    'paperEntry','v4PaperMidamblePointUnifiedV6', ...
    'paperVersion','AWGN-adapted-v6-unchanged','v8Identity',plan.identity, ...
    'caseStartSec',[-366;0],'snrDb',(-30:-21).','packetsPerCell',1000, ...
    'seedRoot',1032900000,'ricianKDb',10,'ricianCoherence','packet-flat', ...
    'nativePhysicalSymbols',config.parent.noMidambleFrameSymbolCount, ...
    'paperPhysicalSymbols',config.parent.commonTimelineSymbolCount, ...
    'payloadSymbols',config.parent.payloadSymbolCount, ...
    'commonSearchStepBins',parameters.searchStepBins, ...
    'pairing','payload-channel-logical-preamble-data-noise; different frame durations', ...
    'sourcePaths',sourcePaths,'sourceSha256',hashes, ...
    'inputPaths',inputPaths,'inputSha256',inputHashes);
end

function hash = localDigest(state)
copy = state;
if isfield(copy,'stateDigest'), copy = rmfield(copy,'stateDigest'); end
hash = localBytesHash(getByteStreamFromArray(orderfields(copy)));
end

function hash = localBaseDigest(s)
hash = localBytesHash(getByteStreamFromArray({s.signature,s.senloraErrors, ...
    s.idealErrors,s.firstErrors,s.acceptedBlocks,s.rateGain,s.channelPower, ...
    s.failed,s.failureMessage,s.usesForbiddenInput,s.payloadSeed,s.noiseSeed, ...
    s.channelSeed,s.completed}));
end

function hash = localBytesHash(bytes)
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(typecast(uint8(bytes(:)),'int8'));
hash = lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end

function [raw,summary] = localTables(state,baseline,summary,c)
raw = baseline;
raw.paperRawErrors = state.paperErrors;
raw.paperFrameIdealRawErrors = state.paperIdealErrors;
raw.paperCfoRmseBins = state.paperCfoRmseBins;
raw.paperStaticSelected = state.paperStatic;
raw.explicitMidambles = state.midambleCount;
raw.midambleNoiseSeed = state.midambleNoiseSeed;
raw.paperFailed = state.failed(:,1);
raw.paperFrameIdealFailed = state.failed(:,2);
raw.paperUsesForbiddenInput = state.usesForbiddenInput;
raw.paperFailureMessage = state.failureMessage(:,1);
raw.paperFrameIdealFailureMessage = state.failureMessage(:,2);
n = height(summary);
fields = {'paperRawErrors','paperFrameIdealRawErrors','paperSer', ...
    'paperFrameIdealSer','paperLower95','paperUpper95', ...
    'paperMinusOwnIdealSer','pairedDifferenceLower95','pairedDifferenceUpper95', ...
    'paperFailedPackets','paperFrameIdealFailedPackets','paperStaticPackets', ...
    'paperForbiddenPackets','nativeFrameDurationSec','paperFrameDurationSec'};
for index = 1:numel(fields), summary.(fields{index}) = zeros(n,1); end
for index = 1:n
    mask = raw.caseIndex==summary.caseIndex(index) & raw.snrDb==summary.snrDb(index);
    paper = state.paperErrors(mask);
    ideal = state.paperIdealErrors(mask);
    summary.paperRawErrors(index) = sum(paper);
    summary.paperFrameIdealRawErrors(index) = sum(ideal);
    summary.paperSer(index) = sum(paper)/(1000*c.payloadSymbolCount);
    summary.paperFrameIdealSer(index) = sum(ideal)/(1000*c.payloadSymbolCount);
    bounds = localClusterBounds(paper,c.payloadSymbolCount,1032900000+index);
    summary.paperLower95(index) = bounds(1);
    summary.paperUpper95(index) = bounds(2);
    difference = paper-ideal;
    bounds = localClusterBounds(difference,c.payloadSymbolCount,1032901000+index);
    summary.paperMinusOwnIdealSer(index) = mean(difference)/c.payloadSymbolCount;
    summary.pairedDifferenceLower95(index) = bounds(1);
    summary.pairedDifferenceUpper95(index) = bounds(2);
    summary.paperFailedPackets(index) = sum(state.failed(mask,1));
    summary.paperFrameIdealFailedPackets(index) = sum(state.failed(mask,2));
    summary.paperStaticPackets(index) = sum(state.paperStatic(mask));
    summary.paperForbiddenPackets(index) = sum(state.usesForbiddenInput(mask));
    summary.nativeFrameDurationSec(index) = c.noMidambleFrameSymbolCount*c.symbolDurationSec;
    summary.paperFrameDurationSec(index) = c.commonTimelineSymbolCount*c.symbolDurationSec;
end
end

function bounds = localClusterBounds(errors,symbols,seed)
stream = RandStream('mt19937ar','Seed',seed);
n = numel(errors);
sample = zeros(5000,1);
for index = 1:numel(sample)
    sample(index) = mean(errors(randi(stream,n,n,1)))/symbols;
end
bounds = prctile(sample,[2.5 97.5]);
end

function localPlot(summary,root)
fig = figure('Visible','off','Color','w','Position',[100 100 1260 570]);
tiles = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
for ci = 1:2, localAxes(nexttile,summary(summary.caseIndex==ci,:),ci); end
title(tiles,'Rician K=10 dB: frozen V8 and reused Paper adapted V6 (1000 packets/point)');
exportgraphics(fig,fullfile(root,'RICIAN_PAPER_CASE1_CASE2_SER.png'),'Resolution',220);
close(fig);
for ci = 1:2
    fig = figure('Visible','off','Color','w','Position',[100 100 850 600]);
    localAxes(axes('Parent',fig),summary(summary.caseIndex==ci,:),ci);
    exportgraphics(fig,fullfile(root,sprintf('RICIAN_PAPER_CASE%d_SER.png',ci)), ...
        'Resolution',220);
    close(fig);
end
end

function localAxes(ax,data,ci)
data = sortrows(data,'snrDb');
hold(ax,'on');
plot(ax,data.snrDb,data.exactNoDopplerRicianSer,'-k','LineWidth',1.7, ...
    'DisplayName','Rician theory (no Doppler)');
plot(ax,data.snrDb,data.senloraSer,'-o','Color',[0 0.4470 0.7410], ...
    'LineWidth',1.4,'DisplayName','SenLoRa V8 (120 symbols)');
plot(ax,data.snrDb,data.idealSer,'-^','Color',[0.8500 0.3250 0.0980], ...
    'LineWidth',1.4,'DisplayName','Ideal (V8 frame)');
plot(ax,data.snrDb,data.paperSer,'-s','Color',[0.4660 0.6740 0.1880], ...
    'LineWidth',1.4,'DisplayName','Paper Midamble-Point adapted V6 (157 symbols)');
plot(ax,data.snrDb,data.paperFrameIdealSer,'--d','Color',[0.4940 0.1840 0.5560], ...
    'LineWidth',1.2,'DisplayName','Ideal (Paper frame)');
set(ax,'YScale','log'); xlim(ax,[-30 -21]); ylim(ax,[1e-3 1]); xticks(ax,-30:-21);
grid(ax,'on'); grid(ax,'minor'); xlabel(ax,'SNR (dB)'); ylabel(ax,'Raw SER');
title(ax,sprintf('Case %d: t_0 = %.0f s',ci,data.orbitStartSec(1)));
legend(ax,'Location','southwest','FontSize',8.5);
end
