function output = curveSf7RicianTheoryReference(packets)
%CURVESF7RICIANTHEORYREFERENCE Describe or regenerate normalized-K10 evidence.
spec = paperDraftCurveSpecSf7("sf7_rician_theory_reference",mfilename, ...
    "normalized_k10_pdp_v1/full1000","single_symbol","theory_reference");
if nargin==0, output=spec; return; end
validateattributes(packets,{'numeric'}, ...
    {'scalar','real','finite','integer','positive'},mfilename,'packets');
roots=paperDraftSetupSf7();
script=fullfile(roots.normalizedChannel,'theory','generate_full_grid.py');
assert(isfile(script),'PaperDraft:MissingGenerator','Missing Rician generator.');
outputFolder=fullfile(roots.root,'99_Local_Outputs_Not_Uploaded', ...
    'rician_theory_regeneration');
if ~isfolder(outputFolder), mkdir(outputFolder); end
command=sprintf('python "%s" --packets %d --output "%s"',script,packets,outputFolder);
[status,text]=system(command);
assert(status==0,'PaperDraft:RicianGenerator','%s',text);
output=struct('status',status,'outputFolder',string(outputFolder), ...
    'generator',string(script),'packets',packets,'console',string(text));
end

