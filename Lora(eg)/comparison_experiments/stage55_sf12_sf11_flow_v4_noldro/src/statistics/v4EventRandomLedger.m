function ledger=v4EventRandomLedger(rootSeed,key)
%V4EVENTRANDOMLEDGER Complete-key payload/noise/channel seed ledger.
arguments
    rootSeed (1,1) double {mustBeInteger,mustBeNonnegative}
    key (1,1) struct
end
required={'planVersion','phase','track','channel','comparisonMode', ...
    'snrDb','replicateId','packetId','eventType','eventIndex','sampleIndex'};
for i=1:numel(required)
    if ~isfield(key,required{i})
        error('V4:SeedKey','Missing seed key field %s.',required{i});
    end
end
components={'payload','noise','channel'};
seeds=zeros(1,numel(components));
for i=1:numel(components)
    item=key;
    item.component=components{i};
    seeds(i)=v4KeyedSeed(rootSeed,item);
end
ledger=struct('payloadSeed',seeds(1),'noiseSeed',seeds(2), ...
    'channelSeed',seeds(3),'rootSeed',rootSeed,'key',key, ...
    'ledgerHash',v4Sha256(v4CanonicalJson(struct( ...
    'rootSeed',rootSeed,'key',key,'seeds',seeds))));
end
