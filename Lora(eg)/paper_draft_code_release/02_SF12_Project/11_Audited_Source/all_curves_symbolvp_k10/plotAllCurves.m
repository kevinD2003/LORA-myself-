function outputPaths = plotAllCurves(cohort, options)
%PLOTALLCURVES Full SNR and half-orbit curves from validated packet evidence.
% Aggregation must run first. Each cohort stays in its own output directory.
arguments
    cohort (1,1) string {mustBeMember(cohort,["validation100","formal1000"])} = "validation100"
    options.Metric (1,1) string {mustBeMember(options.Metric,["preFecHardSer","decodedBer","both"])} = "both"
    options.AllowPartial (1,1) logical = false
    options.OutputDirectory (1,1) string = ""
end
root = fileparts(mfilename('fullpath'));
aggregateDirectory = fullfile(root,'results',cohort,'analysis');
statusPath = fullfile(aggregateDirectory,'AGGREGATE_MANIFEST.json');
assert(isfile(statusPath),'AllCurvesPlot:MissingAggregate','Run analysis/all_curves_aggregate.py for this cohort first.');
status = jsondecode(fileread(statusPath));
assert(strcmp(status.cohort,cohort),'AllCurvesPlot:Cohort','Aggregate cohort mismatch.');
assert(status.complete || options.AllowPartial,'AllCurvesPlot:Incomplete', ...
    'All 100 points must validate before final plotting. AllowPartial=true creates visibly pending plots.');
metricPath = fullfile(aggregateDirectory,'ALL_CURVES_METRICS.csv');
assert(isfile(metricPath),'AllCurvesPlot:NoData','There are no valid packet observations to plot.');
if isfield(status,'metricCsvSha256')
    assert(strcmp(localSha256(metricPath),status.metricCsvSha256),'AllCurvesPlot:ChangedCsv','Aggregate CSV changed; reaggregate before plotting.');
end
data = readtable(metricPath,'TextType','string','VariableNamingRule','preserve');
assert(all(data.cohort==cohort),'AllCurvesPlot:MixedCohort','Mixed packet budgets in aggregate data.');
budget = 100;
if cohort=="formal1000", budget=1000; end
assert(all(localNumeric(data.plannedPackets)==budget),'AllCurvesPlot:Budget','Unexpected fixed packet budget.');
if options.OutputDirectory==""
    outputDirectory = fullfile(aggregateDirectory,'figures');
