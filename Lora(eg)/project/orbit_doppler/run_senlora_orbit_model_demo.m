function outputs = run_senlora_orbit_model_demo(options)
%RUN_SENLORA_ORBIT_MODEL_DEMO Plot the stage-1 orbit/Doppler validation.

arguments
    options.OutputDirectory (1,1) string = string(fullfile( ...
        fileparts(mfilename("fullpath")), "results", "orbit_model"))
end

if ~isfolder(options.OutputDirectory)
    mkdir(options.OutputDirectory);
end

geometry = senloraFigure17Geometry();
config = geometry.config;
timeSec = linspace(-400, 400, 3201).';
trajectory = senloraOrbitDopplerTrajectory(timeSec, config);

figureShiftRate = figure("Visible", "off", "Color", "w", ...
    "Position", [100 100 1200 760]);
layout = tiledlayout(2, 1, "TileSpacing", "compact", "Padding", "compact");
nexttile;
plot(timeSec, trajectory.dopplerShiftHz/1e3, "LineWidth", 1.5, ...
    "Color", [0.10 0.36 0.80]);
hold on;
for markerTime = geometry.highShiftTimesSec
    xline(markerTime, "--", "high shift", "Color", [0.85 0.13 0.13]);
end
for markerTime = geometry.highRateTimesSec
    xline(markerTime, "--", "high rate", "Color", [0.08 0.58 0.29]);
end
hold off;
grid on;
xlabel("Orbit time (s)");
ylabel("Doppler shift (kHz)");
title("Reference circular-orbit Doppler shift");

nexttile;
plot(timeSec, trajectory.dopplerRateHzPerSec, "LineWidth", 1.5, ...
    "Color", [0.52 0.20 0.72]);
hold on;
for markerTime = geometry.highShiftTimesSec
    xline(markerTime, "--", "high shift", "Color", [0.85 0.13 0.13]);
end
for markerTime = geometry.highRateTimesSec
    xline(markerTime, "--", "high rate", "Color", [0.08 0.58 0.29]);
end
hold off;
grid on;
xlabel("Orbit time (s)");
ylabel("Doppler rate (Hz/s)");
title("Reference circular-orbit Doppler rate");
title(layout, sprintf("SF-independent orbit model; f_c=%.0f MHz", ...
    config.carrierFrequencyHz/1e6));
shiftRateFile = fullfile(options.OutputDirectory, "orbit_shift_rate.png");
exportgraphics(figureShiftRate, shiftRateFile, "Resolution", 180);
close(figureShiftRate);

sf = 11;
representativeSymbols = [0, 1024];
representativeTimes = [geometry.highShiftTimeSec, geometry.highRateTimeSec];
figurePiecewise = figure("Visible", "off", "Color", "w", ...
    "Position", [100 100 1200 760]);
layout = tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");
validation = cell(2, 1);
for row = 1:2
    trace = senloraDopplerPiecewiseLinear( ...
        representativeSymbols(row), sf, representativeTimes(row), config);
    validation{row} = trace;
    nexttile;
    plot(trace.sampleIndex, trace.exactDopplerHz, "k", "LineWidth", 1.2, ...
        "DisplayName", "exact");
    hold on;
    plot(trace.sampleIndex, trace.linearDopplerHz, "r--", "LineWidth", 1.1, ...
        "DisplayName", "piecewise linear");
    hold off;
    grid on;
    xlabel("Sample index");
    ylabel("Doppler (Hz)");
    title(sprintf("%s, symbol %d", ...
        ternary(row == 1, "high shift", "high rate"), representativeSymbols(row)));
    if row == 1
        legend("Location", "best");
    end
    nexttile;
    plot(trace.sampleIndex, trace.phaseErrorRad, ...
        "Color", [0.10 0.36 0.80], "LineWidth", 1.2);
    grid on;
    xlabel("Sample index");
    ylabel("Phase error (rad)");
    title(sprintf("mean |f error|=%.3g Hz, phase RMSE=%.3g rad", ...
        trace.meanAbsErrorHz, trace.phaseRmseRad));
end
title(layout, "Exact orbit samples versus lora(CFO) piecewise approximation");
piecewiseFile = fullfile(options.OutputDirectory, "piecewise_validation.png");
exportgraphics(figurePiecewise, piecewiseFile, "Resolution", 180);
close(figurePiecewise);

shiftTrajectory = senloraOrbitDopplerTrajectory(geometry.highShiftTimeSec, config);
rateTrajectory = senloraOrbitDopplerTrajectory(geometry.highRateTimeSec, config);
metadata = struct( ...
    "sf", sf, ...
    "bandwidthHz", 250e3, ...
    "carrierFrequencyHz", config.carrierFrequencyHz, ...
    "highShiftTimesSec", geometry.highShiftTimesSec, ...
    "highRateTimesSec", geometry.highRateTimesSec, ...
    "highShiftHz", shiftTrajectory.dopplerShiftHz, ...
    "highRateHzPerSec", rateTrajectory.dopplerRateHzPerSec, ...
    "piecewiseMeanAbsErrorHz", [validation{1}.meanAbsErrorHz, validation{2}.meanAbsErrorHz], ...
    "piecewisePhaseRmseRad", [validation{1}.phaseRmseRad, validation{2}.phaseRmseRad]);
metadataFile = fullfile(options.OutputDirectory, "orbit_model_metadata.json");
fid = fopen(metadataFile, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s", jsonencode(metadata));
clear cleanup;

outputs = struct("shiftRateFigure", string(shiftRateFile), ...
    "piecewiseFigure", string(piecewiseFile), ...
    "metadata", string(metadataFile), "geometry", geometry, ...
    "metadataStruct", metadata);
end

function value = ternary(condition, a, b)
if condition
    value = a;
else
    value = b;
end
end
