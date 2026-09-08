function signature=v4Stage3SSignature(root,parameters,candidateTableHash)
files={'v4TrackAStage55PointAnchoredDecode.m','v4TrackAPointAnchor.m','v4TrackAProvisionalRate.m'};
parts=strings(0,1);for i=1:numel(files),p=fullfile(root,'src','paper_anchor',files{i});parts(end+1)=string(files{i})+":"+v4Sha256(p);end %#ok<AGROW>
parts(end+1)="plan:"+v4Sha256(fullfile(root,'config','plan_manifest_r5_stage3s.json'));
parts(end+1)="seed:"+v4Sha256(fullfile(root,'config','seed_protocol_r5_stage3s.json'));
parts(end+1)="contract:"+v4Sha256(fullfile(root,'config','result_contract_r5_stage3s.json'));
parts(end+1)="candidate:"+string(candidateTableHash);parts(end+1)="parameters:"+v4Sha256(v4CanonicalJson(parameters));
signature=v4Sha256(char(strjoin(sort(parts),newline)));
end
