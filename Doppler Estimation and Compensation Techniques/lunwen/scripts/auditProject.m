%AUDITPROJECT Final requirement-level audit for SF=7, SF=11 and SF=12.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
resultsFolder = fullfile(projectRoot, 'results');
addpath(fullfile(projectRoot, 'scripts'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));

matlabFiles = dir(fullfile(projectRoot, '**', '*.m'));
matlabFiles = matlabFiles(~contains( ...
    string({matlabFiles.folder}), fullfile(projectRoot, 'tmp')));
issueCount = 0;
for index = 1:numel(matlabFiles)
    filePath = fullfile(matlabFiles(index).folder, ...
        matlabFiles(index).name);
    issues = checkcode(filePath, '-struct');
    issueCount = issueCount + numel(issues);
    for issueIndex = 1:numel(issues)
        fprintf('%s:%d: %s\n', filePath, ...
            issues(issueIndex).line, issues(issueIndex).message);
    end
end
assert(issueCount == 0, 'Active Code Analyzer findings remain.');

testResults = runProjectTests(string(fullfile(projectRoot, 'tests')));
assert(all([testResults.Passed]) && ~any([testResults.Failed]) && ...
    ~any([testResults.Incomplete]));
coverage = jsondecode(fileread(fullfile(resultsFolder, ...
    'coverage_summary.json')));
sourceFiles = dir(fullfile(projectRoot, 'src', '*.m'));
assert(coverage.testCount == numel(testResults));
assert(coverage.sourceFileCount == numel(sourceFiles));
assert(coverage.statementCoveragePercent >= ...
    coverage.minimumStatementCoveragePercent);
assert(coverage.functionCoveragePercent >= ...
    coverage.minimumFunctionCoveragePercent);

sf12Status = jsondecode(fileread(fullfile(resultsFolder, ...
    'full_run_status.json')));
sf7Status = jsondecode(fileread(fullfile(resultsFolder, ...
    'sf7_full_run_status.json')));
sf11Status = jsondecode(fileread(fullfile(resultsFolder, ...
    'sf11_full_run_status.json')));
authorSourceStatus = jsondecode(fileread(fullfile(resultsFolder, ...
    'author_source_full_run_status.json')));
assert(string(sf12Status.state) == "completed");
assert(string(sf7Status.state) == "completed");
assert(string(sf11Status.state) == "completed");
assert(string(authorSourceStatus.state) == "completed");

sf12Audit = jsondecode(fileread(fullfile(resultsFolder, ...
    'full_result_audit.json')));
sf7Audit = jsondecode(fileread(fullfile(resultsFolder, ...
    'sf7_result_audit.json')));
sf11Audit = jsondecode(fileread(fullfile(resultsFolder, ...
    'sf11_result_audit.json')));
authorSourceAudit = jsondecode(fileread(fullfile(resultsFolder, ...
    'author_source_audit.json')));
publicationConsistency = jsondecode(fileread(fullfile(resultsFolder, ...
    'publication_consistency.json')));
assert(sf12Audit.dataIntegrityPassed);
assert(sf7Audit.dataIntegrityPassed);
assert(sf11Audit.dataIntegrityPassed);
assert(string(authorSourceAudit.state) == ...
    "source_profile_completed");
assert(authorSourceAudit.complexAwgnVerified);
assert(~authorSourceAudit.finalPaperProfile);
assert(authorSourceAudit.publicSourceRevisionConflict);
assert(publicationConsistency.paperInternalConflictProved);
freshPublicationConsistency = analyzePublicationConsistency( ...
    paperSf12Config());
assert(freshPublicationConsistency.paperInternalConflictProved);
assert(abs(freshPublicationConsistency.fractionalApproximationToaS - ...
    publicationConsistency.fractionalApproximationToaS) < 1e-12);

diagnosticFolder = fullfile(resultsFolder, 'diagnostics');
ldroDiagnostic = readtable(fullfile(diagnosticFolder, ...
    'ldro_decision_endpoint.csv'), 'TextType', 'string');
sampleRicianDiagnostic = readtable(fullfile(diagnosticFolder, ...
    'sample_rician_endpoint.csv'), 'TextType', 'string');
assert(height(ldroDiagnostic) == 12);
assert(height(sampleRicianDiagnostic) == 2);
calibrationAudit = jsondecode(fileread(fullfile(resultsFolder, ...
    'calibrated', 'validation', ...
    'calibration_validation_audit.json')));
assert(calibrationAudit.allEndpointsWithinPaperBands);
assert(calibrationAudit.fittedOrTuned);
assert(~calibrationAudit.completeIndependentReproductionClaimed);
sf11CalibrationAudit = jsondecode(fileread(fullfile(resultsFolder, ...
    'calibrated_sf11', 'audit.json')));
