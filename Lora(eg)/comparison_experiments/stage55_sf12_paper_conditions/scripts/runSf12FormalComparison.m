function summary = runSf12FormalComparison(options)
%RUNSF12FORMALCOMPARISON Paired, resumable 2 Case x 10 SNR experiment.

arguments
    options.MinimumPackets (1,1) double {mustBeInteger,mustBePositive} = 5000
    options.MaximumPackets (1,1) double {mustBeInteger,mustBePositive} = 50000
    options.MinimumSymbolErrors (1,1) double {mustBeInteger,mustBeNonnegative} = 1500
end
root = sf12SetupPaths();
cfg = sf12PaperCommonConfig();
if ~cfg.receiver.manifest.calibrationRunCompleted
    error('Sf12:CalibrationRequired', ...
        'Run runSf12MechanismCalibration before the formal experiment.');
end
folder = fullfile(root,'results','formal_common_frame');
if ~isfolder(folder), mkdir(folder); end
summary = table();
for caseName = ["case1","case2"]
    for snrIndex = 1:numel(cfg.monteCarlo.snrDb)
        snrDb = cfg.monteCarlo.snrDb(snrIndex);
        state = localEmptyState(caseName,snrDb);
        checkpoint = fullfile(folder,sprintf('%s_%+03ddB_checkpoint.mat', ...
            caseName,snrDb));
        if isfile(checkpoint)
            loaded = load(checkpoint,'state');
            state = loaded.state;
        end
        while state.packets < options.MaximumPackets && ...
                (state.packets < options.MinimumPackets || ...
                state.paperErrors < options.MinimumSymbolErrors || ...
                state.stage55Errors < options.MinimumSymbolErrors)
            packet = state.packets+1;
            r = sf12PairedFrameSimulation(cfg,caseName,snrDb, ...
                packet,"formal",snrIndex);
            state = localAccumulate(state,r);
            if mod(packet,cfg.monteCarlo.checkpointEveryPackets) == 0
                save(checkpoint,'state','cfg');
            end
        end
        if state.paperErrors >= options.MinimumSymbolErrors && ...
                state.stage55Errors >= options.MinimumSymbolErrors
            state.stopReason = "both_methods_reached_error_target";
        else
            state.stopReason = "maximum_packets";
        end
        save(checkpoint,'state','cfg');
        rows = localSummaryRows(state);
        summary = [summary;rows]; %#ok<AGROW>
        writetable(summary,fullfile(folder,'sf12_formal_summary.csv'));
        save(fullfile(folder,'sf12_formal_summary.mat'),'summary','cfg');
    end
end
end

function state = localEmptyState(caseName,snrDb)
state = struct('caseName',caseName,'snrDb',snrDb,'packets',0, ...
    'totalSymbols',0,'paperErrors',0,'stage55Errors',0, ...
    'paperCfoSse',0,'stage55CfoSse',0,'cfoSamples',0, ...
    'stage55Accepted',0,'stage55FalseAccepted',0, ...
    'paperCoverage',0,'stage55Coverage',0, ...
    'paperRuntimeSec',0,'stage55RuntimeSec',0, ...
    'paperFftCount',0,'stage55FftCount',0, ...
    'paperMidambles',0,'ledger',table(),'trace',struct(), ...
    'paperPilotFirstEffect',zeros(0,8), ...
    'stage55PilotFirstEffect',zeros(0,23), ...
    'stopReason',"");
end

function state = localAccumulate(state,r)
state.packets = state.packets+1;
state.totalSymbols = state.totalSymbols+r.totalDataSymbols;
state.paperErrors = state.paperErrors+r.paperSymbolErrors;
state.stage55Errors = state.stage55Errors+r.stage55SymbolErrors;
state.paperCfoSse = state.paperCfoSse+r.paperCfoSquaredError;
state.stage55CfoSse = state.stage55CfoSse+r.stage55CfoSquaredError;
state.cfoSamples = state.cfoSamples+r.cfoSampleCount;
state.stage55Accepted = state.stage55Accepted+r.stage55AcceptedVirtualPilots;
state.stage55FalseAccepted = state.stage55FalseAccepted+ ...
    r.stage55FalseAcceptedVirtualPilots;
state.paperMidambles = state.paperMidambles+r.paperEffectiveMidambles;
state.paperCoverage = state.paperCoverage+r.paperPilotImpactCoverageSymbols;
state.stage55Coverage = state.stage55Coverage+ ...
    r.stage55PilotImpactCoverageSymbols;
state.paperRuntimeSec = state.paperRuntimeSec+r.paperRuntimeSec;
state.stage55RuntimeSec = state.stage55RuntimeSec+r.stage55RuntimeSec;
state.paperFftCount = state.paperFftCount+r.paperFftCount;
state.stage55FftCount = state.stage55FftCount+r.stage55FftCount;
ledgerRow = table(r.packetIndex,r.payloadSeed,r.noiseSeed,r.channelSeed, ...
    'VariableNames',{'packetIndex','payloadSeed','noiseSeed','channelSeed'});
state.ledger = [state.ledger;ledgerRow];
state.paperPilotFirstEffect(state.packets,:) = ...
    r.paperFirstEffectiveDataIndex(:).';
state.stage55PilotFirstEffect(state.packets,:) = ...
    r.stage55FirstEffectiveDataIndex(:).';
if r.packetIndex == 1
    state.trace = r;
end
end

function rows = localSummaryRows(state)
methods = ["Paper-Midamble-Point";"Stage55-VP-quality-SER"];
errors = [state.paperErrors;state.stage55Errors];
cfoSse = [state.paperCfoSse;state.stage55CfoSse];
accepted = [0;state.stage55Accepted];
falseAccepted = [0;state.stage55FalseAccepted];
midambles = [state.paperMidambles;0];
coverage = [state.paperCoverage;state.stage55Coverage];
runtimeSec = [state.paperRuntimeSec;state.stage55RuntimeSec];
fftCount = [state.paperFftCount;state.stage55FftCount];
ser = errors/state.totalSymbols;
ci = zeros(2,2);
for k = 1:2, ci(k,:) = sf12WilsonInterval(errors(k),state.totalSymbols); end
rows = table(repmat(string(state.caseName),2,1), ...
    repmat(state.snrDb,2,1),methods,repmat(state.packets,2,1), ...
    errors,repmat(state.totalSymbols,2,1),ser,ci(:,1),ci(:,2), ...
    sqrt(cfoSse/state.cfoSamples),accepted,falseAccepted,midambles, ...
    coverage,runtimeSec,fftCount, ...
    repmat(string(state.stopReason),2,1), ...
    'VariableNames',{'caseName','snrDb','method','packets', ...
    'symbolErrors','totalDataSymbols','ser','ci95Low','ci95High', ...
    'cfoRmseHz','acceptedVirtualPilots','falseAcceptedVirtualPilots', ...
    'effectiveMidambles','pilotImpactCoverageSymbols','runtimeSec', ...
    'fftCount','stopReason'});
end
