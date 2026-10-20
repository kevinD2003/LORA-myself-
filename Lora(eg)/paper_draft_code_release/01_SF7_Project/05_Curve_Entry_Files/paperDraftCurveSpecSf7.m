function spec = paperDraftCurveSpecSf7(curveId,entryFunction,sourceFunction,frameType,category)
%PAPERDRAFTCURVESPECSF7 Standard metadata contract for one SF7 curve.

arguments
    curveId (1,1) string
    entryFunction (1,1) string
    sourceFunction (1,1) string
    frameType (1,1) string {mustBeMember(frameType,["native_120","paper_129","single_symbol"])}
    category (1,1) string {mustBeMember(category,["vp","comparison","ideal","theory","theory_reference"])}
end
spec = struct('sf',7,'curveId',curveId,'entryFunction',entryFunction, ...
    'sourceFunction',sourceFunction,'frameType',frameType, ...
    'category',category,'metric','pre-FEC hard-chirp SER; decoded BER separate', ...
    'rawResultsIncluded',false);
end

