function report = exp1VerifyParentSmoke(results,config)
%EXP1VERIFYPARENTSMOKE Compare new wrapper errors to archived Unified V23 packets.

unifiedRoot = fullfile(config.parentRoot,'results','method_aligned', ...
    'unified_v16_test');
huangRoot = fullfile(config.parentRoot,'results','method_aligned', ...
    'huang_v9_test');
caseIndices = [1 2];
checks = true(2,6);
details = strings(2,6);
for endpoint = 1:2
    result = results{endpoint};
    folder = sprintf('snr_%+03d',config.parentEndpointSnrDb);
    unified = load(fullfile(unifiedRoot,sprintf('case%d',caseIndices(endpoint)), ...
        folder,'test_cell.mat'),'result');
    huang = load(fullfile(huangRoot,sprintf('case%d',caseIndices(endpoint)), ...
        folder,'test_cell.mat'),'result');
    n = result.packetCount;
    expectedSymbol = [double(huang.result.packetErrors(1:n,1)), ...
        double(unified.result.packetErrors(1:n,3,1)), ...
        double(unified.result.packetErrors(1:n,2,1))];
    expectedHard = [double(huang.result.packetErrors(1:n,2)), ...
        double(unified.result.packetErrors(1:n,3,2)), ...
        double(unified.result.packetErrors(1:n,2,2))];
    checks(endpoint,1:3) = all(double(result.symbolErrors(:,1:3)) == ...
        expectedSymbol,1);
    checks(endpoint,4:6) = all(double(result.hardBitErrors(:,1:3)) == ...
        expectedHard,1);
    for checkIndex = 1:6
        details(endpoint,checkIndex) = sprintf('endpoint%d-check%d=%d', ...
            endpoint,checkIndex,checks(endpoint,checkIndex));
    end
end
if all(checks,'all')
    status = 'PASS';
else
    status = 'FAIL';
end
report = struct('status',status,'checks',checks,'details',details, ...
    'packetsPerEndpoint',results{1}.packetCount, ...
    'snrDb',config.parentEndpointSnrDb);
path = fullfile(config.projectRoot,'audits','SMOKE_VALIDATION.md');
file = fopen(path,'w','n','UTF-8');
if file < 0
    error('EXP1:SmokeReportWrite','Cannot open %s.',path);
end
cleanup = onCleanup(@()fclose(file));
fprintf(file,'# Parent endpoint smoke validation\n\n');
fprintf(file,'Status: **%s**\n\n',status);
fprintf(file,'Compared %d packets per endpoint at %.2f dB.\n\n', ...
    results{1}.packetCount,config.parentEndpointSnrDb);
fprintf(file,['Huang V9, Paper V6 and Stage55 V16 symbol-error and ' ...
    'hard-bit-error counts were compared packet by packet against the ' ...
    'archived Unified V23 inputs.\n\n']);
for endpoint = 1:2
    fprintf(file,'- Endpoint %d: symbol checks [%d %d %d], hard checks [%d %d %d]\n', ...
        endpoint,checks(endpoint,:));
end
clear cleanup
end

