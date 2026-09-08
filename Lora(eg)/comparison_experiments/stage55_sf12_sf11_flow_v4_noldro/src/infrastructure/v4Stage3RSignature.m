function signature=v4Stage3RSignature(root,parameters,candidateTableHash)
%V4STAGE3RSIGNATURE Bind R4 plan, code, candidate table and parameters.
files=[dir(fullfile(root,'src','paper_anchor','v4TrackAStage55PendingLockDecode.m')); ...
    dir(fullfile(root,'src','paper_anchor','v4TrackACandidate.m')); ...
    dir(fullfile(root,'src','paper_anchor','v4TrackABranchConsistency.m')); ...
    dir(fullfile(root,'src','paper_anchor','v4TrackACommittedHistoryFit.m'))];
parts=strings(0,1);
for index=1:numel(files)
    path=fullfile(files(index).folder,files(index).name);
    parts(end+1)=string(files(index).name)+":"+v4Sha256(path); %#ok<AGROW>
end
parts(end+1)="plan:"+v4Sha256(fullfile(root,'config','plan_manifest_r4_stage3r.json'));
parts(end+1)="seed:"+v4Sha256(fullfile(root,'config','seed_protocol_r4_stage3r.json'));
parts(end+1)="contract:"+v4Sha256(fullfile(root,'config','result_contract_r4_stage3r.json'));
parts(end+1)="candidate:"+string(candidateTableHash);
parts(end+1)="parameters:"+v4Sha256(v4CanonicalJson(parameters));
signature=v4Sha256(char(strjoin(sort(parts),newline)));
end
