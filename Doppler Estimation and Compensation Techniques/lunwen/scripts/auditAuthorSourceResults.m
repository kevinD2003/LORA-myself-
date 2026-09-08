%AUDITAUTHORSOURCERESULTS Audit the historical public source profile.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultsFolder = fullfile(projectRoot, 'results');
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
files = ["case1_sf7_author_source.csv", ...
    "case2_sf7_author_source.csv", ...
    "case1_sf12_author_source.csv", ...
    "case2_sf12_author_source.csv"];
allFlagsFalse = true;
allStoppingRulesSatisfied = true;
totalRows = 0;
for file = files
    resultTable = readtable(fullfile(resultsFolder, file), ...
        'TextType', 'string');
    totalRows = totalRows + height(resultTable);
    allFlagsFalse = allFlagsFalse && ...
        ~any(resultTable.fittedOrTuned);
    stoppedCorrectly = resultTable.symbolErrors >= 1500 | ...
        resultTable.packets >= 50000;
    allStoppingRulesSatisfied = allStoppingRulesSatisfied && ...
        all(resultTable.packets >= 5000) && all(stoppedCorrectly);
end
assert(totalRows == 120);
assert(allFlagsFalse);
assert(allStoppingRulesSatisfied);

status = jsondecode(fileread(fullfile(resultsFolder, ...
    'author_source_full_run_status.json')));
assert(string(status.state) == "completed");

cfg = authorFigureSf7Config();
previousRandomState = rng;
restoreRandomState = onCleanup(@() rng(previousRandomState));
rng(9102, 'twister');
[complexAwgnProbe, ~] = applyUnitPowerAwgn(ones(16, 1), 0, cfg);
assert(~isreal(complexAwgnProbe));

audit = struct();
audit.state = "source_profile_completed";
audit.profile = "public_arxiv_figure_source";
audit.finalPaperProfile = false;
audit.publicSourceRevisionConflict = true;
audit.baselineNoiseType = "circular_complex_baseband";
audit.complexAwgnVerified = ~isreal(complexAwgnProbe);
audit.resultRows = totalRows;
audit.allFittedOrTunedFlagsFalse = allFlagsFalse;
audit.stoppingRulesSatisfied = allStoppingRulesSatisfied;
audit.sf7FigureExists = isfile(fullfile(resultsFolder, ...
    'author_source_sf7_case1_case2.png'));
audit.sf12FigureExists = isfile(fullfile(resultsFolder, ...
    'author_source_sf12_case1_case2.png'));
assert(audit.sf7FigureExists && audit.sf12FigureExists);

auditPath = fullfile(resultsFolder, 'author_source_audit.json');
fileId = fopen(auditPath, 'w');
assert(fileId >= 0);
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(audit));
fprintf('Author-source audit completed: %s\n', auditPath);
