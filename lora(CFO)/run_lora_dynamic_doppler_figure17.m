function outputs = run_lora_dynamic_doppler_figure17(options)
%RUN_LORA_DYNAMIC_DOPPLER_FIGURE17 运行正式 Figure 17 动态 BER 扫描。
arguments
    options.OutputDirectory (1,1) string = string(pwd)
    options.Config (1,1) struct = lora_dynamic_doppler_figure17_config()
    options.RunExactValidation (1,1) logical = true
end
out = options.OutputDirectory; config = options.Config;
if ~isfolder(out), mkdir(out); end
paths = struct("results",fullfile(out,"dynamic_doppler_ber_results.csv"), ...
    "png",fullfile(out,"dynamic_doppler_ber_figure17.png"), ...
    "pdf",fullfile(out,"dynamic_doppler_ber_figure17.pdf"), ...
    "metadata",fullfile(out,"dynamic_doppler_ber_metadata.json"), ...
    "report",fullfile(out,"dynamic_doppler_ber_report.md"), ...
    "exact",fullfile(out,"dynamic_doppler_ber_exact_validation.csv"));
names = string({config.orbitScenarios.name});
results = load_existing_table(paths.results);
for scenario = names
    for sf = config.spreadingFactors
        for snrDb = config.snrDb
            if has_result_row(results, scenario, sf, snrDb)
                continue
            end
            raw = simulate_lora_dynamic_doppler_ber_point(config.profile, ...
                scenario,config.timeMode,config.dopplerModel,sf,snrDb,config);
            results = [results; struct2table(lora_dynamic_doppler_formalize_result(raw))]; %#ok<AGROW>
            writetable(results,paths.results);
        end
    end
end
results = sortrows(results,{'orbit_scenario','sf','snr_db'}); writetable(results,paths.results);
exactValidation = normalize_exact_table(load_existing_table(paths.exact), config);
if options.RunExactValidation
    for scenario = names
        for sf = [5 7 8 12]
            for snrDb = [-10 0 10]
                if has_result_row(exactValidation, scenario, sf, snrDb)
                    continue
                end
                paired = simulate_lora_dynamic_doppler_paired_point(scenario,sf,snrDb,config);
                exactValidation = [exactValidation; paired_row(scenario,sf,snrDb,paired)]; %#ok<AGROW>
                writetable(exactValidation,paths.exact);
            end
        end
    end
    writetable(exactValidation,paths.exact);
end
export_figure(results,config,paths.png,paths.pdf);
metadata = struct("profile",config.profile,"snr_grid_db",config.snrDb, ...
    "snr_grid_provenance",config.snrGridProvenance,"bandwidth_hz",config.bandwidthHz, ...
    "carrier_hz",config.geometry.configA.carrierFrequencyHz, ...
    "doppler_model",config.dopplerModel,"time_mode",config.timeMode, ...
    "target_bit_errors",config.targetBitErrors,"max_bits_per_point",config.maxBitsPerPoint, ...
    "no_interference",true,"doppler_compensation",false,"zero_error_ber","NaN");
fid=fopen(paths.metadata,"w","n","UTF-8"); fprintf(fid,"%s",jsonencode(metadata)); fclose(fid);
write_report(results,exactValidation,config,paths.report);
outputs = struct("results",results,"exactValidation",exactValidation, ...
    "resultsCsvPath",string(paths.results),"figurePngPath",string(paths.png), ...
    "figurePdfPath",string(paths.pdf),"metadataJsonPath",string(paths.metadata), ...
    "reportPath",string(paths.report),"exactValidationCsvPath",string(paths.exact));
end

