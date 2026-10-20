function spec = paperDraftCurveSpecSf12(curveId,entryFunction,sourceFunction,frameType,category)
%PAPERDRAFTCURVESPECSF12 Standard metadata contract for one SF12 curve.

arguments
    curveId (1,1) string
    entryFunction (1,1) string
    sourceFunction (1,1) string
    frameType (1,1) string {mustBeMember(frameType,["native_120","paper_157","single_symbol"])}
    category (1,1) string {mustBeMember(category,["vp","comparison","ideal","theory","theory_reference"])}
end
spec = struct('sf',12,'curveId',curveId,'entryFunction',entryFunction, ...
    'sourceFunction',sourceFunction,'frameType',frameType, ...
    'category',category,'metric','pre-FEC hard-chirp SER; decoded BER separate', ...
    'rawResultsIncluded',false);
end

