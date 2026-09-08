function report = run_stage12_ber_smoke()
%RUN_STAGE12_BER_SMOKE Four-arm fair BER interface smoke experiment.
%   Small sample only: validates wiring before the final error-target BER run.
root = fileparts(mfilename('fullpath')); resultDir = fullfile(root,'results','stage12_ber_smoke');
if ~isfolder(resultDir), mkdir(resultDir); end
c = satelliteFig3Config(); [w,~] = satelliteFig3VisibilityWindow(c);
snrGrid = (-24:2:-14).'; nFrames = 8; names = {'AWGN ideal','Doppler no comp','Static 8-preamble','SenLoRa virtual pilot'};
err = zeros(numel(snrGrid),4); bits = zeros(numel(snrGrid),1);
for s = 1:numel(snrGrid)
 for f = 1:nFrames
  seed=2026081300+100*s+f; p=satelliteFig3GeneratePayload(c,seed); bins=[zeros(c.bootstrapPilotCount,1);p.symbolBins];
  [rx,tx,truth]=generateContinuousSatelliteFrame(bins,c,StartTimeSec=w.deltaTimeInSec,SampleSnrDb=snrGrid(s),NoiseSeed=seed+700000);
  noise=rx-tx.*exp(1i*truth.phaseRad); awgn=tx+noise;
  awgnSoft=satelliteFig3SenLoRaConfidence(awgn,c);
  hard=zeros(numel(bins),1); for k=1:numel(bins), d=satelliteFig3HardDecision(rx(k,:),c); hard(k)=d.waveformBin; end
  staticTracker=satelliteFig3RollingPilotTracker(rx,c,zeros(c.bootstrapPilotCount,1)); staticSoft=satelliteFig3SenLoRaConfidence(staticTracker.compensatedSymbols,c);
  trusted=satelliteFig3TrustedConfidenceDecode(rx,c,zeros(c.bootstrapPilotCount,1));
  ref=p.dataBits; decoded={awgnSoft.decodedDataBits,satelliteFig3HardPayloadBits(hard(c.bootstrapPilotCount+1:end),c),staticSoft.decodedDataBits,trusted.finalSoft.decodedDataBits};
  for m=1:4, err(s,m)=err(s,m)+sum(decoded{m}(:)~=ref(:)); end
  bits(s)=bits(s)+numel(ref);
 end
end
ber=err./bits; T=table(snrGrid,bits,err(:,1),err(:,2),err(:,3),err(:,4),ber(:,1),ber(:,2),ber(:,3),ber(:,4));
writetable(T,fullfile(resultDir,'ber_smoke.csv')); save(fullfile(resultDir,'ber_smoke.mat'),'T','c','snrGrid','nFrames');
fig=figure('Visible','off','Color','w'); hold on; styles={'o-','s-','d-','^-'}; for m=1:4, semilogy(snrGrid,max(ber(:,m),0.5./bits),styles{m},'LineWidth',1.4,'MarkerSize',7); end
grid on; xlabel('SNR (dB)'); ylabel('BER'); title(sprintf('Four-arm BER smoke: %d frames/point',nFrames)); legend(names,'Location','southwest');
exportgraphics(fig,fullfile(resultDir,'ber_smoke.png'),'Resolution',180); savefig(fig,fullfile(resultDir,'ber_smoke.fig')); close(fig);
report=struct('resultDir',resultDir,'table',T); fprintf('Stage 12 BER smoke: %s\n',resultDir);
end