function row=paired_row(scenario,sf,snr,paired)
row=table(scenario,sf,snr,paired.paper.ber,paired.exact.ber,paired.paper.ser,paired.exact.ser, ...
    paired.paper.bit_errors,paired.exact.bit_errors,paired.paper.total_bits, ...
    paired.exact.total_bits,paired.noiseless_fft_peak_equal,paired.fft_energy_relative_error, ...
    paired.max_doppler_error_hz,paired.rms_phase_error_rad,paired.difference_ber, ...
    paired.consistency_threshold,paired.statistically_consistent, ...
    paired.paper.seed_symbols,paired.paper.seed_noise, ...
    paired.exact.seed_symbols,paired.exact.seed_noise, ...
    'VariableNames',{'orbit_scenario','sf','snr_db','ber_piecewise','ber_exact','ser_piecewise','ser_exact','bit_errors_piecewise','bit_errors_exact','total_bits_piecewise','total_bits_exact','noiseless_fft_peak_equal','fft_energy_relative_error','max_doppler_error_hz','rms_phase_error_rad','abs_ber_difference','consistency_threshold','statistically_consistent','seed_symbols_piecewise','seed_noise_piecewise','seed_symbols_exact','seed_noise_exact'});
end

function existing = load_existing_table(path)
if isfile(path)
    imported = readtable(path, TextType="string");
    if isempty(imported)
        existing = table();
    else
        existing = imported;
    end
else
    existing = table();
end
end

function tf = has_result_row(results, scenario, sf, snrDb)
if isempty(results) || ~all(ismember(["orbit_scenario","sf","snr_db"], ...
        string(results.Properties.VariableNames)))
    tf = false;
    return
end
tf = any(string(results.orbit_scenario) == string(scenario) & ...
    results.sf == sf & results.snr_db == snrDb);
end

function exact = normalize_exact_table(exact, config)
if isempty(exact)
    return
end
requiredSeedNames = ["seed_symbols_piecewise", "seed_noise_piecewise", ...
    "seed_symbols_exact", "seed_noise_exact"];
for name = requiredSeedNames
    if ~ismember(name, string(exact.Properties.VariableNames))
        exact.(name) = zeros(height(exact), 1);
    end
end
for rowIndex = 1:height(exact)
    [seedSymbols, seedNoise] = paired_seeds( ...
        string(exact.orbit_scenario(rowIndex)), exact.sf(rowIndex), ...
        exact.snr_db(rowIndex), config);
    exact.seed_symbols_piecewise(rowIndex) = seedSymbols;
    exact.seed_noise_piecewise(rowIndex) = seedNoise;
    exact.seed_symbols_exact(rowIndex) = seedSymbols;
    exact.seed_noise_exact(rowIndex) = seedNoise;
end
if all(ismember(["abs_ber_difference","consistency_threshold", ...
        "statistically_consistent"], ...
        string(exact.Properties.VariableNames)))
    exact.statistically_consistent = ...
        exact.abs_ber_difference <= exact.consistency_threshold;
end
end

function [seedSymbols, seedNoise] = paired_seeds(scenario, sf, snrDb, config)
names = string({config.orbitScenarios.name});
scenarioIndex = find(names == string(scenario), 1);
snrIndex = round(10*(snrDb + 100));
seedSymbols = config.baseSeedSymbols + 700000 + ...
    10000*scenarioIndex + 100*sf + snrIndex;
seedNoise = config.baseSeedNoise + 700000 + ...
    10000*scenarioIndex + 100*sf + snrIndex;
end

function export_figure(results,config,pngPath,pdfPath)
f=figure(Visible="off",Color="white",Position=[100 100 1400 580]); c=onCleanup(@()close(f)); t=tiledlayout(f,1,2,TileSpacing="compact");
scenarios=["high_doppler_rate","high_doppler_shift"]; titles=["(a) High Doppler Rate","(b) High Doppler Shift"]; colors=lines(numel(config.spreadingFactors));
for p=1:2
    ax=nexttile(t,p); hold(ax,"on");
    for q=1:numel(config.spreadingFactors)
        r=sortrows(results(string(results.orbit_scenario)==scenarios(p) & results.sf==config.spreadingFactors(q),:),"snr_db");
        shown=r.ber; zero=isnan(shown); shown(zero)=r.upper_95_approx(zero);
        semilogy(ax,r.snr_db,shown,"-o",Color=colors(q,:),DisplayName=sprintf("SF%d",config.spreadingFactors(q)));
        if any(zero), semilogy(ax,r.snr_db(zero),shown(zero),"v",Color=colors(q,:),MarkerFaceColor="white",HandleVisibility="off"); end
    end
    grid(ax,"on"); xlabel(ax,"SNR (dB)"); ylabel(ax,"BER"); title(ax,titles(p)); legend(ax,Location="southwest",NumColumns=2); ylim(ax,[1e-9 1]);
