function tests = testStrictPaperReproduction
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
strictPaperSetup();testCase.TestData.config=strictPaperConfig();
end

function testLiteralParameters(testCase)
c=testCase.TestData.config;
verifyEqual(testCase,c.bandwidthHz,62600);
verifyEqual(testCase,c.orbitHeightM,400000);
verifyEqual(testCase,c.carrierFrequencyHz,2.1e9);
verifyEqual(testCase,c.packetSymbolCount,51);
verifyEqual(testCase,c.sf,12);verifyEqual(testCase,c.zeroPaddingFactor,4);
verifyEqual(testCase,c.centroidSampleCount,10);
end

function testIQBatchIndependence(testCase)
c=testCase.TestData.config;symbols=[zeros(8,2);(1:4).' (4092:4095).'];
batch=strictPaperGenerateIQ(symbols,-27,-15,[301 302],c);
separate=[strictPaperGenerateIQ(symbols(:,1),-27,-15,301,c); ...
    strictPaperGenerateIQ(symbols(:,2),-27,-15,302,c)];
verifyEqual(testCase,batch,separate,'AbsTol',0);
end

function testActualNoiseAndUnitPower(testCase)
c=testCase.TestData.config;c.carrierFrequencyHz=0;
symbols=[0;17;4095];clean=strictPaperGenerateIQ(symbols,0,Inf,400,c);
noisy=strictPaperGenerateIQ(symbols,0,-10,400,c);
verifyEqual(testCase,mean(abs(clean(:)).^2),1,'AbsTol',1e-12);
verifyEqual(testCase,mean(abs(noisy(:)-clean(:)).^2),10,'RelTol',0.06);
estimate=dreEstimatePaperCentroids10(clean,c);
verifyEqual(testCase,numel(estimate.offsets),10);
verifyEqual(testCase,mod(round(estimate.rawBins),4096),symbols);
end

function testCausalOLSAndPaperFixedRule(testCase)
c=testCase.TestData.config;c.preambleSymbolCount=8;
symbols=[zeros(8,1);12;500;4095;0;20;21];
position=(0:numel(symbols)-1).';raw=mod(symbols+3.2+0.21*position,4096);
for mode={'fixed','adaptive'}
    decoded=dreDecodeLinearRegressionBatch(raw,8,4096,mode{1});
    verifyEqual(testCase,decoded.detectedSymbols,symbols(9:end));
    changed=raw;changed(end)=mod(changed(end)+13,4096);
    other=dreDecodeLinearRegressionBatch(changed,8,4096,mode{1});
    verifyEqual(testCase,other.detectedSymbols(1:end-1),decoded.detectedSymbols(1:end-1));
    verifyFalse(testCase,decoded.usesPayloadTruth);
end
end

function testCRCFilteredCountingAndTruthIsolation(testCase)
c=testCase.TestData.config;
for cr=[1 4]
    stream=RandStream('mt19937ar','Seed',500+cr);
    payload=dreGenerateFullPhyPayload(3,cr,c,stream);
    detected=payload.logicalBins;
    good=strictPaperScorePayload(detected,payload,cr,c);
    verifyEqual(testCase,good.acceptedPackets,3);
    verifyEqual(testCase,good.packetLosses,0);
    verifyEqual(testCase,good.codedErrorsAccepted,0);
    detected(:,1)=mod(detected(:,1)+733,c.samplesPerSymbol);
    scored=strictPaperScorePayload(detected,payload,cr,c);
    verifyFalse(testCase,scored.crcPass(1));
    verifyEqual(testCase,scored.acceptedPackets,2);
    verifyEqual(testCase,scored.codedBitsAccepted,2*c.sf*(4+cr)*c.hammingBlockCount);
    verifyEqual(testCase,scored.codedErrorsAccepted,0);
    altered=payload;altered.payloadBits=~payload.payloadBits;altered.codedBits=~payload.codedBits;
    rescored=strictPaperScorePayload(detected,altered,cr,c);
    verifyEqual(testCase,rescored.crcPass,scored.crcPass);
    verifyEqual(testCase,rescored.decodedPayloadBits,scored.decodedPayloadBits);
end
end

function testCacheIdentityIncludesBandwidthAndSource(testCase)
c=testCase.TestData.config;
a=strictPaperIdentity(c,'run_strict_full_phy.m');
verifyTrue(testCase,all(strlength(a.sourceHashes(:,2))==64));
changed=c;changed.bandwidthHz=62500;
b=strictPaperIdentity(changed,'run_strict_full_phy.m');
verifyNotEqual(testCase,dreConfigurationSignature(a),dreConfigurationSignature(b));
end

function testAcceleratedCentroidsMatchReference(testCase)
c=testCase.TestData.config;
symbols=[zeros(8,3);(0:11).' (4084:4095).' (100:111).'];
for snr=[Inf -10 -20]
    rx=strictPaperGenerateIQ(symbols,-18,snr,[601 602 603],c);
    reference=dreEstimatePaperCentroids10(rx,c);
    accelerated=strictPaperCentroids(rx,c);
    verifyEqual(testCase,accelerated.rawBins,reference.rawBins,'AbsTol',1e-10);
    verifyEqual(testCase,accelerated.peakBins,reference.peakBins);
end
end

function testAcceleratedPhyMatchesReference(testCase)
c=testCase.TestData.config;
for cr=[1 4]
    stream=RandStream('mt19937ar','Seed',700+cr);
    payload=dreGenerateFullPhyPayload(8,cr,c,stream);
    detected=payload.logicalBins;
    detected(1:5,1:4)=mod(detected(1:5,1:4)+[1;2;3;733;4095],4096);
    reference=dreDecodeFullPhyPayload(detected,payload,cr,c);
    accelerated=strictPaperDecodePayload(detected,cr,c);
    verifyEqual(testCase,accelerated.payloadBits,reference.payloadBits);
    verifyEqual(testCase,accelerated.crcPass,reference.crcPass);
    verifyEqual(testCase,accelerated.receivedCodedBits,reference.receivedCodedBits);
    scored=strictPaperScorePayload(detected,payload,cr,c);
    verifyEqual(testCase,scored.codedErrorsAccepted,reference.acceptedCodedErrors);
    verifyEqual(testCase,scored.codedErrorsAll,reference.totalCodedErrors);
end
end

function testNativeDirectIQMatchesReference(testCase)
c=testCase.TestData.config;
symbols=[zeros(8,3);(0:11).' (4084:4095).' (100:111).'];
for snr=[Inf -10 -20]
    referenceIQ=strictPaperGenerateIQ(symbols,-18,snr,[801 802 803],c);
    reference=dreEstimatePaperCentroids10(referenceIQ,c);
    [raw,iq]=strictPaperRawBatch(symbols,-18,snr,[801 802 803],c);
    verifyEqual(testCase,iq,referenceIQ,'AbsTol',1e-10);
    verifyEqual(testCase,raw(:),reference.rawBins,'AbsTol',1e-8);
    for mode={'fixed','adaptive'}
        a=dreDecodeLinearRegressionBatch(raw,8,4096,mode{1});
        b=dreDecodeLinearRegressionBatch(reshape(reference.rawBins,size(symbols)), ...
            8,4096,mode{1});
        verifyEqual(testCase,a.detectedSymbols,b.detectedSymbols);
    end
end
end
