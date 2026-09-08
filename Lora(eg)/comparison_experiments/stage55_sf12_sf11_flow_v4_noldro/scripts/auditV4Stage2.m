function audit = auditV4Stage2()
%AUDITV4STAGE2 Audit the common SF12 no-LDRO PHY only.
root = v4SetupPaths();
classes = {?V4IndependentChirpGoldenVectorTest,?V4GrayInterleaverGoldenVectorTest, ...
    ?V4NoLdroDimensionTest,?V4NoiseChannelMechanismTest};
suite = matlab.unittest.TestSuite.fromClass(classes{1});
for index = 2:numel(classes)
    suite = [suite matlab.unittest.TestSuite.fromClass(classes{index})]; %#ok<AGROW>
end
results = run(suite);
commonFiles = [dir(fullfile(root,'config','*.m')); ...
    dir(fullfile(root,'src','phy','*.m')); dir(fullfile(root,'src','coding','*.m'))];
forbidden = {'effectiveDataSf = 10','dataAlphabetSize,1024','dataBinSpacing,4', ...
    '10-by-7','ten LDRO','logicalBin*config.dataBinSpacing'};
violations = strings(0,1);
for fileIndex = 1:numel(commonFiles)
    content = fileread(fullfile(commonFiles(fileIndex).folder,commonFiles(fileIndex).name));
    for patternIndex = 1:numel(forbidden)
        if contains(content,forbidden{patternIndex})
            violations(end+1,1) = string(commonFiles(fileIndex).name)+":"+forbidden{patternIndex}; %#ok<AGROW>
        end
    end
end
readonly = v4VerifyReadOnlySources(root);
passed = all([results.Passed]) && isempty(violations) && readonly.passed;
audit = struct('stage','STAGE_02_COMMON_PHY_AUDIT','overall',localStatus(passed), ...
    'planVersion','V4-noLDRO-plan-R3-project-aligned', ...
    'timestampUtc',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX')), ...
    'items',struct('independentGoldenVectors',localStatus(all([results.Passed])), ...
        'activeNoLdroScan',localStatus(isempty(violations)), ...
        'sourceBoundary',localStatus(readonly.passed), ...
        'calibration','NOT_APPLICABLE','validation','NOT_APPLICABLE', ...
        'smoke','NOT_APPLICABLE','formal','NOT_APPLICABLE'), ...
    'testNames',{string({results.Name})},'testPassed',[results.Passed], ...
    'forbiddenPatternViolations',violations,'sourceFileCount',readonly.fileCount, ...
    'commands',{{'auditV4Stage2'}}, ...
    'admission',ternary(passed,'ADMIT_STAGE_3','DO_NOT_ADMIT_STAGE_3'));
v4WriteAuditEvidence(root,audit.stage,audit);
if ~passed, error('V4:Stage2Audit','Stage 2 audit did not pass.'); end
end

function value = localStatus(ok)
if ok, value = 'PASS'; else, value = 'FAIL'; end
end
function value = ternary(condition,a,b)
if condition, value = a; else, value = b; end
end
