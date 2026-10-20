function nkserRunShard(shard,workers,cohort)
%NKSERRUNSHARD Deterministic disjoint four-way point sharding.
arguments
    shard (1,1) double {mustBeInteger,mustBePositive}
    workers (1,1) double {mustBeInteger,mustBePositive}=4
    cohort (1,1) string {mustBeMember(cohort,["gate100","formal1000"])}="gate100"
end
assert(shard<=workers);maxNumCompThreads(1);nkserSetup();
if cohort=="gate100",indices=[10 20 25 35 45 50];else,indices=1:50;end
for position=shard:workers:numel(indices)
    nkserRunPoint(indices(position),cohort);
end
fprintf('NKSER_SHARD_COMPLETE %s %d/%d\n',cohort,shard,workers);
end
