function review = reviewFirstConfig(config)
%REVIEWFIRSTCONFIG Frozen EXP3 packet-replay review configuration.

review = struct();
review.identity = 'EXP3-STAGE55-PACKET-REPLAY-ORBIT-V2';
review.receiverVersion = 'Stage55-V19-dual-hypothesis-packet-replay-v2';
review.resultNamespace = 'review_first_packet_replay_v2';
review.calibrationRootSeed = 981000000;
review.vpCalibrationRootSeed = 982000000;
review.smokeRootSeed = 983000000;
review.reviewRootSeed = 984000000;
review.formalRootSeed = 985000000;
review.refinementRootSeed = 986000000;
review.smokePackets = 5;
review.reviewPackets = 20;
review.caseSnrDb = [-30 -27 -24 -21];
review.smokeSnrDb = [-30 -24 -21];
review.orbitPositionsSec = [-366 -320.25 -274.5 -228.75 -183 ...
    -137.25 -91.5 -45.75 0];
review.orbitSnrDb = config.snrDb;
review.packetDriftThresholdBins = 2.0;
review.strongRateThresholdBinsPerSec = 6.0;
review.rateSigmaFloorBinsPerSec = 0.05;
review.rateConfidenceK = 2.0;
review.splitRateConsistencyBinsPerSec = 0.5;
review.splitRateRelativeTolerance = 0.5;
review.packetLikelihoodGainPerSymbol = 0;
review.packetMinimumReliableVp = 2;
review.packetMinimumConsistentVp = 1;
review.paperShapeRmseLimitDecade = 0.10;
review.paperPointLimitDecade = 0.20;
review.paperReferenceOrbitSec = [-366 -274.5 -183 -91.5 0];
review.paperReferenceMidamblePointSer = [0.022 0.022 0.023 0.029 0.045];
review.paperReferenceSource = [ ...
    'Digitized approximate SF12 Midamble-Point values from Figure 12, ' ...
    'page 14 of the local IEEE PDF; not author raw data'];
review.paperReferenceUncertaintyDecade = 0.05;
review.frameDurationSec = config.frameDurationSec;
end