assert(string(sf11CalibrationAudit.state) == "passed");
assert(sf11CalibrationAudit.fittedOrTuned);
assert(sf11CalibrationAudit.parametersDerivedFromSf7Sf12);
assert(sf11CalibrationAudit.case1PointNotAboveMidamble);
assert(sf11CalibrationAudit.case2MidambleBelowPoint);
assert(isfile(fullfile(resultsFolder, 'calibrated_sf11', 'curves', ...
    'sf11_calibrated_case1_case2.png')));
calibratedCurveFiles = ["case1_sf7_calibrated.csv", ...
    "case2_sf7_calibrated.csv", "case1_sf12_calibrated.csv", ...
    "case2_sf12_calibrated.csv"];
calibratedCurveRows = 0;
calibratedOrderingComparisonCount = 0;
for calibratedFile = calibratedCurveFiles
    calibratedData = readtable(fullfile(resultsFolder, 'calibrated', ...
        'curves', calibratedFile), 'TextType', 'string');
    assert(height(calibratedData) == 30);
    assert(all(calibratedData.fittedOrTuned));
    assert(all(abs(calibratedData.ser - ...
        calibratedData.symbolErrors./calibratedData.totalSymbols) < 1e-14));
    pointRows = sortrows( ...
        calibratedData(calibratedData.strategy == "point", :), 'snrDb');
    midambleRows = sortrows(calibratedData( ...
        calibratedData.strategy == "midamble_point", :), 'snrDb');
    assert(isequal(pointRows.snrDb, midambleRows.snrDb));
    if calibratedFile == "case2_sf12_calibrated.csv"
        assert(all(midambleRows.ser <= pointRows.ser));
    else
        assert(all(pointRows.ser <= midambleRows.ser));
    end
    calibratedOrderingComparisonCount = ...
        calibratedOrderingComparisonCount + height(pointRows);
    calibratedCurveRows = calibratedCurveRows + height(calibratedData);
end
calibratedFigureFiles = ["figure10_11_sf7_calibrated.png", ...
    "figure10_11_sf12_calibrated.png"];
for calibratedFigure = calibratedFigureFiles
    assert(isfile(fullfile(resultsFolder, 'calibrated', ...
        'curves', calibratedFigure)));
end

resultFiles = ["case1_sf7.csv", "case2_sf7.csv", ...
    "case1_sf11.csv", "case2_sf11.csv", ...
    "case1_sf12.csv", "case2_sf12.csv"];
totalResultRows = 0;
sf7Results = table();
sf12Results = table();
for resultFile = resultFiles
    resultTable = readtable(fullfile(resultsFolder, resultFile), ...
        'TextType', 'string');
    assert(height(resultTable) == 30);
    assert(~any(resultTable.fittedOrTuned));
    assert(all(resultTable.packets >= 5000));
    assert(all(resultTable.symbolErrors >= 1500));
    totalResultRows = totalResultRows + height(resultTable);
    if contains(resultFile, "_sf7")
        sf7Results = [sf7Results; resultTable]; %#ok<AGROW>
    elseif contains(resultFile, "_sf12")
        sf12Results = [sf12Results; resultTable]; %#ok<AGROW>
    end
end

hashManifest = readtable(fullfile(projectRoot, 'reference', ...
    'primaryResultHashes.csv'), 'TextType', 'string');
assert(height(hashManifest) == numel(resultFiles));
for index = 1:height(hashManifest)
    resultPath = fullfile(resultsFolder, hashManifest.fileName(index));
    assert(fileSha256(string(resultPath)) == ...
        lower(hashManifest.sha256(index)), ...
        'Frozen primary result changed: %s', ...
        hashManifest.fileName(index));
end

paperReference = readtable(fullfile(projectRoot, 'reference', ...
    'paperEndpointAcceptance.csv'), 'TextType', 'string');
freshSf7Agreement = evaluatePaperAgreement( ...
    sf7Results, paperReference, 7);
freshSf12Agreement = evaluatePaperAgreement( ...
    sf12Results, paperReference, 12);
assert(freshSf7Agreement.passed == sf7Audit.paperAgreementPassed);
assert(freshSf12Agreement.passed == sf12Audit.paperAgreementPassed);

figureFiles = ["figure10_11_sf7_midamble_point.png", ...
    "sf11_midamble_point_case1_case2.png", ...
    "figure10_11_sf12_midamble_point.png", ...
    "sf7_sf11_sf12_midamble_summary.png"];
for figureFile = figureFiles
    assert(isfile(fullfile(resultsFolder, figureFile)));
end

audit = struct();
audit.paperAgreementSf7 = freshSf7Agreement.passed;
audit.paperAgreementSf12 = freshSf12Agreement.passed;
audit.paperAgreementAll = audit.paperAgreementSf7 && ...
    audit.paperAgreementSf12;
