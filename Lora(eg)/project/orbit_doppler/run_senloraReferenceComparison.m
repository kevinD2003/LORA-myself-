function report = run_senloraReferenceComparison(options)
%RUNSENLORAREFERENCECOMPARISON Compare the new channel with lora(CFO).

arguments
    options.ReferenceFolder (1,1) string = ""
end
rootFolder = fileparts(mfilename("fullpath"));
if strlength(options.ReferenceFolder) == 0
    workspaceFolder = fileparts(fileparts(rootFolder));
    referenceFolder = fullfile(workspaceFolder,"lora(CFO)");
else
    referenceFolder = options.ReferenceFolder;
end
resultFolder = fullfile(rootFolder,"results","regression_tests");
if ~isfolder(resultFolder)
    mkdir(resultFolder);
end
if ~isfolder(referenceFolder)
    error("SenLoRa:ReferenceFolderMissing", ...
        "Reference folder was not found. Set ReferenceFolder explicitly.");
end
originalPath = path;
pathCleanup = onCleanup(@()path(originalPath));
addpath(char(referenceFolder));
reference = lora_orbit_doppler_config();
ours = senloraOrbitConfig();
constantNames = ["speedOfLightMps","gravityMps2","earthRadiusM", ...
    "earthRotationRadPerSec","orbitHeightM","inclinationRad", ...
    "carrierFrequencyHz","theoreticalMaxElevationRad", ...
    "minimumElevationRad","maximumElevationRad", ...
    "centralVisibilityTimeSec"];
constantDiff = zeros(numel(constantNames),1);
for idx = 1:numel(constantNames)
    constantDiff(idx) = abs(double(ours.(constantNames(idx))) - ...
        double(reference.(constantNames(idx))));
end

timeSec = (-400:0.5:400).';
referenceTrajectory = lora_orbit_doppler_trajectory(timeSec,reference);
ourTrajectory = senloraOrbitDopplerTrajectory(timeSec,ours);
shiftDiff = max(abs(referenceTrajectory.dopplerShiftHz - ...
    ourTrajectory.dopplerShiftHz));
rateDiff = max(abs(referenceTrajectory.dopplerRateHzPerSec - ...
    ourTrajectory.dopplerRateHzPerSec));

symbols = [0;1;2^11-1];
starts = [ours.centralVisibilityTimeSec-249.75203746714354; ...
    ours.centralVisibilityTimeSec+37.082433353952396; ...
    ours.centralVisibilityTimeSec];
piecewiseDiffHz = 0;
piecewiseDiffPhase = 0;
for symbolIdx = 1:numel(symbols)
    refTrace = lora_doppler_piecewise_linear( ...
        symbols(symbolIdx),11,starts(symbolIdx),reference, ...
        BandwidthHz=250e3);
    ourTrace = senloraDopplerPiecewiseLinear( ...
        symbols(symbolIdx),11,starts(symbolIdx),ours, ...
        BandwidthHz=250e3);
    piecewiseDiffHz = max(piecewiseDiffHz, ...
        max(abs(refTrace.linearDopplerHz-ourTrace.linearDopplerHz)));
    piecewiseDiffPhase = max(piecewiseDiffPhase, ...
        max(abs(refTrace.linearPhaseRad-ourTrace.linearPhaseRad)));
end

report = struct( ...
    "referenceFolder",string(referenceFolder), ...
    "constantNames",constantNames, ...
    "maxConstantAbsDiff",max(constantDiff), ...
    "maxTrajectoryShiftAbsDiffHz",shiftDiff, ...
    "maxTrajectoryRateAbsDiffHzPerSec",rateDiff, ...
    "maxPiecewiseFrequencyAbsDiffHz",piecewiseDiffHz, ...
    "maxPiecewisePhaseAbsDiffRad",piecewiseDiffPhase, ...
    "pass",max([constantDiff;shiftDiff;rateDiff;piecewiseDiffHz;piecewiseDiffPhase]) < 1e-10);
fid = fopen(fullfile(resultFolder,"reference_comparison.json"),"w");
if fid < 0
    error("SenLoRa:ReferenceReportOpenFailed","Could not write comparison.");
end
cleanup = onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(report),"char");
end
