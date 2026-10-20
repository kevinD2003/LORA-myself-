function manifest=plotNkserResults()
%PLOTNKSERRESULTS Twelve complete SER figures plus PNG/PDF overview.
oldPath=path;restore=onCleanup(@()path(oldPath));roots=nkserSetup();
analysisDirectory=fullfile(roots.root,'results','formal1000','analysis');
statusPath=fullfile(analysisDirectory,'STATUS.json');
assert(isfile(statusPath),'NkSerPlot:MissingStatus','Run the formal aggregator first.');
status=jsondecode(fileread(statusPath));
assert(status.complete&&status.physicalPoints==100&&status.methodRows==500, ...
    'NkSerPlot:Incomplete','Validated 100-point SER evidence is required.');
metricPath=fullfile(analysisDirectory,'SER_500_METHOD_ROWS.csv');
endpointPath=fullfile(analysisDirectory,'ENDPOINT_24_ACCEPTANCE.csv');
data=readtable(metricPath,'TextType','string','VariableNamingRule','preserve');
endpoints=readtable(endpointPath,'TextType','string','VariableNamingRule','preserve');
assert(height(data)==500&&height(endpoints)==24&&all(data.packets==1000));
outputDirectory=fullfile(analysisDirectory,'figures');
if ~isfolder(outputDirectory),mkdir(outputDirectory);end

sfValues=[7 12];channels=["AWGN" "Rician"];families=["case1" "case2" "half"];
files=strings(0,1);figureCount=0;
for sf=sfValues
    for channel=channels
        for family=families
            fig=figure('Visible','off','Color','w','Position',[80 80 1160 780]);
            cleanup=onCleanup(@()close(fig));ax=axes(fig,'Position',[.09 .15 .87 .76]);
            drawPanel(ax,data,endpoints,sf,channel,family,true);
            filename=sprintf('ser_sf%d_%s_%s',sf,lower(channel),family);
            png=fullfile(outputDirectory,[filename '.png']);pdf=fullfile(outputDirectory,[filename '.pdf']);
            exportgraphics(fig,png,'Resolution',180);exportgraphics(fig,pdf,'ContentType','vector');
            files(end+1:end+2,1)=[string(png);string(pdf)]; %#ok<AGROW>
            figureCount=figureCount+1;clear cleanup;
        end
    end
end
assert(figureCount==12);

overview=figure('Visible','off','Color','w','Position',[20 20 2100 2200]);
cleanup=onCleanup(@()close(overview));layout=tiledlayout(overview,4,3, ...
    'TileSpacing','compact','Padding','compact');
row=0;
for sf=sfValues
    for channel=channels
        row=row+1;
        for family=families
            ax=nexttile(layout);drawPanel(ax,data,endpoints,sf,channel,family,false);
        end
    end
end
title(layout,{'Frozen AWGN + normalized K=10 Rician | pre-FEC hard-chirp SER', ...
    '1000 packets/point, 112 data chirps; PDF reference-read uncertainty is unquantified'}, ...
    'FontWeight','bold','FontSize',15,'Interpreter','none');
overviewPng=fullfile(outputDirectory,'SER_OVERVIEW_12.png');
overviewPdf=fullfile(outputDirectory,'SER_OVERVIEW_12.pdf');
exportgraphics(overview,overviewPng,'Resolution',180);
exportgraphics(overview,overviewPdf,'ContentType','vector');
files(end+1:end+2,1)=[string(overviewPng);string(overviewPdf)];clear cleanup;

records=cell(numel(files),1);
for k=1:numel(files)
    records{k}=struct('path',char(files(k)),'sha256',nkserHash(char(files(k))));
end
manifest=struct('status','COMPLETE','individualSerFigures',12,'berFigures',0, ...
    'overviewPng',overviewPng,'overviewPdf',overviewPdf,'files',vertcat(records{:}), ...
    'awgnTheory','exact noncoherent orthogonal FFT-bin SER', ...
    'ricianTheory','not plotted: packet-flat formula is not applicable to the registered causal multipath PDP', ...
    'referenceMarkers','fixed published-PDF vector reads; reading error interval not frozen');
writeText(fullfile(analysisDirectory,'FIGURE_MANIFEST.json'),jsonencode(manifest,PrettyPrint=true));
end

