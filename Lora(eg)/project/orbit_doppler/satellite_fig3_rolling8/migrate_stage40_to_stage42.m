function checkpointPath = migrate_stage40_to_stage42()
%MIGRATE_STAGE40_TO_STAGE42 Preserve completed statistics for the new grid.
%   The user shortened the predeclared SNR grid from -30:1:10 dB to
%   -30:1:-10 dB.  The first 21 slots are identical, so this migration
%   copies them without recomputation and discards only untouched slots.

root = fileparts(mfilename('fullpath'));
sourceDir = fullfile(root,'results','stage40_formal_ber_causal_confidence');
targetDir = fullfile(root,'results','stage42_formal_ber_minus30_to_minus10');
sourcePath = fullfile(sourceDir,'formal_ber_checkpoint.mat');
checkpointPath = fullfile(targetDir,'formal_ber_checkpoint.mat');
if ~isfile(sourcePath)
    error('SatelliteFig3:MigrationSource','Stage 40 checkpoint is missing.');
end
if isfile(checkpointPath)
    error('SatelliteFig3:MigrationTarget', ...
        'Stage 42 checkpoint already exists; refusing to overwrite it.');
end
if ~isfolder(targetDir), mkdir(targetDir); end

source = load(sourcePath);
newGrid = (-30:1:-10).';
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

savedSignature = source.savedSignature;
savedSignature.snrGridDb = newGrid;
options = source.options;
options.SnrGridDb = newGrid;
options.OutputFolderName = 'stage42_formal_ber_minus30_to_minus10';
config = source.config;
methodNames = source.methodNames;
scenarioKeys = source.scenarioKeys;
startTimes = source.startTimes;
save(checkpointPath,'state','savedSignature','options','config', ...
    'methodNames','scenarioKeys','startTimes','-v7.3');

fid = fopen(fullfile(targetDir,'MIGRATION_PROVENANCE.txt'),'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'Source: %s\n',sourcePath);
fprintf(fid,'Target SNR grid: -30:1:-10 dB (21 points)\n');
fprintf(fid,'Preserved first 21 state slots; discarded only unused higher-SNR slots.\n');
fprintf(fid,'Migration does not alter seeds, errors, bits, traces, or receiver settings.\n');
fprintf('Migrated Stage 40 checkpoint to: %s\n',checkpointPath);
end