audit.independentReproductionPassed = true;
audit.completePaperReproductionClaimed = audit.paperAgreementAll;
if audit.paperAgreementAll
    audit.state = "paper_match_passed";
    audit.paperMatchState = "matched";
else
    audit.state = "independent_reproduction_passed";
    audit.paperMatchState = ...
        "not_reproducible_from_available_publication_materials";
end
audit.matlabRelease = version('-release');
audit.codeAnalyzerFileCount = numel(matlabFiles);
audit.codeAnalyzerIssueCount = issueCount;
audit.unitTestCount = numel(testResults);
audit.unitTestsPassed = all([testResults.Passed]);
audit.unitTestsExecutedFresh = true;
audit.statementCoveragePercent = ...
    coverage.statementCoveragePercent;
audit.functionCoveragePercent = ...
    coverage.functionCoveragePercent;
audit.completedSpreadingFactors = [7, 11, 12];
audit.fullResultRows = totalResultRows;
audit.allFittedOrTunedFlagsFalse = true;
audit.minimumPacketsPerPoint = 5000;
audit.minimumErrorsPerPoint = 1500;
audit.primaryFigureCount = numel(figureFiles);
audit.primaryResultHashesPassed = true;
audit.primaryResultHashCount = height(hashManifest);
audit.coverageGatePresent = true;
audit.authorSourceProfileCompleted = true;
audit.authorSourceIsFinalPaperProfile = false;
audit.authorSourceComplexAwgnVerified = ...
    authorSourceAudit.complexAwgnVerified;
audit.authorSourceResultRows = authorSourceAudit.resultRows;
audit.publicationConsistencyProofPassed = ...
    publicationConsistency.paperInternalConflictProved;
audit.sf12TableUsesFractionalMidambleApproximation = ...
    publicationConsistency.tableMatchesFractionalApproximation;
audit.sf12Equation20ImplementedToaS = ...
    publicationConsistency.implementedToaS;
audit.sf12TableReportedToaS = ...
    publicationConsistency.paperTableMidamblePointToaS;
audit.ldroDecisionDiagnosticRows = height(ldroDiagnostic);
audit.sampleRicianDiagnosticRows = height(sampleRicianDiagnostic);
audit.calibratedProfileAvailable = true;
audit.calibratedEndpointMatchPassed = ...
    calibrationAudit.allEndpointsWithinPaperBands;
audit.calibratedProfileFittedOrTuned = ...
    calibrationAudit.fittedOrTuned;
audit.calibratedValidationSeed = calibrationAudit.randomSeed;
audit.calibratedParameters = calibrationAudit.parameters;
audit.calibratedCurveRows = calibratedCurveRows;
audit.calibratedFigureCount = numel(calibratedFigureFiles);
audit.calibratedPaperOrderingPassed = true;
audit.calibratedOrderingComparisonCount = ...
    calibratedOrderingComparisonCount;
audit.calibratedSerEqualsRawErrorRatio = true;
audit.calibratedSf11Available = true;
audit.calibratedSf11AuditPassed = true;
audit.calibratedSf11ParametersDerivedFromSf7Sf12 = true;
audit.calibratedSf11PacketsPerPoint = ...
    sf11CalibrationAudit.packetsPerPoint;
audit.calibratedSf11RawResultRows = ...
    sf11CalibrationAudit.rawResultRowCount;
audit.calibratedSf11OrderingComparisonCount = ...
    sf11CalibrationAudit.orderingComparisonCount;
physicalConfig = paperSf12Config();
legacyCalibrationConfig = calibratedPaperSf12Config();
assert(physicalConfig.receiver.midambleEstimatorModel == "physical");
assert(physicalConfig.receiver.midambleEstimatorSnrOffsetDb == 0);
assert(legacyCalibrationConfig.receiver.midambleEstimatorModel == ...
    "legacy_snr_offset");
audit.defaultMidambleEstimatorModel = ...
    physicalConfig.receiver.midambleEstimatorModel;
audit.defaultMidambleAddsArtificialNoise = false;
audit.legacyCalibratedSnrOffsetIsIsolated = true;
audit.unresolvedReasons = [ ...
    "paper_endpoint_mismatch", ...
    "final_simulator_not_published", ...
    "temporal_rician_parameters_not_published"];
audit.resolvedPublicationFindings = [ ...
    "sf12_table3_uses_fractional_midamble_count", ...
    "public_source_is_awgn_only_incompatible_revision", ...
    "valid_bins_only_ldro_does_not_explain_endpoint_gap", ...
    "sample_independent_rician_does_not_explain_endpoint_gap"];

auditPath = fullfile(resultsFolder, 'project_audit.json');
fileId = fopen(auditPath, 'w');
assert(fileId >= 0);
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', jsonencode(audit));
fprintf('Project audit completed with state %s: %s\n', ...
    audit.state, auditPath);
