classdef V4TrackARandomPairingTest < matlab.unittest.TestCase
    methods (Test)
        function packetKeyIsReproducibleAndIndependent(testCase)
            c = sf12NoLdroSf11FlowConfig();
            a = v4GenerateTrackAPacket(c,-366,-21,5,410000000);
            b = v4GenerateTrackAPacket(c,-366,-21,5,410000000);
            d = v4GenerateTrackAPacket(c,-366,-21,6,410000000);
            testCase.verifyEqual(a.truth.labels,b.truth.labels);
            testCase.verifyEqual(a.rx,b.rx);
            testCase.verifyNotEqual(a.truth.labels,d.truth.labels);
        end
    end
end
