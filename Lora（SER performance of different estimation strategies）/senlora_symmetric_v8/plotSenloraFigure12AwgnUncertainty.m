function output = plotSenloraFigure12AwgnUncertainty()
%PLOTSENLORAFIGURE12AWGNUNCERTAINTY Preserve means; show sampling uncertainty.
% Plot-only analysis: no receiver, channel, seed ledger or SER count changes.
here = fileparts(mfilename('fullpath'));
addpath(here,fullfile(here,'..','scripts')); paths = exp1SetupPaths();
inputRoot = fullfile(paths.resultsRoot,'senlora_symmetric_v8','figure12_pilot_time_aligned');
outputRoot = fullfile(paths.resultsRoot,'senlora_symmetric_v8','figure12_awgn_uncertainty');
files = dir(inputRoot); files = files(~[files.isdir]);
inputPaths = string(fullfile(inputRoot,{files.name})).';
inputHashes = localHashes(inputPaths);
raw = readtable(fullfile(inputRoot,'FOUR_CURVE_RAW_PACKETS.csv'));
summary = readtable(fullfile(inputRoot,'FOUR_CURVE_SUMMARY.csv'));
state = load(fullfile(inputRoot,'FOUR_CURVE_CHECKPOINT.mat'));
assert(isequaln(state,load(fullfile(inputRoot,'FOUR_CURVE_RESULT.mat'))));
assert(strcmp(state.stateDigest,localDigest(state)));
assert(all(state.completed) && height(raw)==10000 && height(summary)==10);
assert(~any(state.failed,'all') && ~any(state.forbidden,'all') && ~any(raw.forbiddenInput));
assert(all(strcmp(string(raw.receiverMode),'PilotTimeAligned')) && ~any(raw.isOriginalPaperThirdMethod));
errorNames = {'precRawErrors','vpRawErrors','comparisonRawErrors', ...
    'nativeIdealRawErrors','comparisonIdealRawErrors'};
