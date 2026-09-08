function ledger = v3RandomLedger(config,scope,snrIndex,passIndex,frameIndex)
%V3RANDOMLEDGER Disjoint payload/noise/channel seeds by experiment identity.

arguments
    config (1,1) struct
    scope (1,:) char {mustBeMember(scope,{'mechanism','validation','formal'})}
    snrIndex (1,1) double {mustBeInteger,mustBePositive}
    passIndex (1,1) double {mustBeInteger,mustBePositive}
    frameIndex (1,1) double {mustBeInteger,mustBePositive}
end
if snrIndex > 10 || passIndex > 20 || frameIndex > 4000
    error('V3:LedgerIndex','Ledger index exceeds the preregistered domain.');
end
offset = (snrIndex-1)*80000+(passIndex-1)*4000+frameIndex;
ledger = struct('payloadSeed',config.seeds.([scope 'PayloadBase'])+offset, ...
    'noiseSeed',config.seeds.([scope 'NoiseBase'])+offset, ...
    'channelSeed',config.seeds.([scope 'ChannelBase'])+offset, ...
    'scope',scope,'snrIndex',snrIndex,'passIndex',passIndex, ...
    'frameIndex',frameIndex);
end

