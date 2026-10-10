function output = runSenloraPaperPointFourCurves(options)
%RUNSENLORAPAPERPOINTFOURCURVES Eq17 Case-SNR and Figure12 user-PHY comparison.
arguments
    options.Stage (1,1) string {mustBeMember(options.Stage,["CaseSnr","Figure12"])} = "Figure12"
    options.WorkerCount (1,1) double {mustBeInteger,mustBePositive} = 4
    options.StopAfterPacket (1,1) double {mustBeInteger,mustBePositive} = 1000
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','scripts')); paths = exp1SetupPaths(); addpath(here);
config = exp1Config(); c = config.parent; plan = senloraSymmetricV8Config(config);
parameters = v4LoadMethodAlignedR3ParametersV1();
localFrozen(config,plan,here);
[raw,initial,inputPaths] = localPlan(options.Stage,config,plan);
signature = localSignature(options.Stage,config,raw,inputPaths,here,parameters);
if options.Stage=="CaseSnr", folder = 'paper_point_eq17_nint1_case_snr_rician';
else, folder = 'figure12_four_methods_nint1'; end
root = fullfile(paths.resultsRoot,'senlora_symmetric_v8',folder);
if ~isfolder(root), mkdir(root); end
checkpoint = fullfile(root,'FOUR_CURVE_CHECKPOINT.mat');
if isfile(checkpoint)
    state = load(checkpoint);
    if ~isequaln(state.signature,signature) || ...
            ~isequal(size(state.completed),[height(raw),1]) || ...
            ~strcmp(state.stateDigest,localDigest(state))
        error('EXP5Paper:Checkpoint','Incompatible four-curve checkpoint.');
    end
else
    state = struct('signature',signature,'completed',false(height(raw),1), ...
        'errors',initial,'failed',false(height(raw),5), ...
        'failureMessage',strings(height(raw),5),'forbidden',false(height(raw),3), ...
        'gain',nan(height(raw),1),'vpBlocks',nan(height(raw),1), ...
        'channelPower',nan(height(raw),1));
    state.stateDigest = localDigest(state);
end
pending = find(~state.completed & raw.packetId<=min(1000,options.StopAfterPacket));
if ~isempty(pending)
    pool = gcp('nocreate');
    if isempty(pool), parpool('local',options.WorkerCount);
    elseif pool.NumWorkers~=options.WorkerCount
        error('EXP5Paper:Workers','Existing worker count differs.');
    end
end
for first = 1:50:numel(pending)
    jobs = pending(first:min(first+49,numel(pending)));
    rows = raw(jobs,:); results = cell(numel(jobs),1);
    parfor job = 1:numel(jobs)
        results{job} = localEvaluate(rows(job,:),options.Stage,config);
    end
    for job = 1:numel(jobs)
        index = jobs(job); p = results{job};
        % Native PREC/VP/Ideal are frozen paired baselines in both stages.
        state.errors(index,[3,5]) = p.errors([3,5]);
        state.failed(index,:) = p.failed;
        state.failureMessage(index,:) = p.message;
        state.forbidden(index,:) = p.forbidden;
        state.gain(index) = p.gain; state.vpBlocks(index) = p.vpBlocks;
        state.channelPower(index) = p.channelPower;
        state.completed(index) = true;
    end
    state.stateDigest = localDigest(state);
    temporary = checkpoint+".tmp.mat";
    save(temporary,'-struct','state','-v7.3');
    probe = load(temporary);
    if ~strcmp(probe.stateDigest,localDigest(probe)), error('EXP5Paper:Checkpoint','Digest mismatch.'); end
    [ok,message] = movefile(temporary,checkpoint,'f');
    if ~ok, error('EXP5Paper:Checkpoint','%s',message); end
    fprintf('%s Eq17: %d/%d paired rows; errors PREC/VP/Paper=%d/%d/%d; failures=%d\n', ...
        options.Stage,sum(state.completed),height(raw), ...
        sum(state.errors(state.completed,1),'omitnan'), ...
        sum(state.errors(state.completed,2),'omitnan'), ...
        sum(state.errors(state.completed,3),'omitnan'),sum(state.failed,'all'));