end
sgtitle(t,"Raw Monte Carlo; no interference; no Doppler compensation"); exportgraphics(f,pngPath,Resolution=200); exportgraphics(f,pdfPath,ContentType="vector"); clear c
end

function write_report(results,paired,config,path)
fid=fopen(path,"w","n","UTF-8"); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,"%s\n\n",u8([35,32,70,105,103,117,114,101,32,49,55,32,230,173,163,229,188,143,229,138,168,230,128,129,32,68,111,112,112,108,101,114,32,66,69,82,32,230,138,165,229,145,138]));
fprintf(fid,"%s\n",u8([45,32,83,78,82,32,231,189,145,230,160,188,239,188,154,45,51,48,58,49,58,49,48,32,100,66,239,188,136,230,156,172,233,161,185,231,155,174,229,163,176,230,152,142,239,188,155,232,174,186,230,150,135,230,156,170,229,133,172,229,188,128,32,77,111,110,116,101,32,67,97,114,108,111,32,230,173,165,233,149,191,239,188,137,227,128,130]));
fprintf(fid,"%s%s%s\n",u8([45,32,228,184,187,230,168,161,229,158,139,239,188,154]),char(config.dopplerModel),u8([239,188,155,230,151,160,229,185,178,230,137,176,239,188,155,230,151,160,32,68,111,112,112,108,101,114,32,232,161,165,229,129,191,227,128,130]));
fprintf(fid,"%s%d%s\n",u8([45,32,228,184,187,32,67,83,86,32,229,142,159,229,167,139,231,130,185,230,149,176,239,188,154]),height(results),u8([227,128,130]));
fprintf(fid,"%s\n",u8([45,32,233,155,182,233,148,153,232,175,175,32,66,69,82,32,229,134,153,228,189,156,32,78,97,78,239,188,155,111,110,101,95,99,111,117,110,116,95,108,101,118,101,108,32,228,184,141,230,152,175,228,184,165,230,160,188,231,187,159,232,174,161,228,184,138,231,149,140,227,128,130]));
if ~isempty(paired)
    fprintf(fid,"%s%d%s%d%s\n",u8([45,32,101,120,97,99,116,32,230,138,189,230,159,165,231,130,185,230,149,176,239,188,154]),height(paired),u8([239,188,155,228,184,141,228,184,128,232,135,180,231,130,185,239,188,154]),nnz(~paired.statistically_consistent),u8([227,128,130]));
end
clear cleanup
end

function text = u8(bytes)
text = native2unicode(uint8(bytes),"UTF-8");
end

function write_report_legacy(results,paired,config,path) %#ok<DEFNU>
fid=fopen(path,"w","n","UTF-8"); fprintf(fid,"# Figure 17 正式动态 Doppler BER 报告\n\n");
fprintf(fid,"- SNR 网格：-30:1:10 dB（本项目声明，论文未公开 Monte Carlo 步长）。\n- 模型：%s；无干扰；无 Doppler 补偿。\n- 原始点数：%d。\n",config.dopplerModel,height(results));
fprintf(fid,"- 零错误 BER 写作 NaN；one_count_level 不是严格统计上界。\n");
if ~isempty(paired), fprintf(fid,"- exact 抽查点数：%d；不一致点：%d。\n",height(paired),nnz(~paired.statistically_consistent)); end
fclose(fid);
end
