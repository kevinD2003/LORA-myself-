function runAcShard(shard,workers,cohort)
%RUNACSHARD Deterministic disjoint sharding with per-point checkpoints.
arguments
    shard (1,1) double {mustBeInteger,mustBePositive}
    workers (1,1) double {mustBeInteger,mustBePositive}=4
    cohort (1,1) string="validation100"
end
assert(shard<=workers);maxNumCompThreads(1);acSetup();
for index=shard:workers:100,runAcPoint(index,cohort);end
fprintf('ALL_CURVES_SHARD_COMPLETE %s %d/%d\n',cohort,shard,workers);
end
