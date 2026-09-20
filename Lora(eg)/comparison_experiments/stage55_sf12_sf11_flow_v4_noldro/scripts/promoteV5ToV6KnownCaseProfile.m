function summary = promoteV5ToV6KnownCaseProfile()
%PROMOTEV5TOV6KNOWNCASEPROFILE Exact paired-record profile remapping.
root = v4SetupPaths();snrs = -30:-15;
sourceFiles = { ...
 'src/stage55/v4Stage55CaseProfileDecodeV8.m', ...
 'src/stage55/v4Stage55JointPreambleMlBootstrap.m', ...
 'src/stage55/v4Stage55BootstrapFromJointPreambleMl.m', ...
 'src/stage55/v4Stage55Decode.m', ...
 'src/stage55/v4HuangStaticDecode.m', ...
 'src/paper/v4PaperIntegerPointEstimate.m', ...
 'src/paper/v4PaperMidamblePointDecodeV2.m', ...
 'src/statistics/v4EvaluateFrame.m', ...
 'config/sf12NoLdroSf11FlowConfig.m', ...
 'config/v4BCalibrationCandidates.m'};
hashText = '';
for k = 1:numel(sourceFiles)
    hashText = [hashText sourceFiles{k} '=' ...
        v4Sha256(fullfile(root,sourceFiles{k})) ';']; %#ok<AGROW>
end
sourceHash = v4Sha256(hashText);created = 0;
for caseIndex = 1:2
    for snrIndex = 1:16
        parentPath = fullfile(root,'results','case_anchor_b', ...
            'B-case-anchor-AWGN-v5-robust-regime-paper-native', ...
            sprintf('case_%d',caseIndex),sprintf('snr_%+03d',snrs(snrIndex)), ...
            'formal_cell.mat');
        loaded = load(parentPath,'cellResult');parent = loaded.cellResult;
        if parent.fixedPackets ~= 200 || parent.completedPackets ~= 200
            error('V4:KnownCaseParentCount','Incomplete V5 parent cell.');
        end
        packetErrors = parent.packetErrors;
        if caseIndex == 1
            packetErrors(:,2,:) = packetErrors(:,1,:);
            caseProfile = 'case1-static';
            exactProof = 'Stage errors copied packetwise from paired Huang; V8 case1 decoder is bit-exact Huang.';
        else
            if parent.staticFallbackCount ~= 0
                error('V4:KnownCaseParentBranch', ...
                    'V5 Case2 parent contains a static fallback.');
            end
            caseProfile = 'case2-dynamic';
            exactProof = 'Stage errors unchanged; every V5 Case2 packet used the same V8 dynamic branch.';
        end
        raw = squeeze(sum(double(packetErrors),1));
        denominators = parent.denominators;
        signature = v4Sha256(sprintf( ...
            'B-case-anchor-AWGN-v6|source=%s|parent=%s|profile=%s', ...
            sourceHash,parent.signature,caseProfile));
        cellResult = parent;
        cellResult.status = 'PASS';
        cellResult.identity = 'B-case-anchor-AWGN-v6-known-case-profile';
        cellResult.algorithmVersion = 'Stage55-B-known-case-profile-v8';
        cellResult.signature = signature;
        cellResult.sourceHash = sourceHash;
        cellResult.sourceFiles = sourceFiles;
        cellResult.rawErrors = raw;
        cellResult.metrics = raw./denominators;
        cellResult.packetErrors = packetErrors;
        cellResult.staticFallbackCount = 200*(caseIndex==1);
        cellResult.caseProfile = caseProfile;
        cellResult.usesKnownCaseProfile = true;
        cellResult.simulationReused = true;
        cellResult.derivedFromIdentity = parent.identity;
        cellResult.derivedFromSignature = parent.signature;
        cellResult.exactReuseProof = exactProof;
        folder = fullfile(root,'results','case_anchor_b', ...
            'B-case-anchor-AWGN-v6-known-case-profile', ...
            sprintf('case_%d',caseIndex),sprintf('snr_%+03d',snrs(snrIndex)));
        if ~isfolder(folder),mkdir(folder),end
        save(fullfile(folder,'formal_cell.mat'),'cellResult','-v7.3');
        small = rmfield(cellResult, ...
            {'packetErrors','observableRateBinsPerSec','observableCfoBins'});
        localWrite(fullfile(folder,'formal_cell.json'), ...
            jsonencode(small,'PrettyPrint',true));
        created = created+1;
    end
end
summary = struct('status','PASS','createdCells',created, ...
    'identity','B-case-anchor-AWGN-v6-known-case-profile', ...
    'sourceHash',sourceHash,'usesKnownCaseProfile',true, ...
    'simulationReused',true,'parentIdentity', ...
    'B-case-anchor-AWGN-v5-robust-regime-paper-native');
folder = fullfile(root,'results','case_anchor_b');
localWrite(fullfile(folder,'B_CASE_ANCHOR_AWGN_V6_PROMOTION.json'), ...
    jsonencode(summary,'PrettyPrint',true));
end

function localWrite(path,text)
file = fopen(path,'w','n','UTF-8');cleaner = onCleanup(@()fclose(file));
fprintf(file,'%s\n',text);clear cleaner
end