end
output = struct('status','FOUR_CURVES_IN_PROGRESS','completedPackets', ...
    sum(state.completed),'totalPackets',height(raw),'root',root);
if ~all(state.completed), return; end
raw.precRawErrors = state.errors(:,1); raw.vpRawErrors = state.errors(:,2);
raw.paperRawErrors = state.errors(:,3); raw.nativeIdealRawErrors = state.errors(:,4);
raw.paperIdealRawErrors = state.errors(:,5); raw.channelPower = state.channelPower;
raw.rateGain = state.gain; raw.acceptedVpBlocks = state.vpBlocks;
names = {'precFailed','vpFailed','paperFailed','nativeIdealFailed','paperIdealFailed'};
for k = 1:5, raw.(names{k}) = state.failed(:,k); end
raw.forbiddenInput = any(state.forbidden,2);
summary = localSummary(raw,state,options.Stage,c);
writetable(raw,fullfile(root,'FOUR_CURVE_RAW_PACKETS.csv'));
writetable(summary,fullfile(root,'FOUR_CURVE_SUMMARY.csv'));
save(fullfile(root,'FOUR_CURVE_RESULT.mat'),'-struct','state','-v7.3');
localPlot(summary,options.Stage,root);
output.status = 'FOUR_CURVES_COMPLETE'; output.summary = summary;
output.failedDecodes = sum(state.failed,'all');
output.allForbiddenFlagsFalse = ~any(state.forbidden,'all');
if output.failedDecodes || ~output.allForbiddenFlagsFalse
    output.status = 'FOUR_CURVES_COMPLETE_WITH_VALIDATION_FAILURE';
end
end

