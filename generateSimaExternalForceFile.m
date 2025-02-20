function generateSimaExternalForceFile(config)
% generateSimaExternalForceFile Generates a SIMA-readable external force file.
%
% Author:  Shuijin Li
% Email:   lishuijin@nbu.edu.cn
%
% -------------------------------------------------------------------------
% Description:
%   1) Initializes the workspace and sets paths (doInitialization, setupPaths).
%   2) Parses input file(s) to get file paths (parseInputFilePaths).
%   3) Prepares a cache folder (prepareCacheFolder) => config.output_folder/<configName>.
%   4) Loads master cache (loadMasterCache).
%   5) Processes each CSV file into resultStruct (processAllFiles).
%   6) For each variable in config.var_to_process:
%      - Recursively locates it in resultStruct
%      - Optionally applies a transformation (and logs/plots before/after comparison)
%      - Writes the external force file **into the same cache folder** as the .mat file
%   7) Finalizes and saves the updated master cache (finalizeAndSave).
%
% External Force File Format:
%   - Header lines (prefixed with apostrophes)
%   - Three format parameters (6 columns, number of time steps, sample interval)
%   - Lines with [0 0 0 0 MY_value 0], where MY_value = the (optionally transformed) data
%
% Configuration Requirements (config):
%   config.output_folder  : Parent folder for results
%   config.input_file     : One or more .csv paths
%   config.var_to_process : A struct, each field is a variable to process:
%                              .transformationFunctionToTheVar (optional)
%                              .outputFileName (string)
%
% Example:
%   config.output_folder = 'results';
%   config.input_file    = 'mySIMAdata.csv';
%   config.var_to_process.MyMomentVar.transformationFunctionToTheVar = 'Var=Var*(-1)';
%   config.var_to_process.MyMomentVar.outputFileName = 'Mom_End1.txt';
%   generateSimaExternalForceFile(config);

%% 1. Initialization & Path Setup
[config, mainPath] = doInitialization(config);
setupPaths(mainPath);

%% 2. Parse Input File(s)
filePaths = parseInputFilePaths(config);

%% 3. Prepare Cache Folder
cacheFolder = prepareCacheFolder(config);

%% 4. Load Master Cache
resultStruct = loadMasterCache(config, cacheFolder);

%% 5. Process Each File (imports or loads CSV data into resultStruct)
resultStruct = processAllFiles(filePaths, config, cacheFolder, resultStruct);

