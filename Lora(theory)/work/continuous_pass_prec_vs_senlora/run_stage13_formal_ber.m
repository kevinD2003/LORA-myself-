function report = run_stage13_formal_ber(options)
%RUN_STAGE13_FORMAL_BER Checkpointed four-arm BER, no fitted smoothing.
arguments
 options.SnrGridDb (:,1) double = (-30:1:10).'
 options.MinBitErrors (1,1) double = 300
 options.MaxBitsPerPoint (1,1) double = 1e7
 options.Resume (1,1) logical = true
end
root=fileparts(mfilename('fullpath')); out=fullfile(root,'results','stage13_formal_ber'); if ~isfolder(out),mkdir(out);end
checkpoint=fullfile(out,'formal_ber_checkpoint.mat'); c=satelliteFig3Config(); [w,~]=satelliteFig3VisibilityWindow(c); names={'AWGN ideal','Doppler no comp','Static 8-preamble','SenLoRa virtual pilot'}; n=numel(options.SnrGridDb);
if options.Resume && isfile(checkpoint), load(checkpoint,'errors','bits','completed','frameOffset'); else, errors=zeros(n,4); bits=zeros(n,1); completed=false(n,1); frameOffset=zeros(n,1); end
for s=1:n
 if completed(s),continue,end
 while bits(s)<options.MaxBitsPerPoint && any(errors(s,:)<options.MinBitErrors)
  frameOffset(s)=frameOffset(s)+1; seed=2026081400+100000*s+frameOffset(s); p=satelliteFig3GeneratePayload(c,seed); labels=[zeros(c.bootstrapPilotCount,1);p.symbolBins];
  [rx,tx,truth]=generateContinuousSatelliteFrame(labels,c,StartTimeSec=w.deltaTimeInSec,SampleSnrDb=options.SnrGridDb(s),NoiseSeed=seed+700000);
  noise=rx-tx.*exp(1i*truth.phaseRad); awgnSoft=satelliteFig3SenLoRaConfidence(tx+noise,c);
  hard=zeros(numel(labels),1); for k=1:numel(labels),d=satelliteFig3HardDecision(rx(k,:),c);hard(k)=d.waveformBin;end
  stat=satelliteFig3RollingPilotTracker(rx,c,zeros(c.bootstrapPilotCount,1)); statSoft=satelliteFig3SenLoRaConfidence(stat.compensatedSymbols,c);
  trusted=satelliteFig3TrustedConfidenceDecode(rx,c,zeros(c.bootstrapPilotCount,1)); decoded={awgnSoft.decodedDataBits,satelliteFig3HardPayloadBits(hard(c.bootstrapPilotCount+1:end),c),statSoft.decodedDataBits,trusted.finalSoft.decodedDataBits};
  for m=1:4, errors(s,m)=errors(s,m)+sum(decoded{m}(:)~=p.dataBits(:));end; bits(s)=bits(s)+numel(p.dataBits);
  if mod(frameOffset(s),50)==0, save(checkpoint,'errors','bits','completed','frameOffset','options','c'); end
 end
 completed(s)=true; save(checkpoint,'errors','bits','completed','frameOffset','options','c'); localWrite(out,options.SnrGridDb,errors,bits,names);
end
T=localWrite(out,options.SnrGridDb,errors,bits,names); report=struct('resultDir',out,'table',T,'completed',completed); fprintf('Stage 13 formal BER: %s\n',out);
end
function T=localWrite(out,snr,errors,bits,names)
ber=errors./bits; upper=-log(0.05)./bits; shown=ber; upperMatrix=repmat(upper,1,4); shown(errors==0)=upperMatrix(errors==0);
T=table(snr,bits,errors(:,1),errors(:,2),errors(:,3),errors(:,4),shown(:,1),shown(:,2),shown(:,3),shown(:,4), ...
 'VariableNames',{'snrDb','bits','errAwgn','errNoComp','errStatic','errSenLoRa','berAwgn','berNoComp','berStatic','berSenLoRa'}); writetable(T,fullfile(out,'formal_ber.csv'));
fig=figure('Visible','off','Color','w'); hold on; st={'o-','s-','d-','^-'}; for m=1:4,semilogy(snr,shown(:,m),st{m},'LineWidth',1.3,'MarkerSize',6);end; set(gca,'YScale','log','YTick',10.^(-6:0)); grid on; ylim([1e-6 1]); xlabel('SNR (dB)');ylabel('BER');title('Formal BER: raw Monte Carlo / 95% zero-error upper bounds');legend(names,'Location','southwest'); exportgraphics(fig,fullfile(out,'formal_ber.png'),'Resolution',180);savefig(fig,fullfile(out,'formal_ber.fig'));close(fig);
end
