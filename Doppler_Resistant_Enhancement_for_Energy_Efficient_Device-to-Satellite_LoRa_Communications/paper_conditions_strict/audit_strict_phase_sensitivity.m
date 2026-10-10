function result = audit_strict_phase_sensitivity()
%AUDIT_STRICT_PHASE_SENSITIVITY Diagnose Eq. (15) versus instantaneous CFO.
folder=strictPaperSetup();base=strictPaperConfig();orbit=drePaperOrbit(0,base);
duration=base.packetSymbolCount*base.symbolDurationSec;
starts=(-orbit.horizonTimeSec:duration:orbit.horizonTimeSec-duration).';
models={'paper-equation-15-product','integrated-instantaneous-doppler'};
row=0;phaseModel=strings(8,1);dopplerSign=zeros(8,1);snrDb=zeros(8,1);
adaptiveSerPercent=zeros(8,1);fixedSerPercent=zeros(8,1);
fixedCircularMeanSE=zeros(8,1);fixedAbsoluteMeanSE=zeros(8,1);
for model=1:2
    for sign=[1 -1]
        c=base;c.phaseModel=models{model};c.carrierFrequencyHz=sign*abs(base.carrierFrequencyHz);
        for snr=[Inf -20]
            row=row+1;phaseModel(row)=string(c.phaseModel);dopplerSign(row)=sign;snrDb(row)=snr;
            errors=zeros(1,2);absolute=0;circular=0;
            for packet=1:numel(starts)
                stream=RandStream('mt19937ar','Seed',base.randomSeed+packet);
                data=randi(stream,[0 4095],base.payloadSymbolCount,1);
                symbols=[zeros(8,1);data];
                raw=strictPaperRawBatch(symbols,starts(packet),snr,base.randomSeed+10000+packet,c);
                for method=1:2
                    modes={'adaptive','fixed'};
                    r=dreDecodeLinearRegressionBatch(raw,8,4096,modes{method});
                    mismatch=r.detectedSymbols~=data;errors(method)=errors(method)+sum(mismatch);
                    if method==2
                        absolute=absolute+sum(abs(r.detectedSymbols(mismatch)-data(mismatch)));
                        circular=circular+sum(dreCircularSymbolDistance( ...
                            r.detectedSymbols(mismatch),data(mismatch),4096));
                    end
                end
            end
            rates=100*errors/(numel(starts)*base.payloadSymbolCount);
            adaptiveSerPercent(row)=rates(1);fixedSerPercent(row)=rates(2);
            fixedCircularMeanSE(row)=circular/max(errors(2),1);
            fixedAbsoluteMeanSE(row)=absolute/max(errors(2),1);
            fprintf('Phase sensitivity %s sign=%+d SNR=%g: adaptive=%.4f fixed=%.4f\n', ...
                c.phaseModel,sign,snr,rates(1),rates(2));
        end
    end
end
summary=table(phaseModel,dopplerSign,snrDb,adaptiveSerPercent,fixedSerPercent, ...
    fixedCircularMeanSE,fixedAbsoluteMeanSE);
identity=strictPaperIdentity(base,'audit_strict_phase_sensitivity.m');
result=struct('status','DIAGNOSTIC_COMPLETE','table',summary,'identity',identity, ...
    'signature',dreConfigurationSignature(identity), ...
    'note','Sensitivity only; no parameter is selected by closeness to a target.');
output=fullfile(folder,'results','numerical_gap_audit');
save(fullfile(output,'phase_sensitivity.mat'),'result','-v7.3');
writetable(summary,fullfile(output,'phase_sensitivity.csv'));disp(summary);
end
