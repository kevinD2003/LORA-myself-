classdef V4Stage3RMechanismTest < matlab.unittest.TestCase
    methods (Test)
        function singleCandidateDoesNotCommit(testCase)
            [packet,c,p]=localPacket(-366,Inf,1);
            row=packet.schedule.dataRows(1);
            r=v4TrackAStage55PendingLockDecode(packet,c,p,StopAfterPhysicalRow=row);
            testCase.verifyEqual(r.committedVpCount,0);
            testCase.verifyEqual(r.finalLockState,'PENDING_BOOTSTRAP');
        end
        function twoCandidatesCommitAtomicallyAndLater(testCase)
            [packet,c,p]=localPacket(-366,Inf,2);
            r=v4TrackAStage55PendingLockDecode(packet,c,p);
            testCase.verifyGreaterThanOrEqual(r.committedVpCount,2);
            first=r.commitRecords(1:2);
            testCase.verifyEqual([first.transactionId],[first(1).transactionId first(1).transactionId]);
            testCase.verifyGreaterThanOrEqual([first.releaseAtSec],[first.measurementTimeSec]);
            testCase.verifyGreaterThan([first.firstEffectiveTimeSec],[first.releaseAtSec]-1e-12);
        end
        function processingDelayMovesEffectiveSlot(testCase)
            [packet,c,p]=localPacket(-366,Inf,3);
            a=v4TrackAStage55PendingLockDecode(packet,c,p,ProcessingDelaySec=0);
            b=v4TrackAStage55PendingLockDecode(packet,c,p,ProcessingDelaySec=1.2*c.symbolDurationSec);
            testCase.verifyGreaterThan(b.commitRecords(1).firstEffectivePhysicalRow, ...
                a.commitRecords(1).firstEffectivePhysicalRow);
        end
        function differentFutureCannotChangePrefix(testCase)
            [a,c,p]=localPacket(-366,-21,4); b=a;
            futureRow=a.schedule.dataRows(6); first=a.schedule.startSample(futureRow)+1;
            b.rx(first:end)=-b.rx(first:end);
            ra=v4TrackAStage55PendingLockDecode(a,c,p);rb=v4TrackAStage55PendingLockDecode(b,c,p);
            testCase.verifyEqual(ra.detectedPhysicalBins(1:5),rb.detectedPhysicalBins(1:5));
            testCase.verifyEqual(ra.virtualPilotAccepted(1:5),rb.virtualPilotAccepted(1:5));
            testCase.verifyEqual(ra.releaseAtSec(1:5),rb.releaseAtSec(1:5));
        end
        function ambiguityDoesNotForcePair(testCase)
            p=localParameters();p.branchRateAgreementLimitBinsPerSec=0.1;
            q=localSyntheticCandidates([0 0;1 1;2 2.5]);
            d=v4TrackABranchConsistency(q,p,2);
            testCase.verifyFalse(d.release);
        end
        function lostStateRejectsRestOfPacket(testCase)
            [packet,c,p]=localPacket(-366,Inf,5);
            cutoff=packet.schedule.dataRows(4);first=packet.schedule.startSample(cutoff)+1;
            packet.rx(first:end)=0;
            r=v4TrackAStage55PendingLockDecode(packet,c,p);
            testCase.verifyEqual(r.finalLockState,'LOST');
            committed=find(r.virtualPilotAccepted);
            if ~isempty(committed)
                afterLoss=find(packet.truth.dataCenterTimeSec-packet.truth.caseStartTimeSec>r.lossTimeSec);
                testCase.verifyFalse(any(r.virtualPilotAccepted(afterLoss)));
            end
        end
        function checkpointResumeMatchesOneShot(testCase)
            [packet,c,p]=localPacket(-366,-21,6);
            stop=packet.schedule.dataRows(5);
            partial=v4TrackAStage55PendingLockDecode(packet,c,p,StopAfterPhysicalRow=stop);
            resumed=v4TrackAStage55PendingLockDecode(packet,c,p,ResumeState=partial.checkpointState);
            one=v4TrackAStage55PendingLockDecode(packet,c,p);
            testCase.verifyEqual(resumed.detectedPhysicalBins,one.detectedPhysicalBins);
            testCase.verifyEqual(resumed.virtualPilotAccepted,one.virtualPilotAccepted);
            testCase.verifyEqual(resumed.finalLockState,one.finalLockState);
            testCase.verifyEqual(resumed.commitRecords,one.commitRecords);
        end
        function scoringUsesCommittedFrozenLabels(testCase)
            [packet,c,p]=localPacket(0,-21,7);
            r=v4TrackAStage55PendingLockDecode(packet,c,p);
            metrics=v4EvaluateTrackAPacket(r,packet.truth,c);
            expected=sum(r.virtualPilotAccepted & r.vpUsedLabel~=packet.truth.labels);
            testCase.verifyEqual(metrics.vpFalseAccepted,expected);
        end
        function receiverSourceContainsNoForbiddenInputs(testCase)
            root=v4SetupPaths();content=fileread(fullfile(root,'src','paper_anchor', ...
                'v4TrackAStage55PendingLockDecode.m'));
            testCase.verifyFalse(contains(content,'packet.truth'));
            testCase.verifyFalse(contains(content,'v4DecodePayload'));
            testCase.verifyFalse(contains(content,'midambleResidual'));
        end
        function oldPaperAndFailureEvidenceRemainValid(testCase)
            results=run(matlab.unittest.TestSuite.fromClass(?V4PaperNativeEstimatorIsolationTest));
            testCase.verifyTrue(all([results.Passed]));
            root=v4SetupPaths();manifest=jsondecode(fileread(fullfile(root,'config','r3_failure_evidence_manifest.json')));
            for i=1:numel(manifest.files)
                testCase.verifyEqual(v4Sha256(fullfile(root,manifest.files(i).path)),manifest.files(i).sha256);
            end
        end
    end
end

function [packet,c,p]=localPacket(caseTime,snr,packetId)
c=sf12NoLdroSf11FlowConfig();p=localParameters();
packet=v4GenerateTrackAPacket(c,caseTime,snr,packetId,610000000);
end
function p=localParameters()
p=struct('decisionPeakRatioThreshold',1,'maximumNormalizedEntropy',1, ...
    'residualPeakRatioThreshold',1,'innovationLimitBins',1, ...
    'residualStepBins',0.05,'historyDecay',0.85,'huberThresholdBins',0.5, ...
    'maximumRateBinsPerSec',20,'branchResidualLimitBins',1, ...
    'branchRateAgreementLimitBinsPerSec',20,'pendingWindowDataSymbols',3, ...
    'lostAfterRejectedData',3,'historyLength',8);
end
function q=localSyntheticCandidates(values)
empty=struct('candidateId',0,'dataIndex',0,'physicalRow',0,'hardLabel',0, ...
    'measurementTimeSec',0,'decisionAtSec',0,'availableAtSec',0, ...
    'cfoCandidateBins',0,'predictedCfoBins',0,'peakRatio',10, ...
    'entropyNormalized',0,'residualPeakRatio',10,'innovationBins',0, ...
    'qualityPassed',true,'status','PENDING','rejectionReason','');
q=repmat(empty,size(values,1),1);
for i=1:numel(q),q(i).candidateId=i;q(i).dataIndex=i;q(i).measurementTimeSec=values(i,1);q(i).cfoCandidateBins=values(i,2);end
end
