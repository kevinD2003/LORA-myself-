function audit = auditV3()
%AUDITV3 Unified final self-audit for source, tests, formal artifacts, and scope.

root = v3SetupPaths();
config = sf12Sf11FlowConfig();
[~,manifest] = v3LoadFrozenReceiverParameters(config);
testResults = runV3Tests();

groups = {'config','src\coding','src\phy','src\stage55', ...
    'src\paper','src\statistics','scripts','tests'};
codeAnalyzerIssues = 0;
scopeViolations = strings(0,1);
for group = 1:numel(groups)
    files = dir(fullfile(root,groups{group},'*.m'));
    for index = 1:numel(files)
        path = fullfile(files(index).folder,files(index).name);
        codeAnalyzerIssues = codeAnalyzerIssues+numel(checkcode(path,'-id'));
        content = fileread(path);
        if ~strcmp(files(index).name,'auditV3.m') && ( ...
                contains(content,'stage55_sf12_paper_conditions') || ...
                contains(content,'satellite_fig3_rolling8'))
            scopeViolations(end+1,1) = string(path); %#ok<AGROW>
        end
    end
end

sourceManifest = jsondecode(fileread(fullfile(root,'config','source_manifest.json')));
hashMismatch = strings(0,1);
for index = 1:numel(sourceManifest.files)
    path = fullfile(sourceManifest.copiedRoot,sourceManifest.files(index).file);
    if ~strcmp(localSha256(path),sourceManifest.files(index).copiedSha256)
        hashMismatch(end+1,1) = string(path); %#ok<AGROW>
    end
end

formal = load(fullfile(root,'results','formal','v3_formal_comparison_v2.mat'),'formal');
formalPointCount = numel(formal.formal.points);
completePassCounts = zeros(formalPointCount,1);
for index = 1:formalPointCount
    completePassCounts(index) = formal.formal.points{index}.completedPasses;
end
audit = struct('passed',all([testResults.Passed]) && codeAnalyzerIssues == 0 && ...
    isempty(scopeViolations) && isempty(hashMismatch) && formalPointCount == 10 && ...
    all(completePassCounts >= 5 & completePassCounts <= 20), ...
    'testPassed',sum([testResults.Passed]),'testFailed',sum([testResults.Failed]), ...
    'codeAnalyzerIssues',codeAnalyzerIssues, ...
    'scopeViolationFiles',scopeViolations,'frozenSourceHashMismatches',hashMismatch, ...
    'formalPointCount',formalPointCount,'completePassCounts',completePassCounts, ...
    'algorithmSignature',manifest.algorithmSignature, ...
    'paperBranchName','Paper-Midamble-Point-SF12-CR3-adapted', ...
    'usesOrbitPrior',false);
file = fopen(fullfile(root,'results','audit.json'),'w');
if file < 0, error('V3:AuditWrite','Cannot write audit JSON.'); end
cleanup = onCleanup(@()fclose(file));
fprintf(file,'%s\n',jsonencode(audit));
clear cleanup
if ~audit.passed
    error('V3:AuditFailure','Final V3 audit failed.');
end
end

function hash = localSha256(path)
digest = java.security.MessageDigest.getInstance('SHA-256');
file = fopen(path,'rb');
if file < 0, error('V3:HashRead','Cannot read %s.',path); end
cleanup = onCleanup(@()fclose(file));
bytes = fread(file,Inf,'*uint8');
clear cleanup
digest.update(typecast(bytes,'int8'));
hashBytes = typecast(digest.digest(),'uint8');
hash = lower(reshape(dec2hex(hashBytes,2).',1,[]));
end
