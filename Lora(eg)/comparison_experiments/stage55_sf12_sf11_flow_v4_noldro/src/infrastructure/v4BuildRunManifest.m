function manifest = v4BuildRunManifest(root,identity)
%V4BUILDRUNMANIFEST Construct the immutable identity carried by every run.
arguments
    root (1,:) char
    identity (1,1) struct = struct()
end
plan = jsondecode(fileread(fullfile(root,'config','plan_manifest.json')));
manifest = identity;
manifest.planVersion = plan.planVersion;
manifest.sourceManifestHash = v4Sha256(fullfile(root,'config','source_manifest.json'));
manifest.resultContractHash = v4Sha256(fullfile(root,'config','result_contract.json'));
manifest.seedProtocolHash = v4Sha256(fullfile(root,'config','seed_protocol.json'));
manifest.frameTimingHash = v4Sha256(fullfile(root,'config','frame_timing_manifest.json'));
manifest.calibrationProtocolHash = v4Sha256(fullfile(root,'config','calibration_protocol.json'));
manifest.matlabRelease = version('-release');
manifest.algorithmSignature = v4Sha256(v4CanonicalJson(manifest));
end
