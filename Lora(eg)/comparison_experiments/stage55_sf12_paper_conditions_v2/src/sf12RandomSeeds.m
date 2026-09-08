function seeds = sf12RandomSeeds(cfg,domain,caseName,snrIndex,packetIndex)
%SF12RANDOMSEEDS Method-independent paired random ledger.

domain = string(domain);
switch domain
    case "calibration"
        payloadBase = cfg.seeds.calibrationPayloadBase;
        noiseBase = cfg.seeds.calibrationNoiseBase;
    case "validation"
        payloadBase = cfg.seeds.validationPayloadBase;
        noiseBase = cfg.seeds.validationNoiseBase;
    case "formal"
        payloadBase = cfg.seeds.formalPayloadBase;
        noiseBase = cfg.seeds.formalNoiseBase;
    otherwise
        error('Sf12:SeedDomain','Unknown seed domain: %s',domain);
end
caseIndex = find(["case1","case2"] == string(caseName),1);
if isempty(caseIndex)
    error('Sf12:Case','Unknown case: %s',caseName);
end
offset = (caseIndex-1)*1e6+(snrIndex-1)*5e4+packetIndex;
seeds.domain = domain;
seeds.payloadSeed = double(payloadBase+offset);
seeds.noiseSeed = double(noiseBase+offset);
seeds.channelSeed = seeds.noiseSeed;
seeds.caseIndex = caseIndex;
seeds.snrIndex = snrIndex;
seeds.packetIndex = packetIndex;
end