function drawPanel(ax,data,endpoints,sf,channel,family,fullSize)
selected=data(data.sf==sf&data.channel==channel&data.family==family,:);
expected=50;if family=="half",expected=25;end
assert(height(selected)==expected,'NkSerPlot:Rows','Incomplete curve.');hold(ax,'on');
methods=["prec" "vp" "paper" "idealNative" "idealPaper"];
labels=["PREC" "V8 Symbol-VP / Rolling-N8" "Reproduced paper method" "IdealNative" "IdealPaper"];
colors=[.00 .36 .70;.85 .34 .08;.45 .22 .61;.10 .55 .28;.25 .25 .25];
markers={'o','s','d','^','x'};styles={'-','-','-','--',':'};allPositive=[];
for k=1:5
    rows=selected(selected.method==methods(k),:);
    if family=="half",x=rows.orbitStartSec;else,x=rows.snrDb;end
    [x,order]=sort(x);rows=rows(order,:);rate=rows.rate;low=rows.ciLow;high=rows.ciHigh;
    shown=rate;shown(rate==0)=NaN;
    semilogy(ax,x,shown,'LineStyle',styles{k},'Marker',markers{k},'Color',colors(k,:), ...
        'LineWidth',1.35,'MarkerSize',5,'DisplayName',labels(k));
    positive=rate>0;
    if any(positive)
        errorbar(ax,x(positive),rate(positive),rate(positive)-low(positive),high(positive)-rate(positive), ...
            'LineStyle','none','Color',colors(k,:),'CapSize',3,'LineWidth',.65,'HandleVisibility','off');
    end
    zero=rate==0;
    if any(zero)
        semilogy(ax,x(zero),high(zero),'v','Color',colors(k,:),'MarkerFaceColor','none', ...
            'MarkerSize',7,'LineWidth',1,'HandleVisibility','off');
    end
    allPositive=[allPositive;rate(rate>0);high(high>0)]; %#ok<AGROW>
end
if channel=="AWGN"
    if family=="half"
        x=unique(selected.orbitStartSec);snr=unique(selected.snrDb);
        assert(numel(snr)==1);theory=repmat(senloraSymmetricV8AwgnTheory(sf,snr),numel(x),1);
    else
        x=unique(selected.snrDb);theory=senloraSymmetricV8AwgnTheory(sf,x);
    end
    semilogy(ax,x,theory,'-.','Color',[.05 .05 .05],'LineWidth',1.15, ...
        'DisplayName','AWGN single-chirp theory');
    allPositive=[allPositive;theory(theory>0)]; %#ok<AGROW>
end
reference=endpoints(endpoints.sf==sf&endpoints.channel==channel&endpoints.family==family,:);
assert(height(reference)==2);
for k=1:height(reference)
    if family=="half",x=reference.orbitStartSec(k);else,x=reference.snrDb(k);end
    target=reference.paperTargetSer(k);
    if reference.method(k)=="paper",marker='p';color=[.65 .05 .05];name='Paper method PDF read';
    else,marker='h';color=[.05 .05 .05];name='Paper ideal PDF read';end
    semilogy(ax,x,target,marker,'LineStyle','none','Color',color,'MarkerSize',9, ...
        'LineWidth',1.4,'MarkerFaceColor','none','DisplayName',name);
    allPositive=[allPositive;target]; %#ok<AGROW>
end
set(ax,'YScale','log','FontSize',9,'TickLabelInterpreter','none');grid(ax,'on');ax.YMinorGrid='on';
ylabel(ax,'Pre-FEC hard FFT chirp SER');
if family=="half"
    xlabel(ax,'Orbit start time t_0 (s)');xticks(ax,[-366 -274.5 -183 -91.5 0]);xlim(ax,[-380 14]);
    detail='half orbit, E_s/N_0=15 dB Rician / 14 dB AWGN';
else
    xlabel(ax,'SNR per complex sample (dB)');
    limits=[-15 -6];if sf==12,limits=[-30 -21];end
    xticks(ax,limits(1):limits(2));xlim(ax,limits+[-.25 .25]);
    start=-366;if family=="case2",start=0;end
    detail=sprintf('%s, t_0=%g s',family,start);
end
if ~isempty(allPositive)
    low=max(realmin,10^floor(log10(min(allPositive)*.55)));
    high=min(1,10^ceil(log10(max(allPositive)*1.2)));
    if high<=low,high=min(1,low*10);end
    ylim(ax,[low high]);
end
title(ax,sprintf('SF%d | %s | %s',sf,channel,detail),'FontWeight','bold','Interpreter','none');
if fullSize
    legend(ax,'Location','best','FontSize',8,'Interpreter','none');
    if channel=="Rician"
        subtitle(ax,'Normalized K=10 dB causal PDP; unit ensemble power; no margin/packet normalization');
    else
        subtitle(ax,'Frozen AWGN packet evidence; reused read-only');
    end
end
end

function writeText(file,content)
temporary=[file '.tmp'];fid=fopen(temporary,'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',content);clear cleanup;movefile(temporary,file,'f');
end
