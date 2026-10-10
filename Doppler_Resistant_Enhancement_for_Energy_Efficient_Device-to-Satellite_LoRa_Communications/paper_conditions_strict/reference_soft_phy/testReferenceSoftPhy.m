function tests = testReferenceSoftPhy
tests=functiontests(localfunctions);
end
function setupOnce(testCase)
folder=setupReferenceSoftPhy;testCase.TestData.config=referencePhyV6Config;
testCase.TestData.fixtures=jsondecode(fileread(fullfile(folder,'tests','reference_soft_vectors.json')));
end
function testLiteralReferenceSoftTablesAndTies(testCase)
fixtures=testCase.TestData.fixtures.hamming;
for i=1:numel(fixtures)
    f=fixtures(i);verifyEqual(testCase,referenceSoftHamming(f.llr(:),f.cr),uint8(f.nibble));
end
end
function testReferenceLikelihoodLoopsAndClipping(testCase)
fixtures=testCase.TestData.fixtures.powers;
for i=1:numel(fixtures)
    f=fixtures(i);[llr,clipped]=referenceSoftLlr(f.power(:),f.reduced);
    verifyEqual(testCase,llr,double(f.llr(:)),'AbsTol',1e-10);
    verifyEqual(testCase,clipped,f.clipped);
end
end
function testSoftCanResolveWeakBitErrorsWithoutCrc(testCase)
verifyEqual(testCase,referenceSoftHamming([0.1;0.1;-5;-5;-5;-5;-5;-5],4),uint8(0));
verifyEqual(testCase,referencePhyV6Hamming(uint8(192),4,'decode'),uint8(3));
verifyEqual(testCase,referenceSoftHamming([0.1;-5;-5;-5;-5],1),uint8(0));
verifyEqual(testCase,referencePhyV6Hamming(uint8(16),1,'decode'),uint8(1));
end
function testPredictionsAreExactAndCausal(testCase)
c=testCase.TestData.config;l=referencePhyV6Layout(4,c);x=l.observationIndices;
symbols=mod((0:numel(x)-1).'*79,4096);symbols(1:8)=0;
raw=mod(symbols+3.2+0.21*x,4096);
for mode={'fixed','adaptive'}
    [p,a]=referenceSoftPredictions(raw,x,c,mode{1});
    b=referencePhyV6LR(raw,x,8,4096,mode{1});
    verifyEqual(testCase,a,b);verifyEqual(testCase,p(9:end),3.2+0.21*x(9:end),'AbsTol',1e-10);
    changed=raw;changed(end)=mod(changed(end)+733,4096);
    [other,next]=referenceSoftPredictions(changed,x,c,mode{1});
    verifyEqual(testCase,other(9:end),p(9:end),'AbsTol',0);
    verifyEqual(testCase,next.detectedSymbols(1:end-1),a.detectedSymbols(1:end-1));
end
end
function testNoiselessPhysicalFramesAndReducedRateModes(testCase)
c=testCase.TestData.config;c.sf=7;c.samplesPerSymbol=128;c.symbolDurationSec=128/c.sampleRateHz;
payload=uint8(repmat((0:31).',1,2));
for cr=[1 4]
    for reduced={'on','off'}
        c.ldroMode=reduced{1};tx=referencePhyV6Encode(payload,cr,c);l=tx.layout;
        frequency=3.25+0.13*l.observationIndices;
        raw=mod(tx.observedSymbols+frequency,128);
        [p,~]=referenceSoftPredictions(raw,l.observationIndices,c,'adaptive');
        iq=dreModulateSymbols(tx.observedSymbols(:),c).* ...
            exp(1i*2*pi*repmat(frequency,2,1)*(0:127)/128);
        for window={'reference-rectangular','paper-hann'}
            rx=referenceSoftDecode(iq,p,cr,c,window{1});
            verifyTrue(testCase,all(rx.crcPass));verifyTrue(testCase,all(rx.headerValid));
            verifyEqual(testCase,rx.payloadBytes,payload);verifyEqual(testCase,rx.decodedNibbles,tx.nibbles);
            verifyFalse(testCase,rx.usesPayloadTruth);verifyFalse(testCase,rx.softFeedbackIntoLR);
        end
    end
end
end
function testHeaderAndCrcParserMatchesV6(testCase)
c=testCase.TestData.config;
for cr=[1 4]
    tx=referencePhyV6Encode(uint8(repmat((0:31).',1,3)),cr,c);
    decisions=tx.logicalBins;decisions(1:8,1)=mod(decisions(1:8,1)+733,4096);
    decisions(9:end,2)=mod(decisions(9:end,2)+733,4096);
    hard=referencePhyV6Decode(decisions,cr,c);data=zeros(size(hard.receivedCodedWords),'uint8');
    for block=1:numel(tx.layout.rows)
        wi=tx.layout.wordStarts(block)+(0:tx.layout.rows(block)-1);
        data(wi,:)=referencePhyV6Hamming(hard.receivedCodedWords(wi,:),tx.layout.rates(block),'decode');
    end
    parsed=referenceSoftBytes(data,hard.receivedCodedWords,cr,c);
    verifyEqual(testCase,parsed,hard);
end
end
function testPrimaryBitStreamAndGoldIsolation(testCase)
c=testCase.TestData.config;tx=referencePhyV6Encode(uint8(repmat((0:31).',1,3)),4,c);
hard=referencePhyV6Score(tx.logicalBins,tx,4,c);
rx=referencePhyV6Decode(tx.logicalBins,4,c);rx.crcPass=[true false true];
hard.perPacketCodedErrorsAll=[3 7 9];
score=referenceSoftScore(rx,hard,tx);
verifyEqual(testCase,score.codedErrorsAccepted,12);verifyEqual(testCase,score.codedErrorsAll,19);
verifyEqual(testCase,score.codedBitsAccepted,2*584);verifyEqual(testCase,score.packetLosses,1);
altered=tx;altered.codedWords=bitxor(tx.codedWords,uint8(255));
altered.payloadBytes=bitxor(tx.payloadBytes,uint8(255));other=referenceSoftScore(rx,hard,altered);
verifyEqual(testCase,other.crcPass,score.crcPass);verifyEqual(testCase,other.packetLosses,score.packetLosses);
verifyEqual(testCase,other.codedErrorsAccepted,score.codedErrorsAccepted);
end
function testZeroEnergyDoesNotBecomeAValidPacket(testCase)
c=testCase.TestData.config;l=referencePhyV6Layout(1,c);
iq=complex(zeros(numel(l.observationIndices),4096));p=zeros(numel(l.observationIndices),1);
rx=referenceSoftDecode(iq,p,1,c);verifyFalse(testCase,rx.crcPass);verifyFalse(testCase,rx.headerValid);
end
function testInvalidReceiverInputs(testCase)
verifyError(testCase,@()referenceSoftHamming(zeros(7,1),4),'ReferenceSoft:LLR');
verifyError(testCase,@()referenceSoftLlr(-ones(128,1),true),'ReferenceSoft:Power');
end
function testRunnerRejectsEmptyAndDuplicateSelections(testCase)
verifyError(testCase,@()run_reference_soft_phy('unused.mat',ConditionIndices=[]),'ReferenceSoft:Conditions');
verifyError(testCase,@()run_reference_soft_phy('unused.mat',ConditionIndices=[1;1]),'ReferenceSoft:Conditions');
end
function testAuditRequiresResultPaths(testCase)
verifyError(testCase,@()audit_reference_soft_phy(),'ReferenceSoft:AuditPaths');
end
function testScoreRejectsBroadcastableColumnMask(testCase)
c=testCase.TestData.config;tx=referencePhyV6Encode(uint8(repmat((0:31).',1,2)),1,c);
hard=referencePhyV6Score(tx.logicalBins,tx,1,c);rx=referencePhyV6Decode(tx.logicalBins,1,c);
rx.crcPass=rx.crcPass.';
verifyError(testCase,@()referenceSoftScore(rx,hard,tx),'ReferenceSoft:Score');
end
function testHannIntegerGridEqualsPaperFourfoldFft(testCase)
n=128;k=(0:n-1).';signal=exp(1i*2*pi*(51.31*k/n+0.07*(k/n).^2));
window=0.5-0.5*cos(2*pi*k/n);
ordinary=fft(signal.*window,n);paper=fft(signal.*window,4*n);
verifyEqual(testCase,ordinary,paper(1:4:end),'AbsTol',1e-9);
end
function testReferenceFFTNormalizationBranches(testCase)
% Closed-form arguments independent of the fixture generator: Ps=7/128,
% Pn=1, normalized peak=5*128, giving sqrt(35), not sqrt(35/128).
power=ones(128,1);power(64)=5;
[llr,clipped]=referenceSoftLlr(power,true);
expected=log(besseli(0,sqrt(35),1))+sqrt(35)- ...
    log(besseli(0,sqrt(7),1))-sqrt(7);
verifyFalse(testCase,clipped);verifyEqual(testCase,abs(llr),repmat(expected,5,1),'AbsTol',1e-12);
% A second spectrum must cross the pinned 713 cutoff ONLY after scaling.
power(64)=1000;[llr,clipped]=referenceSoftLlr(power,true);
verifyTrue(testCase,clipped);
verifyEqual(testCase,llr,[-1;1;-1;-1;-1]*(128*999));
end
