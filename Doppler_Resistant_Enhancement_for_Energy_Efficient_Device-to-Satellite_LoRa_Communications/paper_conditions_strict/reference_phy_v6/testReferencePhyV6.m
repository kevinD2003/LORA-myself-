function tests = testReferencePhyV6
tests=functiontests(localfunctions);
end
function setupOnce(testCase)
folder=setupReferencePhyV6();testCase.TestData.config=referencePhyV6Config();
testCase.TestData.fixtures=jsondecode(fileread(fullfile(folder,'tests','reference_vectors.json')));
end
function testReferenceWhiteningAndCrc(testCase)
ref=testCase.TestData.fixtures;
verifyEqual(testCase,referencePhyV6Whitening(255),uint8(ref.whitening(:)));
for i=1:numel(ref.fixtures)
    f=ref.fixtures(i);verifyEqual(testCase,referencePhyV6Crc(uint8(f.payload(:))),uint16(f.crc));
end
end
function testExhaustiveReferenceHardDecoder(testCase)
ref=testCase.TestData.fixtures;
verifyEqual(testCase,referencePhyV6Hamming(uint8((0:31).'),1,'decode'),uint8(ref.decode1(:)));
verifyEqual(testCase,referencePhyV6Hamming(uint8((0:255).'),4,'decode'),uint8(ref.decode4(:)));
for nibble=0:15
    word=referencePhyV6Hamming(uint8(nibble),4,'encode');
    for bit=1:8
        verifyEqual(testCase,referencePhyV6Hamming(bitxor(word,uint8(2^(bit-1))),4,'decode'),uint8(nibble));
    end
end
end
function testReferenceFramesAndNoiselessRoundTrip(testCase)
ref=testCase.TestData.fixtures;
for i=1:numel(ref.fixtures)
    f=ref.fixtures(i);c=testCase.TestData.config;
    c.payloadBytes=numel(f.payload);c.sf=f.sf;c.explicitHeader=f.explicit;
    c.ldroMode='off';if f.ldro,c.ldroMode='on';end
    tx=referencePhyV6Encode(uint8(f.payload(:)),f.cr,c);
    verifyEqual(testCase,tx.nibbles,uint8(f.nibbles(:)));
    verifyEqual(testCase,tx.codedWords,uint8(f.words(:)));
    verifyEqual(testCase,tx.logicalBins,double(f.symbols(:)));
    rx=referencePhyV6Decode(tx.logicalBins,f.cr,c);
    verifyEqual(testCase,rx.payloadBytes,uint8(f.payload(:)));
    verifyTrue(testCase,rx.crcPass);verifyTrue(testCase,rx.headerValid);
    verifyFalse(testCase,rx.usesPayloadTruth);
end
end
function testAutoLdroAndOnAirTiming(testCase)
c=testCase.TestData.config;l=referencePhyV6Layout(1,c);
verifyTrue(testCase,l.ldro);verifyEqual(testCase,l.widths(1),8);
verifyEqual(testCase,l.rows(1),10);verifyEqual(testCase,l.onAirSymbols,55.25);
verifyEqual(testCase,l.symbolCount,43);verifyEqual(testCase,l.codedBitsPerPacket,395);
verifyEqual(testCase,l.observationIndices(11),12.25);
l4=referencePhyV6Layout(4,c);verifyEqual(testCase,l4.onAirSymbols,76.25);
verifyEqual(testCase,l4.codedBitsPerPacket,584);
end
function testClockAwareCausalOLSAndV5Equivalence(testCase)
c=testCase.TestData.config;l=referencePhyV6Layout(4,c);x=l.observationIndices;
data=mod((0:numel(x)-1).'*79,4096);data(1:8)=0;
raw=mod(data+3.2+0.21*x,4096);
for mode={'fixed','adaptive'}
    rx=referencePhyV6LR(raw,x,8,4096,mode{1});
    verifyEqual(testCase,rx.detectedSymbols,data(9:end));
    changed=raw;changed(end)=mod(changed(end)+33,4096);
    other=referencePhyV6LR(changed,x,8,4096,mode{1});
    verifyEqual(testCase,rx.detectedSymbols(1:end-1),other.detectedSymbols(1:end-1));
    xUniform=(0:numel(x)-1).';
    uniform=mod(data+3.2+0.21*xUniform,4096);
    a=referencePhyV6LR(uniform,xUniform,8,4096,mode{1});
    b=dreDecodeLinearRegressionBatch(uniform,8,4096,mode{1});
    verifyEqual(testCase,a.detectedSymbols,b.detectedSymbols);
    verifyEqual(testCase,a.observedErrorBins,b.observedErrorBins,'AbsTol',1e-10);
end
end
function testRawSamplesCentroidsAndSeedIndependence(testCase)
c=testCase.TestData.config;l=referencePhyV6Layout(1,c);
tx=referencePhyV6Encode(uint8(repmat((0:31).',1,2)),1,c);
[raw,iq]=referencePhyV6Raw(tx.observedSymbols,l,-24,-10,[404 405],c);
ref=dreEstimatePaperCentroids10(iq,c);
verifyEqual(testCase,raw(:),ref.rawBins,'AbsTol',1e-8);
separate=[referencePhyV6Raw(tx.observedSymbols(:,1),l,-24,-10,404,c) ...
    referencePhyV6Raw(tx.observedSymbols(:,2),l,-24,-10,405,c)];
verifyEqual(testCase,raw,separate,'AbsTol',0);
[clean,cleanIQ]=referencePhyV6Raw(tx.observedSymbols,l,-24,Inf,[404 405],c); %#ok<ASGLU>
verifyEqual(testCase,mean(abs(cleanIQ(:)).^2),1,'AbsTol',1e-12);
verifyEqual(testCase,mean(abs(iq(:)-cleanIQ(:)).^2),10,'RelTol',0.03);
end
function testCrcIndependentOfGoldAndPaddingExcluded(testCase)
c=testCase.TestData.config;tx=referencePhyV6Encode(uint8(repmat((0:31).',1,3)),4,c);
good=referencePhyV6Score(tx.logicalBins,tx,4,c);
verifyEqual(testCase,good.packetLosses,0);verifyEqual(testCase,good.codedBitsAccepted,3*584);
changed=tx.logicalBins;changed(:,1)=mod(changed(:,1)+733,4096);
scored=referencePhyV6Score(changed,tx,4,c);
altered=tx;altered.codedWords=bitxor(tx.codedWords,uint8(255));altered.payloadBytes=bitxor(tx.payloadBytes,uint8(255));
other=referencePhyV6Score(changed,altered,4,c);
verifyEqual(testCase,other.crcPass,scored.crcPass);
verifyEqual(testCase,other.decodedPayloadBytes,scored.decodedPayloadBytes);
verifyFalse(testCase,scored.crcPass(1));
end
function testProtectedHeaderCorruptionIsLost(testCase)
c=testCase.TestData.config;tx=referencePhyV6Encode(uint8((0:31).'),1,c);
bad=tx.logicalBins;bad(1:8)=mod(bad(1:8)+733,4096);
rx=referencePhyV6Decode(bad,1,c);
verifyFalse(testCase,rx.headerValid);verifyFalse(testCase,rx.crcPass);
end
function testFrozenV5AndNewIdentity(testCase)
c=testCase.TestData.config;a=referencePhyV6Identity(c);
verifyTrue(testCase,all(strlength(a.sourceHashes(:,2))==64));
c.explicitHeader=false;b=referencePhyV6Identity(c);
verifyNotEqual(testCase,dreConfigurationSignature(a),dreConfigurationSignature(b));
end
function testAuditRequiresAResultDirectory(testCase)
verifyError(testCase,@()audit_reference_phy_v6(),'ReferencePhyV6:AuditPaths');
end
