function output = runSenloraSymmetricV3Smoke()
%RUNSENLORASYMMETRICV3SMOKE Independent paired full-orbit V3 smoke.

paths = exp1SetupPaths();
addpath(fullfile(paths.projectRoot,'review_first_v1'));
addpath(fullfile(paths.projectRoot,'senlora_symmetric_v2'));
config = exp1Config();
plan = senloraSymmetricV3Config(config);
parameters = v4LoadMethodAlignedR3ParametersV1();
negative = plan.negativeOrbitStartSec(:);
n = plan.smokePackets;
pairCount = numel(negative);
payloadCount = config.parent.payloadSymbolCount;
jobCount = pairCount*n;
jobPairs = repmat((1:pairCount).',n,1);
jobPackets = repelem((1:n).',pairCount);
v2Errors = zeros(jobCount,2,'uint16');
v3Errors = zeros(jobCount,2,'uint16');
parentErrors = zeros(jobCount,2,'uint16');
failed = false(jobCount,2);
loboVerified = false(jobCount,2);
case1Exact = false(jobCount,1);
parentProtected = false(jobCount,2);

pool = gcp('nocreate');
if isempty(pool), parpool('local',6); end
parfor job = 1:jobCount
    pairIndex = jobPairs(job);
    packetId = jobPackets(job);
    starts = [negative(pairIndex), ... %#ok<PFBNS>
        -negative(pairIndex)-plan.frameDurationSec]; %#ok<PFBNS>
    ledger = senloraSymmetricV3SeedPlan(config,plan,'smoke', ...
        pairIndex,plan.snrDb,packetId);
    localV2 = zeros(1,2,'uint16');
    localV3 = zeros(1,2,'uint16');
    localParent = zeros(1,2,'uint16');
    localFailed = false(1,2);
    localLobo = false(1,2);
    localProtected = false(1,2);
    localCase1Exact = true;
    for side = 1:2
        try
            frame = exp1GenerateFrame(config,starts(side),plan.snrDb,ledger);
            common = v4CommonBootstrap( ...
                frame.observation.rxPhysical(1:8,:),config.parent, ...
                SearchStepBins=parameters.searchStepBins); %#ok<PFBNS>
            result = senloraSymmetricV3Decode( ...
                frame.observation,common,config,plan);
            truth = frame.truth.payloadPhysicalBins(:);
            localV2(side) = uint16(sum( ...
                result.v2CandidateDetectedPhysicalBins(:)~=truth));
            localV3(side) = uint16(sum( ...
                result.detectedPhysicalBins(:)~=truth));
            localParent(side) = uint16(sum( ...
                result.frozenParentHypothesis.detectedPhysicalBins(:)~=truth));
            localLobo(side) = result.decision.leaveOneBlockOut && ...
                ~result.decision.selfBlockUsedForFit;
            localProtected(side) = result.decision.parentStaticProtected;
            if pairIndex==1 && side==1
                localCase1Exact = isequal( ...
                    result.detectedPhysicalBins(:), ...
                    result.frozenParentHypothesis.detectedPhysicalBins(:)) && ...
                    isequal(result.hardDecodedDataBits(:), ...
                    result.frozenParentHypothesis.hardDecodedDataBits(:));
            end
        catch exception
            localFailed(side) = true;
            localV2(side) = uint16(payloadCount);
            localV3(side) = uint16(payloadCount);
            localParent(side) = uint16(payloadCount);
            if pairIndex==1 && side==1, localCase1Exact = false; end
            warning('EXP5V3:SmokeFailure', ...
                'Pair %d packet %d side %d: %s', ...
                pairIndex,packetId,side,exception.message);
        end
    end
    v2Errors(job,:) = localV2;
    v3Errors(job,:) = localV3;
    parentErrors(job,:) = localParent;
    failed(job,:) = localFailed;
    loboVerified(job,:) = localLobo;
    parentProtected(job,:) = localProtected;
    case1Exact(job) = localCase1Exact;
end

rows = cell(pairCount,15);
for pairIndex = 1:pairCount
    jobs = jobPairs==pairIndex;
    v2 = sum(double(v2Errors(jobs,:)),1);
    v3 = sum(double(v3Errors(jobs,:)),1);
    parent = sum(double(parentErrors(jobs,:)),1);
    target = localUpperTarget(negative(pairIndex),plan);
    rows(pairIndex,:) = {negative(pairIndex), ...
        -negative(pairIndex)-plan.frameDurationSec,n, ...
        v2(1)/(n*payloadCount),v2(2)/(n*payloadCount), ...
        v3(1)/(n*payloadCount),v3(2)/(n*payloadCount), ...
        parent(1)/(n*payloadCount),parent(2)/(n*payloadCount),target, ...
        sum(parentProtected(jobs,1)),sum(parentProtected(jobs,2)), ...
        sum(failed(jobs,:),'all'),all(loboVerified(jobs,:),'all'), ...
        all(v3<=n*payloadCount*target)};
end
summary = cell2table(rows,'VariableNames',{ ...
    'negativeOrbitStartSec','positiveMirrorStartSec','packets', ...
    'v2NegativeSer','v2PositiveSer','v3NegativeSer','v3PositiveSer', ...
    'parentNegativeSer','parentPositiveSer','upperTargetSer', ...
    'negativeParentProtectedPackets','positiveParentProtectedPackets', ...
    'failedPackets','leaveOneBlockOutVerified','bothSidesBelowUpper'});
case1Jobs = jobPairs==1;
shape = struct('status','SMOKE_COMPLETE', ...
    'case1ExactPackets',sum(case1Exact(case1Jobs)), ...
    'case1TotalPackets',n,'failedPackets',sum(failed,'all'), ...
    'leaveOneBlockOutVerified',all(loboVerified,'all'), ...
    'v2PooledErrors',sum(v2Errors,'all'), ...
    'v3PooledErrors',sum(v3Errors,'all'), ...
    'v3NoWorseOverall',sum(v3Errors,'all')<=sum(v2Errors,'all'), ...
    'allPointsBelowUpper',all(summary.bothSidesBelowUpper), ...
    'formalStarted',false);
root = fullfile(paths.resultsRoot,'senlora_symmetric_v3','smoke');
if ~isfolder(root), mkdir(root); end
writetable(summary,fullfile(root,'SMOKE_SUMMARY.csv'));
save(fullfile(root,'SMOKE_RESULT.mat'),'summary','shape','plan', ...
    'v2Errors','v3Errors','parentErrors','failed','loboVerified', ...
    'case1Exact','parentProtected','-v7.3');
output = struct('status',shape.status,'summary',summary,'shape',shape, ...
    'resultRoot',root,'formalStarted',false);
end

function target = localUpperTarget(t0,plan)
u = min(1,max(0,(t0-plan.negativeOrbitStartSec(1))/ ...
    abs(plan.negativeOrbitStartSec(1))));
target = 10^(log10(plan.targetCase1Ser)+u*( ...
    log10(plan.targetCenterSer)-log10(plan.targetCase1Ser)));
end
