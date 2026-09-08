function audit = auditSf12Comparison()
%AUDITSF12COMPARISON Machine-check physical, fairness and statistics gates.

root = sf12SetupPaths();
cfg = sf12PaperCommonConfig();
layout = sf12BuildFrameLayout(cfg);
audit = struct();
audit.sf12 = cfg.radio.sf == 12;
audit.paperConditions = cfg.channel.ricianKDb == 10 && ...
    cfg.radio.bandwidthHz == 125e3 && cfg.frame.payloadSymbolCount == 23;
audit.layout = isequal(layout.midambleAfterDataIndex,[3:3:21,23].') && ...
    numel(layout.trackingMidambleRows) == 7;
audit.noImageCalibration = ~cfg.provenance.fittedOrTuned;
audit.receiverManifestCalibrated = ...
    cfg.receiver.manifest.calibrationRunCompleted;
smokeFile = fullfile(root,'results','validation','sf12_smoke_packets.csv');
if isfile(smokeFile)
    smoke = readtable(smokeFile,'TextType','string');
    audit.commonBootstrap = all(smoke.paperInitialCfoHz == ...
        smoke.stage55InitialCfoHz);
    audit.pilotIsolation = all(smoke.stage55ExplicitMidambleAccepted == 0) && ...
        all(smoke.paperVirtualPilotAccepted == 0) && ...
        all(smoke.paperEffectiveMidambles == 7);
else
    audit.commonBootstrap = false;
    audit.pilotIsolation = false;
end
formalFile = fullfile(root,'results','formal_common_frame', ...
    'sf12_formal_summary.csv');
if isfile(formalFile)
    data = readtable(formalFile,'TextType','string');
    audit.serArithmetic = all(abs(data.ser-data.symbolErrors./ ...
        data.totalDataSymbols) < 10*eps);
    audit.pairedStop = localPairedCounts(data);
else
    audit.serArithmetic = false;
    audit.pairedStop = false;
end
audit.requiredImplementationGates = audit.sf12 && audit.paperConditions && ...
    audit.layout && audit.noImageCalibration;
matlabFiles = dir(fullfile(root,'**','*.m'));
audit.staticCheckIssueCount = 0;
for k = 1:numel(matlabFiles)
    issues = checkcode(fullfile(matlabFiles(k).folder,matlabFiles(k).name),'-id');
    audit.staticCheckIssueCount = audit.staticCheckIssueCount+numel(issues);
end
audit.staticCheckPassed = audit.staticCheckIssueCount == 0;
audit.completeExperimentGates = audit.requiredImplementationGates && ...
    audit.staticCheckPassed && audit.receiverManifestCalibrated && ...
    audit.commonBootstrap && audit.pilotIsolation && ...
    audit.serArithmetic && audit.pairedStop;
folder = fullfile(root,'results');
fid = fopen(fullfile(folder,'audit.json'),'w');
assert(fid >= 0); cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(audit,'PrettyPrint',true));
assert(audit.requiredImplementationGates,'SF12 implementation audit failed.');
if isfile(formalFile)
    assert(audit.completeExperimentGates, ...
        'SF12 formal-result audit failed.');
end
end

function paired = localPairedCounts(data)
paired = true;
groups = unique(data(:,{'caseName','snrDb'}),'rows');
for k = 1:height(groups)
    rows = data(data.caseName == groups.caseName(k) & ...
        data.snrDb == groups.snrDb(k),:);
    paired = paired && height(rows) == 2 && numel(unique(rows.packets)) == 1;
end
end
