function report = audit_strict_numerical_gaps()
%AUDIT_STRICT_NUMERICAL_GAPS Quantify seed uncertainty and CRC definitions.
folder=strictPaperSetup();
singleRun=load(fullfile(folder,'results','table_iv_v5_O1','table_iv.mat'),'result');
ensemble=load(fullfile(folder,'results','table_iv_v5_O32','table_iv.mat'),'result');
validation=load(fullfile(folder,'results','full_phy_v5_O8_Pall_S-10','full_phy.mat'),'result');
singleRun=singleRun.result;ensemble=ensemble.result;validation=validation.result;
for r={singleRun,ensemble}
    identity=strictPaperIdentity(r{1}.config,'run_strict_table_iv.m');
    assert(strcmp(r{1}.signature,dreConfigurationSignature(identity)));
end
identity=strictPaperIdentity(validation.config,'run_strict_full_phy.m');
assert(strcmp(validation.signature,dreConfigurationSignature(identity)));
assert(ensemble.overpasses==32 && ...
    isequal(singleRun.packetErrors(:,1,:,:),ensemble.packetErrors(:,1,:,:)));
snrDb=ensemble.table.snrDb;
method=strings(10,1);singlePassSer=zeros(10,1);ensembleSer=zeros(10,1);
meanLow95=zeros(10,1);meanHigh95=zeros(10,1);
singlePassLow95=zeros(10,1);singlePassHigh95=zeros(10,1);paperSer=zeros(10,1);
stream=RandStream('mt19937ar','Seed',91832000);row=0;
for si=1:5
    for mi=1:2
        row=row+1;names=["adaptive" "fixed"];method(row)=names(mi);
        perPass=100*reshape(sum(double(ensemble.packetErrors(:,:,mi,si)),1),[],1)/ ...
            (numel(ensemble.packetStartTimesSec)*ensemble.config.payloadSymbolCount);
        singlePassSer(row)=perPass(1);ensembleSer(row)=mean(perPass);
        resampled=perPass(randi(stream,32,32,2000));
        interval=prctile(mean(resampled,1),[2.5 97.5]);
        prediction=prctile(perPass,[2.5 97.5]);
        meanLow95(row)=interval(1);meanHigh95(row)=interval(2);
        singlePassLow95(row)=prediction(1);singlePassHigh95(row)=prediction(2);
        if mi==1,paperSer(row)=ensemble.config.paperAdaptiveSerPercent(si);
        else,paperSer(row)=ensemble.config.paperFixedSerPercent(si);end
    end
end
snrDb=repelem(snrDb,2);
meanDelta=ensembleSer-paperSer;
withinSinglePassRange=paperSer>=singlePassLow95 & paperSer<=singlePassHigh95;
tableIv=table(snrDb,method,singlePassSer,ensembleSer,paperSer,meanDelta, ...
    meanLow95,meanHigh95,singlePassLow95,singlePassHigh95,withinSinglePassRange);
phy=validation.table;
report=struct('status','NUMERICAL_GAPS_QUANTIFIED', ...
    'tableIvOverpasses',32,'tableIvPacketsPerSnr',32*182, ...
    'tableIvTable',tableIv,'fullPhyValidationTable',phy, ...
    'sourceSignatures',{{singleRun.signature,ensemble.signature,validation.signature}}, ...
    'crcAccountingVerified',true,'nativeReferenceEquivalenceVerified',true, ...
    'numericalAgreementClaimed',false, ...
    'remainingAssumptions',{{'N=8; the paper does not specify N', ...
        'periodic Hann; magnitude centroid offsets -4:5', ...
        '32-byte payload, six code blocks, padding and header details', ...
        'cyclic FFT unwrapping; literal product phase in Eq. (15)'}}, ...
    'interpretation',['An ensemble measures Monte Carlo variation, not author-source identity. ' ...
        'CRC-success BER and all-packet BER are retained separately. ' ...
        'No parameter or metric is fitted to the published result.']);
phasePath=fullfile(folder,'results','numerical_gap_audit','phase_sensitivity.mat');
if isfile(phasePath)
    sensitivity=load(phasePath,'result');
    current=strictPaperIdentity(baseConfig(singleRun),'audit_strict_phase_sensitivity.m');
    assert(strcmp(sensitivity.result.signature,dreConfigurationSignature(current)));
    report.phaseSensitivitySignature=sensitivity.result.signature;
    report.phaseSensitivityPerformed=true;
end
output=fullfile(folder,'results','numerical_gap_audit');
if ~isfolder(output),mkdir(output);end
save(fullfile(output,'numerical_gaps.mat'),'report','-v7.3');
writetable(tableIv,fullfile(output,'table_iv_uncertainty.csv'));
writetable(phy,fullfile(output,'crc_accounting_comparison.csv'));
json=rmfield(report,{'tableIvTable','fullPhyValidationTable'});
file=fopen(fullfile(output,'numerical_gaps.json'),'w','n','UTF-8');
closer=onCleanup(@()fclose(file));fprintf(file,'%s\n',jsonencode(json,'PrettyPrint',true));
disp(tableIv);
end

function c=baseConfig(result)
c=strictPaperConfig();
assert(result.config.bandwidthHz==c.bandwidthHz);
end
