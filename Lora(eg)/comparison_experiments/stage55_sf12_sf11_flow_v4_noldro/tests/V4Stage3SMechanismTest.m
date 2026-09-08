classdef V4Stage3SMechanismTest < matlab.unittest.TestCase
    methods (Test)
        function pointTimingAndNoVpCount(testCase)
            [q,c,p]=localPacket(0,Inf,1);row=q.schedule.dataRows(1)-1;
            r=v4TrackAStage55PointAnchoredDecode(q,c,p,StopAfterPhysicalRow=row);
            testCase.verifyEqual(r.pointAnchor.measurementTimeSec,9.5*c.symbolDurationSec,'AbsTol',1e-12);
            testCase.verifyEqual(r.pointAnchor.availableAtSec,10*c.symbolDurationSec,'AbsTol',1e-12);
            testCase.verifyEqual(r.committedVpCount,0);testCase.verifyEqual(r.checkpointState.rateBinsPerSec,0);
        end
        function case0D1ProvisionalKeepsD2Correct(testCase)
            [q,c,p]=localPacket(0,Inf,2);r=v4TrackAStage55PointAnchoredDecode(q,c,p);
            testCase.verifyEqual(r.detectedPhysicalBins(1:2),q.truth.labels(1:2));
            testCase.verifyTrue(all(r.virtualPilotAccepted(1:2)));
            testCase.verifyEqual(r.finalLockState,'LOCKED');
            testCase.verifyNotEqual(r.provisionalRateBinsPerSec,0);
        end
        function d1FailureLosesWithoutLateStart(testCase)
            [q,c,p]=localPacket(0,Inf,3);q=localZeroData(q,1);
            r=v4TrackAStage55PointAnchoredDecode(q,c,p);
            testCase.verifyEqual(r.finalLockState,'LOST');testCase.verifyEqual(r.lossReason,'d1-startup-gate');
            testCase.verifyEqual(r.committedVpCount,0);
        end
        function d2FailureKeepsD1ButStops(testCase)
            [q,c,p]=localPacket(0,Inf,4);q=localZeroData(q,2);
            r=v4TrackAStage55PointAnchoredDecode(q,c,p);
            testCase.verifyEqual(r.finalLockState,'LOST');testCase.verifyEqual(r.lossReason,'d2-confirmation-gate');
            testCase.verifyTrue(r.virtualPilotAccepted(1));testCase.verifyFalse(any(r.virtualPilotAccepted(2:end)));
        end
        function d1OnlyAffectsLaterSlot(testCase)
            [q,c,p]=localPacket(0,Inf,5);row=q.schedule.dataRows(1);
            r=v4TrackAStage55PointAnchoredDecode(q,c,p,StopAfterPhysicalRow=row);
            testCase.verifyTrue(r.virtualPilotAccepted(1));
            testCase.verifyGreaterThanOrEqual(r.firstEffectiveTimeSec(1),r.releaseAtSec(1));
            testCase.verifyGreaterThan(r.pilotAppliedAtPhysicalRow(1),row);
        end
        function processingDelayMovesFirstEffect(testCase)
            [q,c,p]=localPacket(0,Inf,6);
            a=v4TrackAStage55PointAnchoredDecode(q,c,p,ProcessingDelaySec=0);
            b=v4TrackAStage55PointAnchoredDecode(q,c,p,ProcessingDelaySec=1.2*c.symbolDurationSec);
            testCase.verifyGreaterThan(b.pilotAppliedAtPhysicalRow(1),a.pilotAppliedAtPhysicalRow(1));
        end
        function prefixIsIndependentOfFuture(testCase)
            [a,c,p]=localPacket(-366,-21,7);b=a;row=a.schedule.dataRows(5);first=a.schedule.startSample(row)+1;
            b.rx(first:end)=-b.rx(first:end);ra=v4TrackAStage55PointAnchoredDecode(a,c,p);rb=v4TrackAStage55PointAnchoredDecode(b,c,p);
            testCase.verifyEqual(ra.detectedPhysicalBins(1:4),rb.detectedPhysicalBins(1:4));
            testCase.verifyEqual(ra.virtualPilotAccepted(1:4),rb.virtualPilotAccepted(1:4));
            testCase.verifyEqual(ra.lockStateByData(1:4),rb.lockStateByData(1:4));
        end
        function checkpointResumeMatches(testCase)
            [q,c,p]=localPacket(0,-21,8);stop=q.schedule.dataRows(1);
            partial=v4TrackAStage55PointAnchoredDecode(q,c,p,StopAfterPhysicalRow=stop);
            resumed=v4TrackAStage55PointAnchoredDecode(q,c,p,ResumeState=partial.checkpointState);
            one=v4TrackAStage55PointAnchoredDecode(q,c,p);
            testCase.verifyEqual(resumed.detectedPhysicalBins,one.detectedPhysicalBins);
            testCase.verifyEqual(resumed.virtualPilotAccepted,one.virtualPilotAccepted);
            testCase.verifyEqual(resumed.finalLockState,one.finalLockState);
        end
        function wrongD1IsCountedByOuterScorer(testCase)
            [q,c,p]=localPacket(0,Inf,9);row=q.schedule.dataRows(1);first=q.schedule.startSample(row)+1;
            n=(0:c.samplesPerSymbol-1).';q.rx(first:first+c.samplesPerSymbol-1)= ...
                q.rx(first:first+c.samplesPerSymbol-1).*exp(1i*2*pi*n/c.samplesPerSymbol);
            r=v4TrackAStage55PointAnchoredDecode(q,c,p);m=v4EvaluateTrackAPacket(r,q.truth,c);
            expected=sum(r.virtualPilotAccepted&r.vpUsedLabel~=q.truth.labels);
            testCase.verifyEqual(m.vpFalseAccepted,expected);
            testCase.verifyGreaterThanOrEqual(expected,1);
        end
        function noForbiddenReceiverInputsAndOldEvidenceStable(testCase)
            root=v4SetupPaths();text=fileread(fullfile(root,'src','paper_anchor','v4TrackAStage55PointAnchoredDecode.m'));
            testCase.verifyFalse(contains(text,'packet.truth'));testCase.verifyFalse(contains(text,'v4DecodePayload'));
            for name={'r3_failure_evidence_manifest.json','r4_failure_evidence_manifest.json'}
                m=jsondecode(fileread(fullfile(root,'config',name{1})));
                for i=1:numel(m.files),testCase.verifyEqual(v4Sha256(fullfile(root,m.files(i).path)),m.files(i).sha256);end
            end
        end
    end
end
function [q,c,p]=localPacket(caseTime,snr,id)
root=v4SetupPaths();[list,~]=v4Stage3SCandidateTable(root,1);p=list(1);c=sf12NoLdroSf11FlowConfig();
q=v4GenerateTrackAPacket(c,caseTime,snr,id,710000000);
end
function q=localZeroData(q,index)
row=q.schedule.dataRows(index);first=q.schedule.startSample(row)+1;q.rx(first:first+4095)=0;
end
