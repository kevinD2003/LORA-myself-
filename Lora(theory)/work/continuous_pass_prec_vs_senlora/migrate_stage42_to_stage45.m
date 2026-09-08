function checkpointPath = migrate_stage42_to_stage45()
%MIGRATE_STAGE42_TO_STAGE45 Shorten grid and add the 1e-6 upper-bound stop.

root = fileparts(mfilename('fullpath'));
sourceDir = fullfile(root,'results','stage42_formal_ber_minus30_to_minus10');
targetDir = fullfile(root,'results','stage45_formal_ber_minus30_to_minus14');
sourcePath = fullfile(sourceDir,'formal_ber_checkpoint.mat');
checkpointPath = fullfile(targetDir,'formal_ber_checkpoint.mat');
if ~isfile(sourcePath)
    error('SatelliteFig3:MigrationSource','Stage 42 checkpoint is missing.');
end
if isfile(checkpointPath)
    error('SatelliteFig3:MigrationTarget', ...
        'Stage 45 checkpoint already exists; refusing to overwrite it.');
end
if ~isfolder(targetDir), mkdir(targetDir); end
source = load(sourcePath);
newGrid = (-30:1:-14).';
keep = 1:numel(newGrid);
if ~isequal(source.savedSignature.snrGridDb(keep),newGrid)
    error('SatelliteFig3:MigrationGrid','Source SNR prefix does not match.');
end

state = source.state;
state.errors = state.errors(:,keep,:);
state.bits = state.bits(keep);
state.frameCount = state.frameCount(keep);
state.completed = state.completed(keep);
matrixFields = {'hardAccepted','hardFalse','senAccepted','senFalse', ...
    'senReplayTriggered','senRateReleased','hardPredictionSse', ...
    'senPredictionSse','hardPredictionSamples','senPredictionSamples'};
for index = 1:numel(matrixFields)
    field = matrixFields{index};
    state.(field) = state.(field)(:,keep);
end
state.trace = state.trace(:,keep);
state.terminationReached = false;
state.terminationSnrIndex = NaN;

savedSignature = source.savedSignature;
savedSignature.snrGridDb = newGrid;
savedSignature.stopUpperBerTarget = 1e-6;
options = source.options;
options.SnrGridDb = newGrid;
options.StopUpperBerTarget = 1e-6;
options.OutputFolderName = 'stage45_formal_ber_minus30_to_minus14';
config = source.config;
methodNames = source.methodNames;
scenarioKeys = source.scenarioKeys;
startTimes = source.startTimes;
save(checkpointPath,'state','savedSignature','options','config', ...
    'methodNames','scenarioKeys','startTimes','-v7.3');
fid = fopen(fullfile(targetDir,'MIGRATION_PROVENANCE.txt'),'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'Source: %s\n',sourcePath);
fprintf(fid,'Target grid: -30:1:-14 dB (17 points).\n');
fprintf(fid,'Early stop: all hard-PREC and SenLoRa 95%% upper bounds <= 1e-6.\n');
fprintf(fid,'All retained state, seeds, errors, bits and traces are unchanged.\n');
fprintf('Migrated Stage 42 checkpoint to: %s\n',checkpointPath);
end
