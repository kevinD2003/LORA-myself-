function suite = stage55ProjectTestSuite(options)
%STAGE55PROJECTTESTSUITE Build the complete canonical Stage55 test suite.
%   The builder fails when a top-level or fuxianduibi test file is not a
%   class-based matlab.unittest test or is silently omitted by discovery.

arguments
    options.StageFolder (1,:) char = fileparts(mfilename('fullpath'))
    options.ComparisonFolder (1,:) char = localComparisonFolder( ...
        options.StageFolder)
    options.IncludeFuxianduibi (1,1) logical = true
end

import matlab.unittest.TestSuite

stageFolder = options.StageFolder;
if ~isfolder(stageFolder)
    error('SatelliteFig3:Stage55TestFolder', ...
        'Stage55 test folder not found: %s',stageFolder);
end

topLevelFiles = localTestFiles(stageFolder,{'test_','Test.m'});
localAssertClassBased(topLevelFiles);
suite = TestSuite.fromFolder(stageFolder);
localAssertDiscovered(topLevelFiles,suite);

if options.IncludeFuxianduibi
    fuxianFolder = fullfile(options.ComparisonFolder,'tests');
    if ~isfolder(fuxianFolder)
        error('SatelliteFig3:FuxianduibiTestFolder', ...
            'fuxianduibi test folder not found: %s',fuxianFolder);
    end
    fuxianFiles = localTestFiles(fuxianFolder,{'','Test.m'});
    localAssertClassBased(fuxianFiles);
    fuxianSuite = TestSuite.fromFolder(fuxianFolder);
    localAssertDiscovered(fuxianFiles,fuxianSuite);
    suite = [suite fuxianSuite];
end

function folder = localComparisonFolder(stageFolder)
workspaceFolder = fileparts(fileparts(fileparts(stageFolder)));
folder = fullfile(workspaceFolder,'comparison_experiments', ...
    'stage55_three_method');
end
end

function files = localTestFiles(folder,patterns)
allFiles = dir(fullfile(folder,'*.m'));
names = string({allFiles.name});
if isempty(patterns{1})
    selected = endsWith(names,patterns{2});
else
    selected = startsWith(names,patterns{1}) | ...
        endsWith(names,patterns{2});
end
files = allFiles(selected);
end

function localAssertClassBased(files)
notClassBased = strings(0,1);
for index = 1:numel(files)
    text = fileread(fullfile(files(index).folder,files(index).name));
    firstLine = extractBefore(string(text),newline);
    if ~startsWith(strtrim(firstLine),'classdef ')
        notClassBased(end+1,1) = string(files(index).name); %#ok<AGROW>
    end
end
if ~isempty(notClassBased)
    error('SatelliteFig3:NonClassTest', ...
        'All registered tests must be class-based. Convert: %s', ...
        strjoin(notClassBased,', '));
end
end

function localAssertDiscovered(files,suite)
suiteNames = string({suite.Name});
missing = strings(0,1);
for index = 1:numel(files)
    [~,baseName] = fileparts(files(index).name);
    if ~any(startsWith(suiteNames,string(baseName)+"/"))
        missing(end+1,1) = string(files(index).name); %#ok<AGROW>
    end
end
if ~isempty(missing)
    error('SatelliteFig3:UndiscoveredTest', ...
        'MATLAB test discovery omitted: %s',strjoin(missing,', '));
end
end