%% 6. External Force File Generation
if isfield(config, 'var_to_process')
    varProcess = config.var_to_process;
    varNames   = fieldnames(varProcess);

    for iVar = 1:length(varNames)
        currVarName = varNames{iVar};
        fprintf('Processing variable: %s\n', currVarName);

        % (6.1) Locate the variable in resultStruct
        varStruct = findVariableInResult(resultStruct, currVarName);
        if isempty(varStruct)
            warning('Variable "%s" not found. Skipping.', currVarName);
            continue;
        end
        if ~isfield(varStruct, 'yvalue')
            warning('Variable "%s" lacks "yvalue". Skipping.', currVarName);
            continue;
        end

        varData = varStruct.yvalue;
        if ~isvector(varData)
            warning('Data for "%s" is not a vector. Skipping.', currVarName);
            continue;
        end

        % Extract sample interval if available, otherwise 1.0
        if isfield(varStruct, 'dx') && ~isempty(varStruct.dx)
            samp = varStruct.dx;
        else
            samp = 1.0;
        end

        % (6.2) Check for transformation
        cfgVar = varProcess.(currVarName);
        if isfield(cfgVar, 'transformationFunctionToTheVar') && ~isempty(cfgVar.transformationFunctionToTheVar)
            oldVarData = varData;
            transStr   = cfgVar.transformationFunctionToTheVar;

            % Apply transformation
            [varData, oldVarData] = applyTransformation(varData, transStr);

            % Compare original vs. transformed
            diffVals = varData - oldVarData;
            fprintf('Applied transformation: %s\n', transStr);
            fprintf('    Min difference: %g\n', min(diffVals));
            fprintf('    Max difference: %g\n', max(diffVals));

            % Plot and save comparison
            compareDataBeforeAfter(oldVarData, varData, ...
                currVarName, cacheFolder);
        end

        % (6.3) Determine the output file path within the same cacheFolder
        if ~isfield(cfgVar, 'outputFileName') || isempty(cfgVar.outputFileName)
            warning('No outputFileName for "%s". Skipping.', currVarName);
            continue;
        end
        outputFileName = cfgVar.outputFileName;
        outputFilePath = fullfile(cacheFolder, outputFileName);

        % (6.4) Write the external force file
        fid = fopen(outputFilePath, 'w');
        if fid == -1
            warning('Cannot open file for writing: %s', outputFilePath);
            continue;
        end

        % Header lines
        fprintf(fid, ''' Generated by generateSimaExternalForceFile\n');
        fprintf(fid, ''' Variable: %s\n', currVarName);

        % Format parameters
        ncol = 6;
        nrow = length(varData);
        fprintf(fid, '%d\n', ncol);
        fprintf(fid, '%d\n', nrow);
        fprintf(fid, '%.6f\n', samp);

        % Data lines: [0 0 0 0 varData 0]
        for j = 1:nrow
            fprintf(fid, '0 0 0 0 %.6f 0\n', varData(j));
        end

        fclose(fid);
        fprintf('External force file written: %s\n', outputFilePath);
    end
else
    warning('No "var_to_process" field found in config.');
end

%% 7. Finalize & Save Master Cache
finalizeAndSave(resultStruct, config, cacheFolder);

end % generateSimaExternalForceFile


% =========================================================================
%                           HELPER FUNCTIONS
% =========================================================================

function [config, mainPath] = doInitialization(config)
% (Section 1) Clear workspace and set the working directory
%
% Author: Shuijin Li
% Email:  lishuijin@nbu.edu.cn
% Date:   2025-Feb-03

clearvars -except config;
close all;
clc;
t_script = tic; %#ok<NASGU>
format long g;
mfile_fullpath = mfilename('fullpath');
[mainPath, ~, ~] = fileparts(mfile_fullpath);
cd(mainPath);
fprintf('--- Initialization Complete ---\n\n');
end

function setupPaths(mainPath)
% (Section 1) Adds Modules and Libraries directories to MATLAB path
%
% Updated Date: 2025-Feb-20

modules_path   = fullfile(mainPath, 'Modules');
libraries_path = fullfile(mainPath, 'Libraries');

if exist(modules_path, 'dir')
    addpath(genpath(modules_path));
    fprintf('--- Modules path added: %s ---\n', modules_path);
else
    warning('Modules directory not found: %s', modules_path);
end

if exist(libraries_path, 'dir')
    addpath(genpath(libraries_path));
    fprintf('--- Libraries path added: %s ---\n', libraries_path);
else
    warning('Libraries directory not found: %s', libraries_path);
end

fprintf('--- SetupPaths completed ---\n\n');
end

function filePaths = parseInputFilePaths(config)
% (Section 2) Converts config.input_file into a cell array of file paths
%
% If config.input_file is a string, convert to cell. If it's a struct or cell,
% handle accordingly. Return a cell array of valid file paths.

if ~isfield(config, 'input_file') || isempty(config.input_file)
    error('No "input_file" specified in config.');
end

if ischar(config.input_file) || isstring(config.input_file)
    filePaths = {char(config.input_file)};
elseif iscell(config.input_file)
    filePaths = config.input_file;
elseif isstruct(config.input_file)
    filePaths = {};
    structFields = fieldnames(config.input_file);
    for iF = 1:numel(structFields)
        fileEntry = config.input_file.(structFields{iF});
        if isstruct(fileEntry)
            if isfield(fileEntry, 'path') && ~isempty(fileEntry.path)
                filePaths{end+1} = fileEntry.path; %#ok<AGROW>
            else
                error('Each entry in "input_file" struct must contain a "path" field.');
            end
        elseif ischar(fileEntry) || isstring(fileEntry)
            filePaths{end+1} = char(fileEntry); %#ok<AGROW>
        else
            error(['Unsupported format for "input_file" entry: ', structFields{iF}]);
        end
    end
else
    error('"input_file" must be a string, cell array, or struct with file entries.');
end

if isempty(filePaths)
    error('No valid file paths found in "input_file".');
end
end

function cacheFolder = prepareCacheFolder(config)
% (Section 3) Creates/verifies the output/cache folder
%
% Updated Date: 2025-Feb-03

if isfield(config, 'configName') && ~isempty(config.configName)
    baseName = config.configName;
elseif isfield(config, 'configFileName') && ~isempty(config.configFileName)
    [~, baseName, ~] = fileparts(config.configFileName);
else
    baseName = 'DefaultConfig';
end

cacheFolder = fullfile(config.output_folder, baseName);
if ~exist(cacheFolder, 'dir')
    mkdir(cacheFolder);
    fprintf('Created output/cache folder: %s\n', cacheFolder);
else
    fprintf('Output/cache folder exists: %s\n', cacheFolder);
end
end

function resultStruct = loadMasterCache(config, cacheFolder)
% (Section 4) Loads the master cache file if available
%
% Updated Date: 2025-Feb-03

masterCacheFile = fullfile(cacheFolder, [config.configName, '.mat']);
if isfile(masterCacheFile)
    fprintf('Master cache found: %s\n', masterCacheFile);
    temp = load(masterCacheFile, 'resultStruct');
    if isfield(temp, 'resultStruct')
        resultStruct = temp.resultStruct;
        fprintf('Loaded combined results from master cache.\n');
    else
        warning('Master cache found but missing "resultStruct". Returning empty struct.');
        resultStruct = struct();
    end
else
    resultStruct = struct();
end
end

function resultStruct = processAllFiles(filePaths, config, cacheFolder, resultStruct)
% (Section 5) Processes each input file and aggregates results into resultStruct
%
% If a file is already in the cache, it skips reprocessing. If no cache is found,
% calls processCsvToStruct and then stores the data in the per-file cache.

for fIdx = 1:numel(filePaths)
    thisFile = filePaths{fIdx};
    if isempty(thisFile), continue; end
    [~, baseFile, ~] = fileparts(thisFile);
    safeFieldName = matlab.lang.makeValidName(baseFile);
    if isfield(resultStruct, safeFieldName)
        fprintf('Skipping file "%s" (already loaded in resultStruct).\n', thisFile);
        continue;
    end
    fprintf('--- Processing input file: %s ---\n', thisFile);
    cacheExtractedFileName = sprintf('%s_Extracted.mat', baseFile);
    cacheExtractedFilePath = fullfile(cacheFolder, cacheExtractedFileName);

    if isfile(cacheExtractedFilePath)
        fprintf('Loading individual cache: %s\n', cacheExtractedFilePath);
        temp = load(cacheExtractedFilePath, 'fileData');
        if isfield(temp, 'fileData')
            fileData = temp.fileData;
        else
            warning('No "fileData" in cache. Re-processing CSV: %s', thisFile);
            config.input_file = thisFile;
            fileData = processCsvToStruct(config);
            save(cacheExtractedFilePath, 'fileData', '-v7.3');
        end
    else
        fprintf('Cache not found. Processing CSV: %s\n', thisFile);
        config.input_file = thisFile;
        fileData = processCsvToStruct(config);
        save(cacheExtractedFilePath, 'fileData', '-v7.3');
        fprintf('Data extracted and cached: %s\n', cacheExtractedFilePath);
    end

    resultStruct.(safeFieldName) = fileData;
    fprintf('\n');
end
end

function finalizeAndSave(resultStruct, config, cacheFolder)
% (Section 7) Saves the updated master cache
%
% Updated Date: 2025-Feb-03

masterCacheFile = fullfile(cacheFolder, [config.configName, '.mat']);
save(masterCacheFile, 'resultStruct', '-v7.3');
fprintf('Master cache saved to: %s\n', masterCacheFile);
end

% -------------------------------------------------------------------------
%                   TRANSFORMATION & COMPARISON HELPERS
% -------------------------------------------------------------------------
function varStruct = findVariableInResult(S, varName)
% findVariableInResult Recursively searches structure S for a field named varName.
% Returns the sub-structure if found, otherwise [].

if isfield(S, varName)
    varStruct = S.(varName);
    return;
end

varStruct = [];
fields = fieldnames(S);
for i = 1:numel(fields)
    if isstruct(S.(fields{i}))
        varStruct = findVariableInResult(S.(fields{i}), varName);
        if ~isempty(varStruct)
            return;
        end
    end
end
end

function [newVarData, oldVarData] = applyTransformation(inData, transStr)
% applyTransformation Evaluates the transformation string on the variable "Var".
% Example: transStr = 'Var=Var*(-1)';

oldVarData = inData;
Var        = inData; %#ok<NASGU>
eval(transStr);      % modifies Var
newVarData = Var;
end

function compareDataBeforeAfter(oldData, newData, varName, saveDir)
% compareDataBeforeAfter Plots original vs transformed data in two subplots
% and saves the figure as <varName>_compare.png under saveDir.

figH = figure('Name',['Comparison: ',varName], ...
    'Units','normalized','Position',[0.25,0.25,0.4,0.5]);

subplot(2,1,1);
plot(oldData,'b-','LineWidth',1.2);
title(['Original Data: ', varName], 'Interpreter','none');
xlabel('Index'); ylabel('Amplitude'); grid on;

subplot(2,1,2);
plot(newData,'r-','LineWidth',1.2);
title(['Transformed Data: ', varName], 'Interpreter','none');
xlabel('Index'); ylabel('Amplitude'); grid on;

comparisonFileName = [varName, '_compare.png'];
fullComparisonPath = fullfile(saveDir, comparisonFileName);

try
    saveas(figH, fullComparisonPath);
    fprintf('    -> Comparison plot saved: %s\n', fullComparisonPath);
catch ME
    warning('Could not save comparison figure: %s', ME.message);
end

close(figH);
end
