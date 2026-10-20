function manifest=plotFullGrid()
%PLOTFULLGRID Plot six SER-only panels from the fixed 50-point evidence.
oldPath=path;restore=onCleanup(@()path(oldPath));root=fileparts(mfilename('fullpath'));
analysis=fullfile(root,'results','full1000','analysis');
file=fullfile(analysis,'NORMALIZED_K10_FULL1000_SER.csv');
assert(isfile(file),'Nk10:MissingGrid','Run theory/generate_full_grid.py first.');
tableData=readtable(file,'TextType','string');
assert(height(tableData)==50&&all(tableData.packets==1000),'Nk10:Grid','Expected 50 points x 1000 packets.');
figures=fullfile(analysis,'figures');if ~isfolder(figures),mkdir(figures);end
sfValues=[7 12];families=["case1" "case2" "half"];
entries=cell(6,1);entryIndex=0;
combined=figure('Visible','off','Color','w','Position',[80 80 1800 1120]);
layout=tiledlayout(combined,2,3,'TileSpacing','compact','Padding','compact');
for sf=sfValues
    for family=families
        entryIndex=entryIndex+1;ax=nexttile(layout);drawPanel(ax,tableData,sf,family);
        single=figure('Visible','off','Color','w','Position',[80 80 880 660]);
        singleAx=axes(single);drawPanel(singleAx,tableData,sf,family);
        base=sprintf('SF%d_RICIAN_%s_SER',sf,upper(char(family)));
        png=fullfile(figures,[base '.png']);pdf=fullfile(figures,[base '.pdf']);
        exportgraphics(single,png,'Resolution',180);exportgraphics(single,pdf,'ContentType','vector');close(single);
        entries{entryIndex}=struct('sf',sf,'family',char(family),'png',png,'pdf',pdf);
    end
end
title(layout,{ ...
    'Normalized K=10 Rician, unit power, no link margin — pre-FEC hard-chirp SER', ...
    'Shading: causal boundary SER bracket; independent 1000-packet samples per point; no BER'}, ...
    'FontSize',14);
combinedPng=fullfile(analysis,'NORMALIZED_K10_FULL1000_SER.png');
combinedPdf=fullfile(analysis,'NORMALIZED_K10_FULL1000_SER.pdf');
exportgraphics(combined,combinedPng,'Resolution',180);exportgraphics(combined,combinedPdf,'ContentType','vector');close(combined);
manifest=struct('status','PASS','sourceCsv',file,'combinedPng',combinedPng, ...
    'combinedPdf',combinedPdf,'figures',{vertcat(entries{:})},'figureCount',6, ...
    'metric','pre-FEC-hard-chirp-SER-only','berFigures',0);
writeText(fullfile(analysis,'FIGURES.json'),jsonencode(manifest));disp(jsonencode(manifest));
end

function drawPanel(ax,data,sf,family)
if family=="half"
    mask=data.sf==sf & data.family=="half";x=data.orbitStartSec(mask);
    xName='Orbit time (s), nominal E_s/N_0=15 dB';titleName=sprintf('SF%d half-orbit',sf);
else
    caseIndex=str2double(extractAfter(family,"case"));
    mask=data.sf==sf & data.family=="case" & data.caseIndex==caseIndex;x=data.snrDb(mask);
    xName='Nominal SNR (dB)';titleName=sprintf('SF%d Case%d',sf,caseIndex);
end
low=data.lowerSer(mask);high=data.upperSer(mask);theory=data.cyclicTheorySer(mask);
paper=data.paperIdealSer(mask);floorValue=data.displayFloor(mask);
[x,order]=sort(x);low=low(order);high=high(order);theory=theory(order);paper=paper(order);floorValue=floorValue(order);
plotLow=max(low,floorValue);plotHigh=max(high,floorValue);hold(ax,'on');
fill(ax,[x;flipud(x)],[plotLow;flipud(plotHigh)],[.30 .58 .82], ...
    'FaceAlpha',.20,'EdgeColor','none','DisplayName','Causal boundary bracket');
semilogy(ax,x,plotHigh,'o-','Color',[0 .35 .68],'LineWidth',1.4,'MarkerSize',5, ...
    'DisplayName','Conservative causal upper SER');
semilogy(ax,x,max(theory,floorValue),'k-','LineWidth',1.8,'DisplayName','Cyclic analytic theory');
if family=="half",endpoint=find(x==0,1);else,endpoint=numel(x);end
semilogy(ax,x(endpoint),paper(endpoint),'p','MarkerSize',11,'MarkerFaceColor',[.82 .22 .12], ...
    'MarkerEdgeColor',[.55 .08 .04],'DisplayName','Paper ideal endpoint');
grid(ax,'on');ax.YScale='log';xlabel(ax,xName);ylabel(ax,'SER');title(ax,titleName);
legend(ax,'Location','best','FontSize',8);box(ax,'on');
end

function writeText(file,content)
tmp=[file '.tmp'];fid=fopen(tmp,'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',content);clear cleanup;movefile(tmp,file,'f');
end
