function tests = testLossForensicsV6
tests=functiontests(localfunctions);
end
function setupOnce(testCase)
folder=fileparts(mfilename('fullpath'));addpath(folder,fullfile(fileparts(folder),'reference_phy_v6'));
setupReferencePhyV6;testCase.TestData.config=referencePhyV6Config();
end
function testCleanPartitionsAndHistogram(testCase)
c=testCase.TestData.config;
for cr=[1 4]
    tx=referencePhyV6Encode(uint8(repmat((0:31).',1,3)),cr,c);
    d=summarizePacketLossV6(tx.logicalBins,tx,cr,c);
    verifyEqual(testCase,d.stats.acceptedPackets,3);verifyEqual(testCase,d.stats.rejectedPackets,0);
    verifyEqual(testCase,d.wordErrorHistogram,[3*tx.layout.totalNibbles;zeros(8,1)]);
    verifyEqual(testCase,d.stats.acceptedWithWrongPayloadPackets,0);
    verifyEqual(testCase,d.stats.symbolErrors,0);verifyFalse(testCase,d.receiverUsesPayloadTruth);
end
end
function testHeaderAndPayloadLossPartitions(testCase)
c=testCase.TestData.config;tx=referencePhyV6Encode(uint8(repmat((0:31).',1,3)),4,c);
bad=tx.logicalBins;bad(1:8,1)=mod(bad(1:8,1)+733,4096);
bad(9:end,2)=mod(bad(9:end,2)+733,4096);
d=summarizePacketLossV6(bad,tx,4,c);
verifyEqual(testCase,d.stats.headerRejectedPackets,1);
verifyEqual(testCase,d.stats.crcRejectedValidHeaderPackets,1);
verifyEqual(testCase,d.stats.acceptedPackets,1);
verifyEqual(testCase,d.stats.rejectedPackets,2);
verifyEqual(testCase,d.stats.rejectedWithoutDecodedNibbleErrorPackets,0);
verifyEqual(testCase,sum((0:8).'.*d.wordErrorHistogram),d.score.codedErrorsAll);
end
function testPaddingExcluded(testCase)
c=testCase.TestData.config;tx=referencePhyV6Encode(uint8((0:31).'),4,c);
altered=tx;altered.codedWords(tx.layout.totalNibbles+1:end)=255;
a=summarizePacketLossV6(tx.logicalBins,tx,4,c);
b=summarizePacketLossV6(tx.logicalBins,altered,4,c);
verifyEqual(testCase,b.wordErrorHistogram,a.wordErrorHistogram);
verifyEqual(testCase,b.score.codedErrorsAll,a.score.codedErrorsAll);
verifyEqual(testCase,b.crcPass,a.crcPass);
end
function testGoldCannotChangeReceiverOutcomes(testCase)
c=testCase.TestData.config;tx=referencePhyV6Encode(uint8(repmat((0:31).',1,2)),1,c);
bad=tx.logicalBins;bad(:,1)=mod(bad(:,1)+733,4096);
altered=tx;altered.codedWords=bitxor(tx.codedWords,uint8(1));
altered.nibbles=bitxor(tx.nibbles,uint8(1));altered.payloadBytes=bitxor(tx.payloadBytes,uint8(255));
a=summarizePacketLossV6(bad,tx,1,c);b=summarizePacketLossV6(bad,altered,1,c);
verifyEqual(testCase,b.crcPass,a.crcPass);verifyEqual(testCase,b.headerValid,a.headerValid);
verifyEqual(testCase,b.stats.acceptedPackets,a.stats.acceptedPackets);
verifyEqual(testCase,b.stats.rejectedPackets,a.stats.rejectedPackets);
end
function testRejectEmptyOrDuplicateConditionList(testCase)
verifyError(testCase,@()run_loss_forensics_v6('unused.mat',ConditionIndices=[]),'LossForensics:Conditions');
verifyError(testCase,@()run_loss_forensics_v6('unused.mat',ConditionIndices=[1;1]),'LossForensics:Conditions');
end
