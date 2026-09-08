function report = validateFrameProtocol(cfg)
%VALIDATEFRAMEPROTOCOL Check the locked dialogue-derived frame construction.

arguments
    cfg (1,1) struct
end

layout = buildFrameLayout(cfg);
report.payloadSymbols = layout.payloadSymbols;
report.midambleCount = layout.numberOfMidambles;
report.calculatedPointToaS = layout.pointToaS;
report.paperPointToaS = cfg.paper.pointToaS;
report.pointToaDifferenceS = ...
    layout.pointToaS-cfg.paper.pointToaS;
report.calculatedMidamblePointToaS = layout.midamblePointToaS;
report.paperMidamblePointToaS = cfg.paper.midamblePointToaS;
report.midambleToaDifferenceS = ...
    layout.midamblePointToaS-cfg.paper.midamblePointToaS;
report.toaRoundingToleranceS = 0.5e-3;
report.expectedMidambleCountEq20 = ceil(layout.payloadSymbols/ ...
    cfg.frame.midambleSpacingDataSymbols);
report.payloadCountMatched = ...
    layout.payloadSymbols == cfg.frame.payloadSymbols;
report.midambleCountMatched = layout.numberOfMidambles == ...
    report.expectedMidambleCountEq20;
report.pointToaMatched = abs(report.pointToaDifferenceS) <= ...
    report.toaRoundingToleranceS;
report.midambleToaMatched = abs(report.midambleToaDifferenceS) <= ...
    report.toaRoundingToleranceS;
publicationConsistency = analyzePublicationConsistency(cfg);
report.tableMatchesFractionalMidambleApproximation = ...
    publicationConsistency.tableMatchesFractionalApproximation;
report.paperInternalConflictProved = ...
    publicationConsistency.paperInternalConflictProved;
report.implementationProtocolPassed = report.payloadCountMatched && ...
    report.midambleCountMatched && report.pointToaMatched;
report.passed = report.payloadCountMatched && ...
    report.midambleCountMatched && report.pointToaMatched && ...
    report.midambleToaMatched;
if report.passed
    report.status = "paper_frame_matched";
elseif report.implementationProtocolPassed && ...
        report.paperInternalConflictProved
    report.status = "paper_table_fractional_midamble_conflict";
else
    report.status = "paper_frame_unresolved";
end
end
