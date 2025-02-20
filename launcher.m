%% launcher.m
% Launcher Script for SIMA External Force File Generator
%
% **Author:** Shuijin Li
% **Email:** lishuijin@nbu.edu.cn
% **Date:** 2025.02.03
%
% **Copyright (C) 2025 Shuijin Li.
% **All Rights Reserved.**
%
% **Description:**
%   This script serves as the entry point for the SIMA External Force File Generator
%   tool. It allows users to select one or more JSON configuration files via a GUI
%   prompt (or via a pre-defined variable) and then processes each configuration.
%   For each configuration, it initializes the workspace, sets up paths and cache,
%   processes the CSV file(s) using caching (via processAllFiles), and calls
%   generateSimaExternalForceFile(config) to generate a SIMA-readable external force file.
%
% **Usage:**
%   - Standard Users: Run launcher.m and select configuration file(s) via the GUI.
%   - Advanced Users: Predefine a variable 'config_path' with one or more JSON file paths.
%
% **Update Logs:**
% -----------------------------------------------------------
% Version: 1.0.0 (2025.01.15)
% - Created launcher.m for SIMA External Force File Generator.
%
% Version: 1.1.0 (2025.01.19)
% - Enabled multiple configuration file selection and improved error handling.
%
% Version: 1.2.0 (2025.02.03)
% - Updated logging and validation for config_path.
%
% Version: 1.3.0 (2025.02.10)
% - Modified to call generateSimaExternalForceFile(config) which now uses the caching
%   infrastructure (processAllFiles) and plots a comparison of variable data before
%   and after conversion.
% -----------------------------------------------------------

%% 0. Initialization
clearvars;
close all;
clc;

fprintf('=============================================\n');
fprintf('  Welcome to SIMA External Force File Generator  \n');
fprintf('=============================================\n\n');

%% 1. Configuration Path Selection

% Advanced users may predefine 'config_path' as a string or cell array of file paths.
% Examples:
%   config_path = 'Config/config_example_v1.json';
%   config_path = {'config/config_case1.json', 'config/config_case2.json'};
% Leave empty to prompt for file selection.

if ~exist('config_path', 'var') || isempty(config_path)
    fprintf('No predefined configuration path detected.\n');
    fprintf('Please select one or more configuration file(s) using the dialog below.\n\n');
    
    [files, pathStr] = uigetfile({'*.json', 'JSON Config Files (*.json)'}, ...
                                 'Select Configuration File(s)', 'MultiSelect', 'on');
    
    if isequal(files, 0)
        error('User cancelled the configuration file selection. Workflow aborted.');
    end

    if ischar(files)
        configFiles = {files};  % Single file selected.
    else
        configFiles = files;
    end
else
    fprintf('Predefined configuration path detected.\n');
    if ischar(config_path)
        configFiles = {config_path};
    elseif iscell(config_path)
        configFiles = config_path;
    else
        error('Variable config_path must be a string or a cell array of strings.');
    end
    pathStr = ''; % Assume full file names provided.
    fprintf('Using configuration file(s):\n');
    for k = 1:length(configFiles)
        fprintf('  %s\n', configFiles{k});
    end
    fprintf('\n');
end

%% 2. Process Each Configuration File

for idx = 1:length(configFiles)
    if ~isempty(pathStr)
        currentConfigPath = fullfile(pathStr, configFiles{idx});
    else
        currentConfigPath = configFiles{idx};
    end
    
    [~, ~, ext] = fileparts(currentConfigPath);
    if ~strcmpi(ext, '.json')
        error('The configuration file must be a .json file. Selected file has extension: %s', ext);
    end
    
    if ~exist(currentConfigPath, 'file')
        error('Configuration file not found: %s', currentConfigPath);
    end
    
    %% 3. Load Configuration and Set Config Name
    configText = fileread(currentConfigPath);
    config = jsondecode(configText);
    
    [~, configName, ~] = fileparts(currentConfigPath);
    config.configName = configName;
    
    fprintf('Configuration name set to: %s\n\n', config.configName);
    fprintf('All results (cache, output, etc.) will be saved to: %s\\%s\n\n', ...
            config.output_folder, config.configName);
    fprintf('--- Starting External Force File Generation for %s ---\n\n', config.configName);
    
    %% 4. Call the Generator Workflow
    try
        generateSimaExternalForceFile(config);
        fprintf('\n--- External Force File Generation for %s Completed Successfully ---\n', config.configName);
    catch ME
        fprintf('\n--- An error occurred during the workflow for %s ---\n', config.configName);
        rethrow(ME);
    end
    
    fprintf('\n---------------------------------------------\n\n');
end

%% 5. Ending Message
fprintf('\n=============================================\n');
fprintf('  Thank you for using SIMA External Force File Generator!   \n');
fprintf('=============================================\n');
fprintf('All processes have been completed. Please check the output folder for results.\n\n');
