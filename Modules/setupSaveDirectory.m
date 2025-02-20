function saveDir = setupSaveDirectory(config)
    % setupSaveDirectory Ensures the output directory and subfolders exist based on the config.
    %
    %   saveDir = setupSaveDirectory(config)
    %
    %   The main output directory is determined from config.output_folder and the config file’s base name.
    %   If a "comparison_setup" section exists, subfolders for each comparison scenario are created.
    %
    %   Author: Shuijin Li
    %   Email: lishuijin@nbu.edu.cn
    %   Updated Date: 2025-Feb-03
    %
    %   Parent Functions:
    %       - main.m
    %       - launcher.m
    %
    %   Called Functions:
    %       - None

    % Determine the base name for the output directory
    if isfield(config, 'configName') && ~isempty(config.configName)
        baseName = config.configName;
    elseif isfield(config, 'configFileName') && ~isempty(config.configFileName)
        [~, baseName, ~] = fileparts(config.configFileName);
    else
        baseName = 'DefaultConfig';
    end

    % Create the main output directory if it doesn't exist
    mainDir = fullfile(config.output_folder, baseName);
    if ~exist(mainDir, 'dir')
        mkdir(mainDir);
        fprintf('Created main directory: %s\n', mainDir);
    else
        fprintf('Main directory already exists: %s\n', mainDir);
    end
    
    % Create subfolders for comparison scenarios if specified in the config
    if isfield(config, 'comparison_setup')
        compKeys = fieldnames(config.comparison_setup);
        for i = 1:length(compKeys)
            subfolderName = compKeys{i};
            subfolderPath = fullfile(mainDir, subfolderName);
            if ~exist(subfolderPath, 'dir')
                mkdir(subfolderPath);
                fprintf('Created subfolder for comparison: %s\n', subfolderPath);
            else
                fprintf('Subfolder already exists: %s\n', subfolderPath);
            end
        end
    end

    % Return the main directory path
    saveDir = mainDir;
end