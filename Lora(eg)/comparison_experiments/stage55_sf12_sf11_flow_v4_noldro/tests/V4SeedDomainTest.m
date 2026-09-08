classdef V4SeedDomainTest < matlab.unittest.TestCase
    methods (Test)
        function rootsAreUniqueAndVersioned(testCase)
            root = v4SetupPaths();
            protocol = jsondecode(fileread(fullfile(root,'config','seed_protocol.json')));
            values = struct2array(protocol.roots);
            testCase.verifyEqual(numel(unique(values)),numel(values));
            testCase.verifyNotEqual(protocol.roots.a_calibration,protocol.roots.a_formal);
            testCase.verifyNotEqual(protocol.roots.b_calibration, ...
                protocol.roots.b_formal_awgn_controlled);
            testCase.verifyNotEqual(protocol.roots.b_formal_awgn_controlled, ...
                protocol.roots.b_formal_rician_controlled);
        end
    end
end
