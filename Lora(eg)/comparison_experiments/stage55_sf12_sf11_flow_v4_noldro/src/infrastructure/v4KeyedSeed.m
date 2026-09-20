function seed=v4KeyedSeed(rootSeed,key)
%V4KEYEDSEED Map a complete canonical key to a call-order-independent seed.
arguments
    rootSeed (1,1) double {mustBeInteger,mustBeNonnegative}
    key (1,1) struct
end
payload=struct('generator','mt19937ar-keyed-sha256-v1', ...
    'rootSeed',rootSeed,'key',key);
hash=v4Sha256(v4CanonicalJson(payload));
seed=hex2dec(hash(1:8));
end
