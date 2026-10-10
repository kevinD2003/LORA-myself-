function validatePilotTimeAlignedResults()
%VALIDATEPILOTTIMEALIGNEDRESULTS Full-run checks including unchanged resume.
here = fileparts(fileparts(mfilename('fullpath')));
addpath(here,fullfile(here,'..','scripts'));
paths = exp1SetupPaths();
config = exp1Config();
folders = {'pilot_time_aligned_case_snr_rician','figure12_pilot_time_aligned'};
stages = ["CaseSnr","Figure12"];
expected = [20000,10000];
errorNames = {'precRawErrors','vpRawErrors','comparisonRawErrors', ...
    'nativeIdealRawErrors','comparisonIdealRawErrors'};
failureNames = {'precFailed','vpFailed','comparisonFailed', ...
    'nativeIdealFailed','comparisonIdealFailed'};
for stageIndex = 1:2
    root = fullfile(paths.resultsRoot,'senlora_symmetric_v8',folders{stageIndex});
    state = load(fullfile(root,'FOUR_CURVE_CHECKPOINT.mat'));
    result = load(fullfile(root,'FOUR_CURVE_RESULT.mat'));
    assert(isequaln(state,result),'Checkpoint and result differ.');
    assert(strcmp(state.stateDigest,localDigest(state)),'State digest differs.');
    assert(strcmp(state.signature.identity,'PILOT-TIME-ALIGNED-BRACKET-CFO-FOUR-CURVES-V1'));
    assert(state.signature.receiverMode=="PilotTimeAligned");
    assert(~state.signature.isOriginalPaperThirdMethod);
    assert(state.signature.usesFuturePilots && state.signature.usesPilotTimeInterpolation);
    assert(~state.signature.usesWithinSymbolRate);
    localHashes(state.signature.sourcePaths,state.signature.sourceSha256);
    localHashes(state.signature.inputPaths,state.signature.inputSha256);
    raw = readtable(fullfile(root,'FOUR_CURVE_RAW_PACKETS.csv'));
    summary = readtable(fullfile(root,'FOUR_CURVE_SUMMARY.csv'));
    assert(height(raw)==expected(stageIndex) && all(state.completed));
    assert(all(string(raw.receiverMode)=="PilotTimeAligned"));
    assert(all(string(summary.receiverMode)=="PilotTimeAligned"));
    assert(~any(raw.isOriginalPaperThirdMethod) && ~any(summary.isOriginalPaperThirdMethod));
    assert(~any(contains(raw.Properties.VariableNames,{'paperRawErrors','paperSer','paperFailed'})));
    counters = raw{:,errorNames};
    assert(all(isfinite(counters) & counters>=0 & counters<=112 & counters==floor(counters),'all'));
    assert(isequal(counters,state.errors));
    assert(isequal(logical(raw{:,failureNames}),state.failed));
    assert(~any(state.failed,'all') && ~any(state.forbidden,'all') && ~any(raw.forbiddenInput));
    assert(isequal(raw.alignedRawErrors,raw.comparisonRawErrors));
    assert(isequal(raw.alignedIdealRawErrors,raw.comparisonIdealRawErrors));
    assert(isequal(logical(raw.alignedFailed),state.failed(:,3)));
    assert(isequal(logical(raw.alignedIdealFailed),state.failed(:,5)));
    localClose(raw.channelPower,state.channelPower);
    localClose(raw.rateGain,state.gain);
    localClose(raw.acceptedVpBlocks,state.vpBlocks);
    keys = {'channelIndex','pointIndex','orbitStartSec','snrDb'};
    assert(size(unique(raw{:,{'channelIndex','pointIndex','snrDb','packetId'}},'rows'),1)==height(raw));
    assert(height(summary)==expected(stageIndex)/1000);
    for cellIndex = 1:height(summary)
        select = true(height(raw),1);
        for key = keys
            select = select & raw.(key{1})==summary.(key{1})(cellIndex);
        end
        assert(sum(select)==1000 && isequal(sort(raw.packetId(select)),(1:1000).'));
        totals = sum(counters(select,:),1);
        assert(isequal(summary{cellIndex,errorNames},totals));
        localClose(summary{cellIndex,{'precSer','vpSer','comparisonSer'}},totals(1:3)/112000);
        assert(summary.packets(cellIndex)==1000 && summary.failedDecodes(cellIndex)==0);
        if summary.channelIndex(cellIndex)==1
            theory = senloraSymmetricV8AwgnTheory(12,summary.snrDb(cellIndex));
        else
            theory = senloraSymmetricV8RicianTheory(12,summary.snrDb(cellIndex),10);
        end
        localClose(summary.theorySer(cellIndex),theory);
    end
    localClose(summary.nativeFrameSec,repmat(120*config.parent.symbolDurationSec,height(summary),1));
    localClose(summary.paperFrameSec,repmat(234.25*config.parent.symbolDurationSec,height(summary),1));
    localClose(summary.alignedSer,summary.comparisonSer);
    if stageIndex==1
        assert(isequal(unique(raw.snrDb),(-30:-21).'));
        assert(all(raw.channelIndex==2) && all(raw.rootSeed==1032900000));
        assert(isequal(unique(raw.orbitStartSec),[-366;0]));
        baseline = readtable(fullfile(paths.resultsRoot,'senlora_symmetric_v8', ...
            'case_snr_rician_k10_prec_comparison','RICIAN_PREC_RAW_PACKETS.csv'));
        fields = {'caseIndex','snrDb','packetId','orbitStartSec','rootSeed', ...
            'payloadSeed','noiseSeed','channelSeed','channelPower','precRawErrors'};
        for field = fields, localClose(raw.(field{1}),baseline.(field{1})); end
        assert(isequal(raw.vpRawErrors,baseline.senloraRawErrors));
        assert(isequal(raw.nativeIdealRawErrors,baseline.idealRawErrors));
        images = {'CASE1_FOUR_CURVES.png','CASE2_FOUR_CURVES.png','CASE1_CASE2_FOUR_CURVES.png'};
    else
        assert(isequal(unique(raw.orbitStartSec),[-366;-274.5;-183;-91.5;0]));
        localClose(raw.snrDb,repmat(15-10*log10(4096),height(raw),1));
        assert(all(raw.rootSeed==1033100000));
        awgn = sortrows(raw(raw.channelIndex==1,:),{'pointIndex','packetId'});
        rician = sortrows(raw(raw.channelIndex==2,:),{'pointIndex','packetId'});
        for field = {'pointIndex','packetId','payloadSeed','noiseSeed','channelSeed','paperExtraNoiseSeed'}
            assert(isequal(awgn.(field{1}),rician.(field{1})));
        end
        baseline = readtable(fullfile(paths.resultsRoot,'senlora_symmetric_v8', ...
            'figure12_four_methods','FOUR_CURVE_RAW_PACKETS.csv'));
        for field = {'channelIndex','pointIndex','packetId','payloadSeed','noiseSeed', ...
                'channelSeed','precRawErrors','vpRawErrors','nativeIdealRawErrors','channelPower'}
            localClose(raw.(field{1}),baseline.(field{1}));
        end
        localClose(raw.rateGain,baseline.rateGain);
        localClose(raw.acceptedVpBlocks,baseline.acceptedVpBlocks);
        images = {'FIGURE12_AWGN_FOUR_CURVES.png','FIGURE12_RICIAN_FOUR_CURVES.png', ...
            'FIGURE12_AWGN_RICIAN_FOUR_CURVES.png'};
    end
    for imageIndex = 1:numel(images)
        info = imfinfo(fullfile(root,images{imageIndex}));
        assert(info.Width>=1500 && info.Height>=1000);
    end
    resumed = runSenloraPaperPointFourCurves(Stage=stages(stageIndex), ...
        ReceiverMode="PilotTimeAligned",UseParallel=false);
    assert(strcmp(resumed.status,'FOUR_CURVES_COMPLETE') && resumed.failedDecodes==0);
    assert(resumed.allForbiddenFlagsFalse && resumed.completedPackets==expected(stageIndex));
    assert(isequaln(state,load(fullfile(root,'FOUR_CURVE_CHECKPOINT.mat'))));
    assert(isequaln(raw,readtable(fullfile(root,'FOUR_CURVE_RAW_PACKETS.csv'))));
    fprintf('VALIDATION PASS %s: %d rows, %d cells, 1000 IDs/cell, unchanged resume.\n', ...
        stages(stageIndex),height(raw),height(summary));
end
fprintf('ALL SIX PLOTS / 30000 PAIRED ROWS VALIDATED.\n');
end

function localClose(actual,expected)
assert(isequal(size(actual),size(expected)));
assert(isequal(isnan(actual),isnan(expected)));
select = ~isnan(expected);
assert(all(isfinite(actual(select)) & abs(actual(select)-expected(select))<=1e-12,'all'));
end

function localHashes(paths,hashes)
for k = 1:numel(paths)
    assert(strcmpi(exp1Sha256(paths(k)),hashes(k)),'Changed source/input: %s',string(paths(k)));
end
end

function hash = localDigest(state)
copy = rmfield(state,'stateDigest');
bytes = getByteStreamFromArray(orderfields(copy));
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(uint8(bytes(:)),'int8'));
hash = lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
