function config = ideal_ser_config()
%IDEAL_SER_CONFIG Independent ideal-compensation SER experiment.
% The experiment copies no performance samples from the frozen Stage55
% results.  Only configuration and physical-model source code are inputs.

here = fileparts(mfilename('fullpath'));

config.identity = 'ideal-stage55-conditions-ser-v1';
config.outputFolder = fullfile(here,'results');
config.stage55Root = ['D:\codex\Lora(eg)\comparison_experiments\' ...
    'stage55_sf12_sf11_flow_v4_noldro'];

config.sf = 12;
config.bandwidthHz = 125e3;
config.sampleRateHz = 125e3;
config.carrierFrequencyHz = 868e6;
config.samplesPerSymbol = 2^config.sf;
config.symbolDurationSec = config.samplesPerSymbol/config.sampleRateHz;
config.fftBinSpacingHz = config.bandwidthHz/config.samplesPerSymbol;

config.snrAnchorDb = (-30:-21).';
config.snrCurveDb = (-30:0.25:-21).';
config.caseNames = ["Case A";"Case B"];
config.caseStartTimeSec = [-366;0];

% Fresh seed domain.  These values do not overlap the frozen formal runs.
config.baseSeed = 20260915;
config.validationPacketsPerCaseSnr = 200;
config.confidenceZ = 4.0;
config.randomGenerator = 'mt19937ar';

config.theoryRelTol = 1e-9;
config.theoryAbsTol = 1e-14;
config.noiselessTolerance = 2e-10;
config.noisePowerRelativeTolerance = 5e-3;

config.performanceDataInputs = strings(0,1);
config.fittedToFrozenData = false;
config.existingPerformanceDataLoaded = false;
config.curveSource = 'exact numerical integration; no fit or interpolation';
config.validationSource = ['fresh full-waveform Monte Carlo with exact ' ...
    'samplewise Doppler phase cancellation'];

config.stage55SourceFiles = {
    'config/sf12NoLdroSf11FlowConfig.m'
    'src/coding/v4GeneratePayload.m'
    'src/phy/v4BuildFrameLayout.m'
    'src/phy/v4ModulateSymbol.m'
    'src/phy/v4SymbolLikelihood.m'
    'src/paper_anchor/v4TrackAOrbit.m'
    };
end