function [raw,initial,inputPaths] = localPlan(stage,config,plan)
if stage=="CaseSnr"
    root = fullfile(config.projectRoot,'results','senlora_symmetric_v8', ...
        'case_snr_rician_k10_prec_comparison');
    matPath = fullfile(root,'RICIAN_PREC_RESULT.mat');
    csvPath = fullfile(root,'RICIAN_PREC_RAW_PACKETS.csv');
    old = load(matPath);
    if ~all(old.completed) || any(old.failed) || any(old.usesForbiddenInput) || ...
            ~strcmp(old.stateDigest,localDigest(old))
        error('EXP5Paper:Baseline','PREC/native baseline incomplete or invalid.');
    end
    localHashes(old.signature.sourcePaths,old.signature.sourceSha256);
    localHashes(old.signature.inputPaths,old.signature.inputSha256);
    data = readtable(csvPath);
    keys = data{:,{'caseIndex','snrDb','packetId'}};
    if height(data)~=20000 || size(unique(keys,'rows'),1)~=20000 || ...
            any(~ismember(data.caseIndex,[1;2])) || any(~ismember(data.snrDb,(-30:-21).')) || ...
            any(~ismember(data.packetId,(1:1000).')) || any(data.rootSeed~=1032900000) || ...
            any(data.precRawErrors~=old.precErrors) || ...
            any(data.precFailed | data.precUsesForbiddenInput)
        error('EXP5Paper:Baseline','PREC/native CSV identity invalid.');
    end
    nativePath = fullfile(config.projectRoot,'results','senlora_symmetric_v8', ...
        'case_snr_rician_k10','RICIAN_CASE_SNR_RAW_PACKETS.csv');
    native = readtable(nativePath);
    check = {'caseIndex','snrDb','packetId','payloadSeed','noiseSeed','channelSeed', ...
        'channelPower','senloraRawErrors','idealRawErrors'};
    for k = 1:numel(check)
        if ~isequal(data.(check{k}),native.(check{k}))
            error('EXP5Paper:Baseline','Native field mismatch.');
        end
    end
    raw = data(:,{'caseIndex','snrDb','packetId','orbitStartSec','rootSeed', ...
        'payloadSeed','noiseSeed','channelSeed','channelPower'});
    raw.pointIndex = raw.caseIndex; raw.channelIndex = repmat(2,height(raw),1);
    raw.channelModel = repmat("Rician",height(raw),1);
    initial = nan(height(raw),5);
    initial(:,1) = data.precRawErrors; initial(:,2) = data.senloraRawErrors;
    initial(:,4) = data.idealRawErrors;
    inputPaths = [string(matPath);string(csvPath);string(nativePath)];
else
    times = [-366;-274.5;-183;-91.5;0];
    snr = 15-10*log10(2^config.parent.physicalSf);
    rows = cell(10000,11); count = 0;
    for channel = 1:2
        for point = 1:5
            for packet = 1:1000
                key = localTrajectoryKey(plan,snr,point,packet);
                ledger = v4EventRandomLedger(1033100000,key);
                count = count+1;
                rows(count,:) = {channel,point,packet,times(point),snr,1033100000, ...
                    ledger.payloadSeed,ledger.noiseSeed,ledger.channelSeed, ...
                    double(point==5)+1,string(localChannel(channel))};
            end
        end
    end
    raw = cell2table(rows,'VariableNames',{'channelIndex','pointIndex','packetId', ...
        'orbitStartSec','snrDb','rootSeed','payloadSeed','noiseSeed','channelSeed', ...
        'caseIndex','channelModel'});
    [raw,initial,inputPaths] = localNativeFigureBaseline(config,raw);
end
raw.paperExtraNoiseSeed = zeros(height(raw),1);
for k = 1:height(raw)
    if stage=="CaseSnr", key = localCaseKey(plan,raw(k,:));
    else, key = localTrajectoryKey(plan,raw.snrDb(k),raw.pointIndex(k),raw.packetId(k)); end
    ledger = v4EventRandomLedger(raw.rootSeed(k),key);
    if ~isequal([ledger.payloadSeed,ledger.noiseSeed,ledger.channelSeed], ...
            [raw.payloadSeed(k),raw.noiseSeed(k),raw.channelSeed(k)])
        error('EXP5Paper:Seeds','Ledger mismatch.');
    end
    key.component = 'paper-eq17-down-midamble-quarter-noise';
    raw.paperExtraNoiseSeed(k) = v4KeyedSeed(raw.rootSeed(k),key);
end
end

function [raw,initial,inputs] = localNativeFigureBaseline(config,raw)
root = fullfile(config.projectRoot,'results','senlora_symmetric_v8','figure12_four_methods');
matPath = fullfile(root,'FOUR_CURVE_RESULT.mat');
csvPath = fullfile(root,'FOUR_CURVE_RAW_PACKETS.csv');
old = load(matPath);
if ~strcmp(old.signature.identity,'PAPER-POINT-EQ17-FOUR-CURVES-V1') || ...
        ~strcmp(old.signature.stage,'Figure12') || ~all(old.completed) || ...
        any(old.failed,'all') || any(old.forbidden,'all') || ...
        ~strcmp(old.stateDigest,localDigest(old))
    error('EXP5Paper:Baseline','Original native Figure12 baseline invalid.');
end
here = fileparts(mfilename('fullpath'));
changed = string(fullfile(here,{'runSenloraPaperPointFourCurves.m', ...
    'senloraPaperMidamblePointDecode.m','senloraPaperPointFrameLayout.m'}));
sources = string(old.signature.sourcePaths);
hashes = string(old.signature.sourceSha256);
mask = ismember(sources,changed);
% Only the three Paper-specific revised files may differ. Check their saved
% before-images too; all native receiver/generator dependencies must match.
localHashes(sources(~mask),hashes(~mask));
for k = find(mask).'
    [~,name,extension] = fileparts(sources(k));
    before = fullfile(here,'audit','paper_point_high_rate_before',name+extension);
    localHashes(string(before),hashes(k));
end
localHashes(old.signature.inputPaths,old.signature.inputSha256);
data = readtable(csvPath);
if height(data)~=height(raw) || ...
        ~isequal(data{:,{'precRawErrors','vpRawErrors','paperRawErrors', ...
        'nativeIdealRawErrors','paperIdealRawErrors'}},old.errors) || ...
        any(data.forbiddenInput) || any(data{:,{'precFailed','vpFailed', ...
        'paperFailed','nativeIdealFailed','paperIdealFailed'}},'all')
    error('EXP5Paper:Baseline','Original Figure12 CSV counters invalid.');
end
names = {'channelIndex','pointIndex','packetId','orbitStartSec','rootSeed', ...
    'payloadSeed','noiseSeed','channelSeed','caseIndex'};
for k = 1:numel(names)
    if ~isequal(data.(names{k}),raw.(names{k}))
        error('EXP5Paper:Baseline','Original Figure12 identity differs.');
    end
end
if any(abs(data.snrDb-raw.snrDb)>1e-12) || ...
        ~isequal(string(data.channelModel),raw.channelModel) || ...
        any(abs(data.channelPower-old.channelPower)>1e-12)
    error('EXP5Paper:Baseline','Original Figure12 conditions differ.');
end
raw.channelPower = old.channelPower;
raw.nativeRateGain = old.gain;
raw.nativeVpBlocks = old.vpBlocks;
initial = nan(height(raw),5);
initial(:,[1,2,4]) = old.errors(:,[1,2,4]);
inputs = [string(matPath);string(csvPath)];
end

function key = localCaseKey(plan,row)
key = struct('planVersion',plan.identity,'phase','case-ser-rician-k10', ...
    'track','two-case-native','channel','Rician-K10-packet-flat', ...
    'comparisonMode','frozen-v8-vs-ideal','snrDb',row.snrDb,'replicateId',row.packetId, ...
    'packetId',row.packetId,'eventType','single-native-frame','eventIndex',row.caseIndex,'sampleIndex',0);
end
function key = localTrajectoryKey(plan,snr,point,packet)
key = struct('planVersion',plan.identity,'phase','figure12-eq17-four-methods', ...
    'track','five-independent-orbit-points','channel','paired-AWGN-Rician-K10', ...
    'comparisonMode','PREC-VP-PaperPoint-theory','snrDb',snr,'replicateId',packet, ...
    'packetId',packet,'eventType','independent-native-paper-pair','eventIndex',point,'sampleIndex',0);
end
function channel = localChannel(index)
if index==1, channel = 'AWGN'; else, channel = 'Rician'; end
end

function p = localEvaluate(row,stage,config)
c = config.parent;
seeds = struct('payloadSeed',row.payloadSeed,'noiseSeed',row.noiseSeed, ...
    'channelSeed',row.channelSeed,'paperExtraNoiseSeed',row.paperExtraNoiseSeed);
p = struct('errors',nan(1,5),'failed',false(1,5),'message',strings(1,5), ...
    'forbidden',false(1,3),'gain',NaN,'vpBlocks',NaN,'channelPower',NaN);
if stage=="Figure12"
    p.gain = row.nativeRateGain; p.vpBlocks = row.nativeVpBlocks;
end
p.channelPower = row.channelPower;
paper = senloraPaperPointGenerateFrame(config,row.orbitStartSec,row.snrDb,seeds,char(row.channelModel));
if abs(paper.truth.channelPower-p.channelPower)>1e-12
    error('EXP5Paper:Pairing','Fading replay differs.');
end
try
    receiver = senloraPaperMidamblePointDecode(paper.observation,c);
    p.errors(3) = localCount(receiver,paper,c); p.forbidden(3) = localForbidden(receiver);
catch ex
    p.errors(3) = 112; p.failed(3) = true; p.message(3) = string(ex.message);
end
% The revised-frame Ideal executes only after the Paper decoder has returned.
% Native Ideal is an offline baseline; neither Ideal enters the receiver.
try
    ideal = exp1IdealDecode(paper,config); p.errors(5) = localCount(ideal,paper,c);
catch ex
    p.errors(5) = 112; p.failed(5) = true; p.message(5) = string(ex.message);
end
end
function errors = localCount(receiver,frame,c)
bins = receiver.detectedPhysicalBins(:);
if numel(bins)~=112 || any(~isfinite(bins) | bins<0 | bins>=c.dataAlphabetSize | bins~=floor(bins))
    error('EXP5Paper:DecoderOutput','Invalid symbol output.');
end
errors = sum(bins~=frame.truth.payloadPhysicalBins(:));
end
function forbidden = localForbidden(receiver)
names = {'usesPayloadTruth','usesOrbitTruth','usesCaseIdentity','usesSnrInput','usesTargetSer'};
forbidden = false;
for k = 1:numel(names)
    forbidden = forbidden || (isfield(receiver,names{k}) && receiver.(names{k}));
end
end

function localFrozen(config,plan,here)
manifest = jsondecode(fileread(fullfile(here,'v8_frozen_receiver_manifest.json')));
if ~strcmp(manifest.identity,plan.identity) || ~strcmp(manifest.officialEntry,'senloraSymmetricV8Decode') || ...
        manifest.parameters.d0Bins~=plan.driftBlendStartBins || ...
        manifest.parameters.d1Bins~=plan.driftBlendEndBins || manifest.formalStarted
    error('EXP5Paper:Frozen','V8 identity/parameters changed.');
end
names = {'senloraSymmetricV8Config.m','senloraSymmetricV8Decode.m', ...
    'senloraSymmetricV8JointBlockDecode.m','senloraSymmetricV8BlockLikelihood.m', ...
    'senloraSymmetricV8BlendBootstrap.m','senloraSymmetricV8GenerateFrame.m'};
for k = 1:numel(names)
    localHashes(string(fullfile(here,names{k})),string(manifest.sourceSha256.(matlab.lang.makeValidName(names{k}))));
end
locked = jsondecode(fileread(config.parentManifestPath));
names = {'v4HuangPrecUnifiedDecodeV9','v4HuangPrecDecodeV3','v4HuangStaticDecode'};
for k = 1:numel(names)
    path = which(names{k}); relative = strrep(erase(path,[config.parentRoot,filesep]),'\','/');
    entry = locked.files(strcmp({locked.files.path},relative));
    if numel(entry)~=1, error('EXP5Paper:Frozen','PREC source not in manifest.'); end
    localHashes(string(path),string(entry.sha256));
end
end
function localHashes(paths,hashes)
paths = string(paths); hashes = string(hashes);
if numel(paths)~=numel(hashes), error('EXP5Paper:Hash','Hash dimensions differ.'); end
for k = 1:numel(paths)
    if ~isfile(paths(k)) || ~strcmpi(exp1Sha256(paths(k)),hashes(k))
        error('EXP5Paper:Hash','Changed source/input: %s.',paths(k));
    end
end
end
function signature = localSignature(stage,config,raw,inputs,here,parameters)
names = {'runSenloraPaperPointFourCurves','senloraPaperPointGenerateFrame', ...
    'senloraPaperMidamblePointDecode','senloraPaperPointFrameLayout', ...
    'senloraSymmetricV8Decode','v4HuangPrecUnifiedDecodeV9', ...
    'senloraSymmetricV8GenerateFrame','senloraSymmetricV8GenerateRicianFrame'};
explicit = strings(numel(names),1);
for k = 1:numel(names), explicit(k) = string(which(names{k})); end
required = string(matlab.codetools.requiredFilesAndProducts(cellstr(explicit)));
allPaths = unique([required(:);explicit]);
inScope = startsWith(allPaths,string(config.projectRoot)+filesep,'IgnoreCase',true) | ...
    startsWith(allPaths,string(config.parentRoot)+filesep,'IgnoreCase',true);
sources = sort(allPaths(inScope)); hashes = strings(size(sources));
for k = 1:numel(sources), hashes(k) = exp1Sha256(sources(k)); end
paperPath = fullfile(fileparts(config.projectRoot),'参考论文', ...
    'Doppler_Estimation_and_Compensation_Techniques_in_LoRa_Direct-to-Satellite_Communications.pdf');
inputs = unique([inputs;string(config.parentManifestPath);string(parameters.sourcePath); ...
    string(fullfile(fileparts(which('v4LoadMethodAlignedParametersV1')), ...
    'method_aligned_selected_parameters_v1.json')); ...
    string(fullfile(here,'v8_frozen_receiver_manifest.json'));string(paperPath)]);
inputHashes = strings(size(inputs));
for k = 1:numel(inputs), inputHashes(k) = exp1Sha256(inputs(k)); end
signature = struct('identity','PAPER-POINT-EQ17-NATIVE-NINT1-FFT16-V2','stage',stage, ...
    'packetsPerCell',1000,'methods',{{'PREC V9','VP V8','theory','Paper Eq17'}}, ...
    'paperPhysicalFullSymbols',234,'paperTotalSymbolDuration',234.25, ...
    'paperMidambleSpacingDataSymbols',1,'paperPointFftPaddingFactor',16, ...
    'nativePhysicalSymbols',120,'snrDb',unique(raw.snrDb), ...
    'orbitStartSec',unique(raw.orbitStartSec),'sf',12,'cr',3,'ldro',false, ...
    'sourcePaths',sources,'sourceSha256',hashes,'inputPaths',inputs,'inputSha256',inputHashes);
end
function hash = localDigest(state)
copy = state; if isfield(copy,'stateDigest'), copy = rmfield(copy,'stateDigest'); end
bytes = getByteStreamFromArray(orderfields(copy));
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(uint8(bytes(:)),'int8'));
hash = lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end

function summary = localSummary(raw,state,stage,c)
keys = unique(raw{:,{'channelIndex','pointIndex','orbitStartSec','snrDb'}},'rows');
rows = cell(size(keys,1),15);
for k = 1:size(keys,1)
    key = keys(k,:);
    m = raw.channelIndex==key(1) & raw.pointIndex==key(2) & ...
        raw.orbitStartSec==key(3) & raw.snrDb==key(4);
    if sum(m)~=1000 || ~isequal(sort(raw.packetId(m)),(1:1000).')
        error('EXP5Paper:Summary','Cell is not exactly 1000 unique packets.');
    end
    errors = sum(state.errors(m,:),1); ser = errors/112000;
    if key(1)==1, theory = senloraSymmetricV8AwgnTheory(12,key(4));
    else, theory = senloraSymmetricV8RicianTheory(12,key(4),10); end
    rows(k,:) = {key(1),key(2),key(3),key(4),1000, ...
        errors(1),errors(2),errors(3),errors(4),errors(5), ...
        ser(1),ser(2),ser(3),theory,sum(state.failed(m,:),'all')};
end
summary = cell2table(rows,'VariableNames',{'channelIndex','pointIndex','orbitStartSec','snrDb', ...
    'packets','precRawErrors','vpRawErrors','paperRawErrors','nativeIdealRawErrors','paperIdealRawErrors', ...
    'precSer','vpSer','paperSer','theorySer','failedDecodes'});
if any(~isfinite(summary{:,{'precSer','vpSer','paperSer','theorySer'}}),'all')
    error('EXP5Paper:Summary','Nonfinite curve data.');
end
summary.nativeFrameSec = repmat(120*c.symbolDurationSec,height(summary),1);
summary.paperFrameSec = repmat(234.25*c.symbolDurationSec,height(summary),1);
summary.paperMidambleSpacingDataSymbols = ones(height(summary),1);
summary.paperPointFftPaddingFactor = repmat(16,height(summary),1);
summary.stage = repmat(stage,height(summary),1);
end
function localPlot(summary,stage,root)
if stage=="CaseSnr"
    fig = figure('Visible','off','Color','w','Position',[100 100 1240 600]);
    tiles = tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    for point = 1:2, localAxes(nexttile,summary(summary.pointIndex==point,:),stage,point); end
    title(tiles,'Rician K=10 dB: native PHY, Paper n_{int}=1, 1000 packets/point');
    exportgraphics(fig,fullfile(root,'CASE1_CASE2_FOUR_CURVES.png'),'Resolution',220); close(fig);
    for point = 1:2
        fig = figure('Visible','off','Color','w','Position',[100 100 850 620]);
        localAxes(axes('Parent',fig),summary(summary.pointIndex==point,:),stage,point);
        exportgraphics(fig,fullfile(root,sprintf('CASE%d_FOUR_CURVES.png',point)),'Resolution',220); close(fig);
    end
else
    fig = figure('Visible','off','Color','w','Position',[100 100 1240 610]);
    tiles = tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
    for channel = 1:2, localAxes(nexttile,summary(summary.channelIndex==channel,:),stage,channel); end
    title(tiles,'Figure12 sampling: SF12 user PHY, E_s/N_0=15 dB, Paper n_{int}=1');
    exportgraphics(fig,fullfile(root,'FIGURE12_AWGN_RICIAN_FOUR_CURVES.png'),'Resolution',220); close(fig);
    for channel = 1:2
        fig = figure('Visible','off','Color','w','Position',[100 100 850 620]);
        localAxes(axes('Parent',fig),summary(summary.channelIndex==channel,:),stage,channel);
        exportgraphics(fig,fullfile(root,sprintf('FIGURE12_%s_FOUR_CURVES.png',upper(localChannel(channel)))), ...
            'Resolution',220); close(fig);
    end
end
end
function localAxes(ax,data,stage,id)
if stage=="CaseSnr", data = sortrows(data,'snrDb'); x = data.snrDb;
else, data = sortrows(data,'orbitStartSec'); x = data.orbitStartSec; end
hold(ax,'on');
plot(ax,x,data.precSer,'-v','Color',[0.6350 0.0780 0.1840],'LineWidth',1.5,'DisplayName','PREC (existing V9)');
plot(ax,x,data.vpSer,'-o','Color',[0 0.4470 0.7410],'LineWidth',1.5,'DisplayName','VP (your frozen V8)');
plot(ax,x,data.theorySer,'-k','LineWidth',1.7,'DisplayName','Theory (no Doppler)');
plot(ax,x,data.paperSer,'-s','Color',[0.4660 0.6740 0.1880],'LineWidth',1.5, ...
    'DisplayName','Paper Midamble-Point (Eq17, native n_{int}=1)');
set(ax,'YScale','log'); ylim(ax,[1e-5 1]); grid(ax,'on'); grid(ax,'minor'); ylabel(ax,'Raw SER');
if stage=="CaseSnr"
    xlim(ax,[-30 -21]); xticks(ax,-30:-21); xlabel(ax,'SNR (dB)');
    title(ax,sprintf('Case %d: t_0=%.0f s',id,data.orbitStartSec(1)));
else
    ticks = [-366,-274.5,-183,-91.5,0]; xlim(ax,[-375 9]); xticks(ax,ticks);
    xticklabels(ax,{'-366s','-274.5s','-183s','-91.5s','0s'}); xtickangle(ax,30);
    xlabel(ax,'Time (t) [s]'); title(ax,sprintf('%s: SNR=%.5f dB',localChannel(id),data.snrDb(1)));
end
legend(ax,'Location','southwest','FontSize',9);
end
