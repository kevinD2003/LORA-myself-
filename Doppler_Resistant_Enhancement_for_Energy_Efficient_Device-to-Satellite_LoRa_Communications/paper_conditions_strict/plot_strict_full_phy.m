function paths = plot_strict_full_phy(result,output)
%PLOT_STRICT_FULL_PHY Render frozen results independently of simulations.
paths=strings(0,1);
for cr=[1 4]
    selected=find([result.conditions.cr]==cr & [result.conditions.snrDb]==-10,1);
    if isempty(selected),continue;end
    cellResult=result.conditions(selected);
    fig=figure('Visible','off','Color','w','Position',[100 100 1080 620]);
    axisHandle=axes(fig);yyaxis(axisHandle,'left');hold(axisHandle,'on');
    displayBer=cellResult.trajectoryBer;displayBer(displayBer==0)=1e-5;
    first=plot(axisHandle,0:cellResult.packetCount-1,displayBer(:,1), ...
        '-','LineWidth',1.5);
    second=plot(axisHandle,0:cellResult.packetCount-1,displayBer(:,2), ...
        '--','LineWidth',1.5);
    set(axisHandle,'YScale','log');
    ylabel(axisHandle,'Coded BER, CRC-success packets');
    ylim(axisHandle,[1e-5 1]);grid(axisHandle,'on');
    yyaxis(axisHandle,'right');
    third=plot(axisHandle,0:cellResult.packetCount-1,cellResult.dopplerHz/1000, ...
        '-','LineWidth',1.2);ylabel(axisHandle,'Doppler frequency (kHz)');
    xlabel(axisHandle,'Sampled packet index');
    title(axisHandle,sprintf('%s: direct IQ, CR%d, -10 dB, %d overpasses', ...
        result.status,cr,cellResult.overpasses),'Interpreter','none');
    legend(axisHandle,[first second third], ...
        {'Adaptive LR','Fixed LR','Doppler'},'Location','eastoutside');
    text(axisHandle,0.02,0.04,'Zero BER at 1e-5; no accepted packets produce gaps', ...
        'Units','normalized','FontSize',8);
    path=fullfile(output,sprintf('figure_%d_CR%d.png',3+(cr==4),cr));
    exportgraphics(fig,path,'Resolution',200);close(fig);
    paths(end+1,1)=string(path); %#ok<AGROW>
end
end