else
    outputDirectory = options.OutputDirectory;
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
metrics = ["preFecHardSer","decodedBer"];
if options.Metric~="both", metrics=options.Metric; end
outputPaths = strings(0,1);
for metric = metrics
    methods = ["prec","vp","paper","idealNative","idealPaper"];
    labels = ["PREC (native frame)","V8 SymbolVP / RollingN, N=8 (native frame)", ...
        "Reproduced paper method (midamble frame)","IdealNative (native frame)","IdealPaper (midamble frame)"];
    if metric=="decodedBer"
        methods=methods(1:3); labels=labels(1:3);
        yLabel='Decoded information-bit BER';
    else
        yLabel='Pre-FEC hard FFT chirp SER';
    end
    for sf = [7 12]
        for channel = ["AWGN","Rician"]
            for family = ["case1","case2","half"]
                selected = data(data.sf==sf & data.channel==channel & data.family==family & data.metric==metric,:);
                expectedPoints=10;
                if family=="half", expectedPoints=5; end
                if ~options.AllowPartial
                    assert(height(selected)==expectedPoints*numel(methods),'AllCurvesPlot:Rows','A full curve/method is missing.');
                end
                if isempty(selected), continue; end
                fig = figure('Visible','off','Color','w','Position',[100 100 1160 780]);
                cleanup=onCleanup(@()close(fig));
                ax=axes(fig,'Position',[.095 .25 .865 .62]); hold(ax,'on');
                colors=[.00 .36 .70; .85 .34 .08; .45 .22 .61; .10 .55 .28; .30 .30 .30];
                markers={'o','s','d','^','x'};
                anyZero=false;
                allPositive=[];
                for methodIndex=1:numel(methods)
                    rows=selected(selected.method==methods(methodIndex),:);
                    if isempty(rows), continue; end
                    if family=="half", x=localNumeric(rows.orbitStartSec); else, x=localNumeric(rows.snrDb); end
                    [x,order]=sort(x); rows=rows(order,:);
                    assert(numel(unique(x))==height(rows),'AllCurvesPlot:Duplicate','Duplicate x coordinate for a method.');
                    rate=localNumeric(rows.rate); low=localNumeric(rows.ciLow); high=localNumeric(rows.ciHigh);
                    assert(all(isfinite(rate)&rate>=0&rate<=1&isfinite(low)&low>=0&low<=rate&isfinite(high)&high>=rate&high<=1), ...
                        'AllCurvesPlot:Interval','Invalid measured rate/interval.');
                    style='-';
                    if methods(methodIndex)=="idealNative", style='--'; end
                    if methods(methodIndex)=="idealPaper", style=':'; end
                    localCurve(ax,x,rate,low,high,colors(methodIndex,:),markers{methodIndex},style,labels(methodIndex));
                    anyZero=anyZero||any(rate==0);
                    allPositive=[allPositive;rate(rate>0);high(high>0)]; %#ok<AGROW>
                end
                set(ax,'YScale','log','FontSize',12,'TickLabelInterpreter','none');
                grid(ax,'on'); ax.YMinorGrid='on'; ax.GridAlpha=.2;
                ylabel(ax,yLabel); legend(ax,'Location','best','FontSize',9,'Interpreter','none');
                if family=="half"
                    xlabel(ax,'Orbit start time t_0 (s)');
                    xticks(ax,[-366 -274.5 -183 -91.5 0]); xlim(ax,[-380 14]);
                    familyTitle=sprintf('Half orbit | E_s/N_0 = %g dB',localNumeric(selected.esN0Db(1)));
                else
                    xlabel(ax,'SNR per complex sample (dB)');
                    if sf==7, limits=[-15 -6]; else, limits=[-30 -21]; end
                    xticks(ax,limits(1):limits(2)); xlim(ax,limits+[-.25 .25]);
                    if family=="case1", caseNumber=1; start=-366; else, caseNumber=2; start=0; end
                    familyTitle=sprintf('Case %d | t_0 = %g s',caseNumber,start);
                end
                if ~isempty(allPositive)
                    lowerLimit=max(realmin,10^floor(log10(min(allPositive)*.55)));
                    upperLimit=min(1,10^ceil(log10(max(allPositive)*1.15)));
                    if upperLimit<=lowerLimit, upperLimit=min(1,lowerLimit*10); end
                    ylim(ax,[lowerLimit upperLimit]);
                end
                pending="";
                if ~status.complete, pending="PENDING | "; end
                title(ax,{sprintf('%s%s | SF%d | %s | %s',pending,cohort,sf,channel,familyTitle), ...
                    sprintf('%d packets/point; CR3; 112 data chirps; no LDRO',budget)},'FontWeight','bold','Interpreter','none');
                paperRows=129;
                if sf==12, paperRows=157; end
                channelText='AWGN';
                if channel=="Rician"
                    channelText='Rician K=10 dB; diffuse delays 8/16/24/32 us';
                end
                footer=sprintf('%s; native frame 120 rows; Paper frame %d rows. Packet bootstrap 95%% intervals.',channelText,paperRows);
                if anyZero
                    footer=[footer newline 'Open downward triangles show the conservative packet-level 95% upper bound for zero observed errors; measured rate is zero.'];
                end
                if metric=="decodedBer"
                    footer=[footer newline 'Decoded BER is reported separately from pre-FEC SER. Decoder failures count as all information bits in error.'];
                else
                    footer=[footer newline 'Each ideal retains its own frame timing and fading. No flat-fading theory curve is substituted.'];
                end
                annotation(fig,'textbox',[.06 .015 .91 .12],'String',footer,'EdgeColor','none', ...
                    'HorizontalAlignment','center','FontSize',9,'Interpreter','none','FitBoxToText','off');
                filename=sprintf('%s_sf%d_%s_%s_%s',cohort,sf,lower(channel),family,metric);
                png=fullfile(outputDirectory,[filename '.png']);
                exportgraphics(fig,png,'Resolution',180);
                exportgraphics(fig,fullfile(outputDirectory,[filename '.pdf']),'ContentType','vector');
                outputPaths(end+1,1)=string(png); %#ok<AGROW>
                clear cleanup;
            end
        end
    end
end
end

function localCurve(ax,x,rate,low,high,color,marker,style,label)
shown=rate; shown(rate==0)=NaN;
semilogy(ax,x,shown,'LineStyle',style,'Marker',marker,'Color',color, ...
    'LineWidth',1.6,'MarkerSize',6,'DisplayName',label);
positive=rate>0;
if any(positive)
    errorbar(ax,x(positive),rate(positive),rate(positive)-low(positive),high(positive)-rate(positive), ...
        'LineStyle','none','Color',color,'CapSize',5,'LineWidth',.8,'HandleVisibility','off');
end
zero=rate==0;
if any(zero)
    semilogy(ax,x(zero),high(zero),'v','LineStyle','none','Color',color, ...
        'MarkerFaceColor','none','MarkerSize',8,'LineWidth',1.2,'HandleVisibility','off');
end
end

function values=localNumeric(values)
if ~isnumeric(values), values=str2double(string(values)); end
values=values(:);
end

function digest=localSha256(path)
fid=fopen(path,'rb');
assert(fid>=0,'AllCurvesPlot:Read','Cannot read aggregate CSV.');
cleanup=onCleanup(@()fclose(fid));
bytes=fread(fid,Inf,'*uint8');
engine=java.security.MessageDigest.getInstance('SHA-256');
if ~isempty(bytes), engine.update(typecast(bytes(:),'int8')); end
digest=lower(reshape(dec2hex(typecast(engine.digest(),'uint8'),2).',1,[]));
end
