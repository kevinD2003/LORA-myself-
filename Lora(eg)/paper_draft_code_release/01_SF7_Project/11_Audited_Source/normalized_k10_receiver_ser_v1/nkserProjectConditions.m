function [points,configs]=nkserProjectConditions()
%NKSERPROJECTCONDITIONS Frozen 50-point normalized-K10 Rician grid.
nkserSetup();sfValues=[7 12];configs={nk10Config(7),nk10Config(12)};
rows=cell(50,1);localIndex=0;originalIndex=50;
for sfIndex=1:2
    sf=sfValues(sfIndex);grid=configs{sfIndex}.parent.snrDb;
    for caseIndex=1:2
        starts=[-366 0];
        for j=1:numel(grid)
            localIndex=localIndex+1;originalIndex=originalIndex+1;snr=grid(j);
            rows{localIndex}=entry(localIndex,originalIndex,sf,'case',caseIndex, ...
                starts(caseIndex),snr,snr+10*log10(2^sf));
        end
    end
    times=[-366 -274.5 -183 -91.5 0];esn0=15;
    for j=1:numel(times)
        localIndex=localIndex+1;originalIndex=originalIndex+1;
        rows{localIndex}=entry(localIndex,originalIndex,sf,'half',0,times(j), ...
            esn0-10*log10(2^sf),esn0);
    end
end
points=vertcat(rows{:});
assert(numel(points)==50&&points(1).originalIndex==51&&points(end).originalIndex==100);
end

function p=entry(localIndex,originalIndex,sf,family,caseIndex,time,snr,esn0)
id=sprintf('p%03d_sf%d_rician_%s%d',originalIndex,sf,family,caseIndex);
p=struct('id',id,'localIndex',localIndex,'originalIndex',originalIndex,'sf',sf, ...
    'channel','Rician','family',family,'caseIndex',caseIndex, ...
    'orbitStartSec',time,'snrDb',snr,'esN0Db',esn0);
end