counts = raw{:,errorNames};
assert(isequal(counts,state.errors));
assert(all(isfinite(counts) & counts>=0 & counts<=112 & counts==floor(counts),'all'));
assert(isequal(localHashes(state.signature.sourcePaths),string(state.signature.sourceSha256)));
assert(isequal(localHashes(state.signature.inputPaths),string(state.signature.inputSha256)));
times = [-366;-274.5;-183;-91.5;0];
snrDb = 15-10*log10(4096);
theory = senloraSymmetricV8AwgnTheory(12,snrDb);
draws = 20000; seedBase = 2026100500;
rows = cell(5,16);
for point = 1:5
    for channel = 1:2
        select = raw.channelIndex==channel & raw.pointIndex==point;
        assert(sum(select)==1000 && isequal(sort(raw.packetId(select)),(1:1000).'));
        assert(all(raw.orbitStartSec(select)==times(point)) && all(abs(raw.snrDb(select)-snrDb)<1e-12));
        s = summary(summary.channelIndex==channel & summary.pointIndex==point,:);
        assert(height(s)==1 && s.packets==1000 && s.orbitStartSec==times(point));
        totals = sum(counts(select,:),1);
        assert(isequal(s{:,errorNames},totals));
        assert(all(abs(s{:,{'precSer','vpSer','comparisonSer'}}-totals(1:3)/112000)<1e-12));
        expected = theory;
        if channel==2, expected = senloraSymmetricV8RicianTheory(12,snrDb,10); end
        assert(abs(s.theorySer-expected)<1e-12);
    end
    a = sortrows(raw(raw.channelIndex==1 & raw.pointIndex==point,:),'packetId');
    [vpBounds,differenceBounds] = localIntervals( ...
        a.vpRawErrors,a.nativeIdealRawErrors,seedBase+point,draws);
    vpErrors = sum(a.vpRawErrors); idealErrors = sum(a.nativeIdealRawErrors);
    difference = (vpErrors-idealErrors)/112000;
    rows(point,:) = {point,times(point),1000,vpErrors,idealErrors, ...
        vpErrors/112000,idealErrors/112000,theory,theory*112000, ...
        vpBounds(1),vpBounds(2),difference,differenceBounds(1),differenceBounds(2), ...
        vpBounds(1)<=theory && theory<=vpBounds(2), ...
        differenceBounds(1)<=0 && 0<=differenceBounds(2)};
end
statistics = cell2table(rows,'VariableNames',{'pointIndex','orbitStartSec','packets', ...
    'vpRawErrors','nativeIdealRawErrors','vpSer','nativeIdealSer','theorySer', ...
    'theoryExpectedErrors','vpLower95','vpUpper95','vpMinusIdealSer', ...
    'pairedDifferenceLower95','pairedDifferenceUpper95', ...
    'theoryInsidePointwiseVp95','zeroInsidePointwisePaired95'});
if ~isfolder(outputRoot), mkdir(outputRoot); end
provenance = struct('inputPaths',inputPaths,'inputSha256',inputHashes, ...
    'scriptPath',string([mfilename('fullpath'),'.m']), ...
    'scriptSha256',string(exp1Sha256([mfilename('fullpath'),'.m'])), ...
    'bootstrapDraws',draws,'analysisSeedBase',seedBase,'confidence',0.95, ...
    'intervalMethod','pointwise packet-cluster percentile, linear order-statistic interpolation', ...
    'resamplingUnit','complete packet; paired VP/native-Ideal rows share indices', ...
    'symbolsPerPacket',112,'usesNewSimulation',false,'changesRawCounts',false, ...
    'changesReceiverOrTheory',false,'isFormalAcceptanceTest',false);
awgnPath = fullfile(outputRoot,'FIGURE12_AWGN_FOUR_CURVES_95CI.png');
combinedPath = fullfile(outputRoot,'FIGURE12_AWGN_RICIAN_FOUR_CURVES_95CI.png');
fig = figure('Visible','off','Color','w','Position',[100 100 1000 700]);
localAxes(axes('Parent',fig),summary,statistics,1);
exportgraphics(fig,awgnPath,'Resolution',220); close(fig);
fig = figure('Visible','off','Color','w','Position',[100 100 1360 680]);
tiles = tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
for channel = 1:2, localAxes(nexttile,summary,statistics,channel); end
title(tiles,'SF12, E_s/N_0=15 dB: unchanged raw estimates; AWGN VP uncertainty shown');
exportgraphics(fig,combinedPath,'Resolution',220); close(fig);
assert(isequal(inputHashes,localHashes(inputPaths)),'Original results were modified.');
writetable(statistics,fullfile(outputRoot,'AWGN_POINT_UNCERTAINTY.csv'));
save(fullfile(outputRoot,'AWGN_POINT_UNCERTAINTY.mat'),'statistics','provenance');
output = struct('statistics',statistics,'provenance',provenance, ...
    'awgnFigure',awgnPath,'combinedFigure',combinedPath,'originalResultsUnchanged',true);
fprintf('AWGN uncertainty plot complete: VP/Ideal total errors %d/%d, theory %.14g.\n', ...
    sum(statistics.vpRawErrors),sum(statistics.nativeIdealRawErrors),theory);
disp(statistics);
end

function [vpBounds,differenceBounds] = localIntervals(vp,ideal,seed,draws)
stream = RandStream('mt19937ar','Seed',seed);
n = numel(vp); vpSamples = zeros(draws,1); differenceSamples = vpSamples;
for first = 1:1000:draws
    count = min(1000,draws-first+1);
    indices = randi(stream,n,n,count);
    target = first:first+count-1;
    vpSamples(target) = mean(vp(indices),1)/112;
    differenceSamples(target) = mean(vp(indices)-ideal(indices),1)/112;
end
position = 1+(draws-1)*[0.025 0.975];
vpBounds = interp1((1:draws).',sort(vpSamples),position);
differenceBounds = interp1((1:draws).',sort(differenceSamples),position);
end

function localAxes(ax,summary,statistics,channel)
data = sortrows(summary(summary.channelIndex==channel,:),'orbitStartSec');
x = data.orbitStartSec; hold(ax,'on');
plot(ax,x,data.precSer,'-v','Color',[0.6350 0.0780 0.1840], ...
    'LineWidth',1.5,'DisplayName','PREC V9: measured');
if channel==1
    assert(all(statistics.vpLower95>0)); % No clipping or fabricated zero replacement.
    errorbar(ax,x,data.vpSer,data.vpSer-statistics.vpLower95, ...
        statistics.vpUpper95-data.vpSer,'-o','Color',[0 0.4470 0.7410], ...
        'LineWidth',1.5,'CapSize',10,'DisplayName','VP V8: measured, pointwise 95% CI');
    channelName = 'AWGN';
else
    plot(ax,x,data.vpSer,'-o','Color',[0 0.4470 0.7410], ...
        'LineWidth',1.5,'DisplayName','VP V8: measured');
    channelName = 'Rician';
end
plot(ax,x,data.theorySer,'--k','LineWidth',1.7, ...
    'DisplayName','Uncoded FFT theory: ensemble mean');
plot(ax,x,data.comparisonSer,'-s','Color',[0.4660 0.6740 0.1880], ...
    'LineWidth',1.5,'DisplayName','Pilot time-aligned: variant, not Paper Eq17');
set(ax,'YScale','log'); ylim(ax,[1e-5 1]); xlim(ax,[-375 9]);
xticks(ax,x); xticklabels(ax,{'-366s','-274.5s','-183s','-91.5s','0s'}); xtickangle(ax,25);
grid(ax,'on'); grid(ax,'minor'); xlabel(ax,'Time (t) [s]'); ylabel(ax,'Raw SER');
title(ax,{sprintf('%s: SNR=%.5f dB, 1000 packets/point',channelName,data.snrDb(1)), ...
    'Theory is an expectation, not a finite-sample ordering rule'});
legend(ax,'Location','southoutside','NumColumns',2,'FontSize',9);
end

function hashes = localHashes(paths)
paths = string(paths); hashes = strings(size(paths));
for k = 1:numel(paths), hashes(k) = string(exp1Sha256(paths(k))); end
end

function hash = localDigest(state)
copy = rmfield(state,'stateDigest'); bytes = getByteStreamFromArray(orderfields(copy));
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(typecast(uint8(bytes(:)),'int8'));
hash = lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
