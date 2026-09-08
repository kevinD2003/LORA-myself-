classdef V3ReportArtifactTest < matlab.unittest.TestCase
    methods (Test)
        function finalTablesAndIdentityExist(testCase)
            config = sf12Sf11FlowConfig();
            path = fullfile(config.projectRoot,'results','reports', ...
                'v3_final_report_data.mat');
            loaded = load(path,'report');
            report = loaded.report;
            testCase.verifyEqual(height(report.formalSummary),60);
            testCase.verifyEqual(height(report.symbolCfoRmse),6720);
            testCase.verifyEqual(unique(report.pairedIntervals.resamplingUnit), ...
                "complete-pass");
            testCase.verifyEqual(report.paperIdentity, ...
                'Paper-Midamble-Point-SF12-CR3-adapted');
            testCase.verifyFalse(report.isPaperFigureReplication);
            testCase.verifyTrue(isfile(fullfile(config.projectRoot,'results','reports', ...
                'V3_FINAL_REPORT.md')));
        end
    end
end

