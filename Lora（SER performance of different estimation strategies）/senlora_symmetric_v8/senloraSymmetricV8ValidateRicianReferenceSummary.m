function senloraSymmetricV8ValidateRicianReferenceSummary(summary,c)
%SENLORASYMMETRICV8VALIDATERICIANREFERENCESUMMARY Reject invalid plot inputs.
fields = {'caseIndex','snrDb','senloraSer','idealSer','exactNoDopplerRicianSer'};
values = summary{:,fields};
snr = (-30:-21).';
expectedKeys = [ones(10,1),snr;2*ones(10,1),snr];
if any(~isfinite(values),'all') || ...
        ~isequal(sortrows(summary{:,{'caseIndex','snrDb'}}),expectedKeys)
    error('EXP5V8:PaperReferenceSummary','Missing/nonfinite reference points.');
end
theory = senloraSymmetricV8RicianTheory(c.physicalSf,snr,c.ricianKDb);
expected = theory(summary.snrDb+31);
if any(abs(summary.exactNoDopplerRicianSer-expected)>1e-10)
    error('EXP5V8:PaperReferenceSummary','Reference theory differs from the frozen model.');
end
end
