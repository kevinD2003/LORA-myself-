function acExportPlan()
roots=acSetup();[points,configs]=acProjectConditions();
plan=struct('points',points,'configs',{configs},'count',numel(points), ...
    'validationPackets',100,'formalPackets',1000, ...
    'vpVersion','V8-Symbol-VP-Rolling-N8-both-SF7-SF12', ...
    'symbolSource','native-FFT-hard-chirp-before-FEC');
file=fullfile(roots.root,'POINTS.json');content=jsonencode(plan,PrettyPrint=true);
if isfile(file)
    assert(strcmp(fileread(file),content),'Ac:PlanChanged','Existing plan differs.');
else
    fid=fopen(file,'w','n','UTF-8');assert(fid>=0);close=onCleanup(@()fclose(fid));fprintf(fid,'%s',content);
end
end
