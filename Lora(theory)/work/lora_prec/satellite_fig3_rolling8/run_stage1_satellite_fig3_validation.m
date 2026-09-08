function report = run_stage1_satellite_fig3_validation()
%RUN_STAGE1_SATELLITE_FIG3_VALIDATION Generate first review figures.
%   This validates the single-device Figure 3 trajectory and continuous
%   full-frame phase before virtual-pilot compensation is introduced.

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results','stage1_model_validation');
if ~isfolder(resultDir)
    mkdir(resultDir);
end
config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
config.scenarios(1).startTimeSec = -window.deltaTimeOutSec;
config.scenarios(2).startTimeSec = window.deltaTimeInSec;

t = (-config.trajectoryPlotHalfSpanSec:config.trajectoryTimeStepSec: ...
    config.trajectoryPlotHalfSpanSec).';
[~,visible] = satelliteFig3VisibilityWindow(config,t);
trajectory = satelliteFig3Trajectory(t,config);
highShift = satelliteFig3Trajectory(config.scenarios(1).startTimeSec,config);
highRate = satelliteFig3Trajectory(config.scenarios(2).startTimeSec,config);

fig1 = figure('Visible','off','Color','w','Position',[100 100 1250 730]);
left = trajectory.dopplerShiftHz/1e3;
right = trajectory.dopplerRateHzPerSec;
leftVisible = left; leftVisible(~visible) = NaN;
rightVisible = right; rightVisible(~visible) = NaN;
leftBlind = left; leftBlind(visible) = NaN;
rightBlind = right; rightBlind(visible) = NaN;
yyaxis left
plot(t,leftVisible,'-','LineWidth',2.5,'Color',[0 0.45 0.74]); hold on
plot(t,leftBlind,'--','LineWidth',1.7,'Color',[0 0.45 0.74]);
plot(config.scenarios(1).startTimeSec,highShift.dopplerShiftHz/1e3,'d', ...
    'MarkerSize',11,'MarkerFaceColor',[0 0.45 0.74],'MarkerEdgeColor','k');
plot(config.scenarios(2).startTimeSec,highRate.dopplerShiftHz/1e3,'d', ...
    'MarkerSize',11,'MarkerFaceColor',[0 0.45 0.74],'MarkerEdgeColor','k');
ylabel('Doppler shift (kHz)'); ylim([-20 20]);
yyaxis right
plot(t,rightVisible,'-','LineWidth',2.5,'Color',[0.85 0.325 0.098]);
plot(t,rightBlind,'--','LineWidth',1.7,'Color',[0.85 0.325 0.098]);
plot(config.scenarios(1).startTimeSec,highShift.dopplerRateHzPerSec,'^', ...
    'MarkerSize',11,'MarkerFaceColor',[0.85 0.325 0.098],'MarkerEdgeColor','k');
plot(config.scenarios(2).startTimeSec,highRate.dopplerRateHzPerSec,'^', ...
    'MarkerSize',11,'MarkerFaceColor',[0.85 0.325 0.098],'MarkerEdgeColor','k');
ylabel('Doppler rate (Hz/s)'); ylim([-250 0]);
xlabel('Time relative to t_{cv} (s)'); grid on
title(sprintf(['Single-device dynamic Doppler (f_c = %.0f MHz, H = %.0f km, ' ...
    'i = %.0f deg)'],config.carrierFrequencyHz/1e6,config.orbitHeightM/1e3, ...
    rad2deg(config.inclinationRad)));
legend('Doppler shift - visible','Doppler shift - blind', ...
    'High-shift candidate','High-rate candidate', ...
    'Doppler rate - visible','Doppler rate - blind','Location','southwest');
exportgraphics(fig1,fullfile(resultDir,'figure3_single_device_trajectory.png'),'Resolution',180);
savefig(fig1,fullfile(resultDir,'figure3_single_device_trajectory.fig'));
close(fig1);

trace = satelliteFig3PiecewiseDoppler(1024,config.scenarios(2).startTimeSec,config);
fig2 = figure('Visible','off','Color','w','Position',[100 100 1250 680]);
subplot(2,1,1)
plot(trace.sampleTimeSec-trace.sampleTimeSec(1),trace.exactDopplerHz/1e3, ...
    'LineWidth',2); hold on
plot(trace.sampleTimeSec-trace.sampleTimeSec(1),trace.linearDopplerHz/1e3, ...
    '--','LineWidth',1.4);
grid on; ylabel('Doppler (kHz)');
legend('Exact full-RF','Piecewise linear','Location','best');
title('One SF11 symbol at the high-rate Figure 3 point');
subplot(2,1,2)
plot(trace.sampleTimeSec-trace.sampleTimeSec(1),trace.phaseErrorRad,'LineWidth',1.5);
grid on; xlabel('Time within symbol (s)');
ylabel('Linear - exact phase (rad)');
exportgraphics(fig2,fullfile(resultDir,'exact_vs_piecewise_symbol.png'),'Resolution',180);
savefig(fig2,fullfile(resultDir,'exact_vs_piecewise_symbol.fig'));
close(fig2);

payload = satelliteFig3GeneratePayload(config,config.randomSeedSymbols);
frameBins = [zeros(config.bootstrapPilotCount,1); payload.symbolBins];
[~,~,frameTruth] = generateContinuousSatelliteFrame(frameBins,config, ...
    StartTimeSec=config.scenarios(2).startTimeSec,SampleSnrDb=Inf);
phaseSerial = reshape(frameTruth.phaseRad.',[],1);
dopplerSerial = reshape(frameTruth.dopplerHz.',[],1);
boundary = config.samplesPerSymbol*(1:config.frameSymbolCount-1);
expectedIncrement = pi/config.sampleRateHz*( ...
    dopplerSerial(boundary)+dopplerSerial(boundary+1));
actualIncrement = phaseSerial(boundary+1)-phaseSerial(boundary);
phaseBoundaryErrorRad = max(abs(actualIncrement-expectedIncrement));

report = struct( ...
    'configuration',config, 'visibilityWindow',window, ...
    'highShiftDopplerHz',highShift.dopplerShiftHz, ...
    'highShiftRateHzPerSec',highShift.dopplerRateHzPerSec, ...
    'highRateDopplerHz',highRate.dopplerShiftHz, ...
    'highRateRateHzPerSec',highRate.dopplerRateHzPerSec, ...
    'piecewiseMeanAbsErrorHz',trace.meanAbsErrorHz, ...
    'piecewisePhaseRmseRad',trace.phaseRmseRad, ...
    'phaseBoundaryErrorRad',phaseBoundaryErrorRad, ...
    'resultDir',resultDir);
save(fullfile(resultDir,'stage1_validation_report.mat'),'report','trace','frameTruth');
fprintf('Stage 1 result folder: %s\\n',resultDir);
fprintf('Visible duration %.6f s; high-shift %.3f kHz / %.3f Hz/s; high-rate %.3f kHz / %.3f Hz/s\\n', ...
    window.totalVisibleDurationSec,highShift.dopplerShiftHz/1e3, ...
    highShift.dopplerRateHzPerSec,highRate.dopplerShiftHz/1e3, ...
    highRate.dopplerRateHzPerSec);
fprintf('Frame phase-boundary error: %.3g rad\\n',phaseBoundaryErrorRad);
end
