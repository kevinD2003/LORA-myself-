function report=runIdealEndpointSmoke(packets)
%RUNIDEALENDPOINTSMOKE V4 native/Paper ideal hard-SER smoke; no FEC/BER.
arguments
    packets (1,1) double {mustBeInteger,mustBePositive}=20
end
oldPath=path;restore=onCleanup(@()path(oldPath));nk10Setup();
paper=[.002583154001145438 .002239810615533604 ...
    .01032408321335461 .009566141994319557];
sfValues=[7 7 12 12];families=["case" "half" "case" "half"];
snr=[-6 15-10*log10(128) -21 15-10*log10(4096)];
startSec=[-366 0 -366 0];nativeErrors=zeros(1,4);paperErrors=zeros(1,4);
failures=zeros(1,4);
for point=1:4
    sf=sfValues(point);config=nk10Config(sf);c=config.parent;
    for packet=1:packets
        seed=4082000000+point*100000+packet*8;
        seeds=struct('payloadSeed',seed,'noiseSeed',seed+1, ...
            'channelSeed',seed+2,'paperExtraNoiseSeed',seed+3);
        try
            pair=nk10GeneratePair(config,startSec(point),snr(point),seeds);
            truth=pair.native.truth.payloadPhysicalBins(:);
            native=prefecNativeHardDetect(pair.nativeIdeal.rxPhysical( ...
                pair.native.observation.layout.dataRows,:),c);
            paperResult=prefecNativeHardDetect(pair.pilotIdeal.rxPhysical( ...
                pair.pilot.observation.layout.dataRows,:),c);
            nativeErrors(point)=nativeErrors(point)+nnz(native.detectedPhysicalBins(:)~=truth);
            paperErrors(point)=paperErrors(point)+nnz(paperResult.detectedPhysicalBins(:)~=truth);
        catch problem
            failures(point)=failures(point)+1;
            nativeErrors(point)=nativeErrors(point)+112;
            paperErrors(point)=paperErrors(point)+112;
            fprintf(2,'%s point %d packet %d: %s\n',problem.identifier,point,packet,problem.message);
        end
    end
end
denominator=112*packets;nativeSer=nativeErrors/denominator;paperSer=paperErrors/denominator;
rows=cell(4,1);
for point=1:4
    rows{point}=struct('sf',sfValues(point),'family',families(point), ...
        'snrDb',snr(point),'packets',packets,'nativeErrors',nativeErrors(point), ...
        'nativeSer',nativeSer(point),'paperErrors',paperErrors(point), ...
        'paperSer',paperSer(point),'paperReference',paper(point), ...
        'paperRatio',paperSer(point)/paper(point),'failures',failures(point));
end
rows=vertcat(rows{:});
report=struct('status','SMOKE_ONLY_NOT_ACCEPTANCE','rows',rows, ...
    'kDb',10,'ensembleTotalPower',1,'linkMarginDb',0,'noBer',true);
disp(jsonencode(report));
end

