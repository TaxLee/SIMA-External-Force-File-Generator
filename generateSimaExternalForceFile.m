function generateSimaExternalForceFile(config)
    % generateSimaExternalForceFile Generates a SIMA-readable external force file.
    %
    % This function initializes the workspace and paths, sets up caching, and then
    % processes the input CSV file(s) using processAllFiles (which internally calls
    % processCsvToStruct if needed). For each variable defined in config.var_to_process,
    % the function optionally applies a transformation, plots a comparison of the
    % original and transformed data, and writes the data to an output file.
    %
    % The output file format includes:
    %   - A header with identification and variable information.
    %   - Format parameters: number of columns (fixed at 6), number of time steps, and sample interval.
    %   - Data lines with six columns: [FX, FY, FZ, MX, MY, MZ]. (Only MY is taken from the variable.)
    %
    % Inputs:
    %   config - A structure containing configuration information, including:
    %            - output_folder: Folder path to save output files.
    %            - input_file: Path (or cell array of paths) to the CSV file(s) to process.
    %            - var_to_process: Structure with fields for each variable to process.
    %              Each field should include:
    %                  transformationFunctionToTheVar (optional): a string MATLAB expression to transform the data.
    %                  outputFileName: The name of the output file.
    %
    % Example usage:
    %   generateSimaExternalForceFile(config);
    %
    % Note: This function relies on helper functions:
    %   - doInitialization, setupPaths, prepareCacheFolder, processAllFiles, finalizeAndSave.
    % Ensure these functions are available on the MATLAB path.
    
        %% 1. Initialization and Path Setup
        [config, mainPath] = doInitialization(config);
        setupPaths(mainPath);
        cacheFolder = prepareCacheFolder(config);
        
        %% 2. Process Input File(s) Using Caching
        % Ensure config.input_file is defined.
        if ~isfield(config, 'input_file')
            error('Configuration must include an "input_file" field.');
        end
        if ischar(config.input_file)
            filePaths = {config.input_file};
        elseif iscell(config.input_file)
            filePaths = config.input_file;
        else
            error('config.input_file must be a string or cell array of strings.');
        end
        
        % Process files using caching (this function mimics the processAllFiles in main.m).
        resultStruct = struct();
        resultStruct = processAllFiles(filePaths, config, cacheFolder, resultStruct);
        
        % For simplicity, assume a single CSV file was processed.
        fileKeys = fieldnames(resultStruct);
        if isempty(fileKeys)
            error('No file data processed.');
        end
        dataStruct = resultStruct.(fileKeys{1});
        
        %% 3. Process Each Variable in config.var_to_process
        varToProcess = config.var_to_process;
        varNames = fieldnames(varToProcess);
        
        for i = 1:length(varNames)
            varName = varNames{i};
            varConfig = varToProcess.(varName);
            
            % Ensure the variable exists in the loaded data.
            if ~isfield(dataStruct, varName)
                warning('Variable "%s" not found in the processed data.', varName);
                continue;
            end
            
            % Retrieve original data.
            originalData = dataStruct.(varName);
            transformedData = originalData;  % Default: no transformation.
            
            % If a transformation function is provided, apply it.
            if isfield(varConfig, 'transformationFunctionToTheVar') && ~isempty(varConfig.transformationFunctionToTheVar)
                try
                    transformationFunction = str2func(['@(x) ' varConfig.transformationFunctionToTheVar]);
                    transformedData = transformationFunction(originalData);
                    % Update the data structure with transformed data.
                    dataStruct.(varName) = transformedData;
                catch ME
                    warning('Error applying transformation for %s: %s', varName, ME.message);
                end
                
                % Plot comparison: original data (blue) vs. transformed data (red dashed).
                figure;
                plot(originalData, 'b-', 'LineWidth', 1.5); hold on;
                plot(transformedData, 'r--', 'LineWidth', 1.5);
                xlabel('Time Step');
                ylabel(varName);
                title(sprintf('Comparison for %s: Original vs. Transformed', varName));
                legend('Original', 'Transformed');
                grid on;
                hold off;
            end
            
            %% 4. Write the External Force File
            outputFileName = varConfig.outputFileName;
            outputFilePath = fullfile(config.output_folder, outputFileName);
            
            fileID = fopen(outputFilePath, 'w');
            if fileID == -1
                error('Failed to open file for writing: %s', outputFilePath);
            end
            
            % Write header information.
            fprintf(fileID, ''' Generated by generateSimaExternalForceFile\n');
            fprintf(fileID, ''' Variable: %s\n', varName);
            
            % Define file format parameters.
            ncol = 6;                      % [FX, FY, FZ, MX, MY, MZ]
            nrow = length(transformedData); % Number of time steps
            samp = 1.0;                    % Sample interval
            
            % Write the parameters.
            fprintf(fileID, '%d\n', ncol);
            fprintf(fileID, '%d\n', nrow);
            fprintf(fileID, '%.1f\n', samp);
            
            % Write force/moment data: only MY is non-zero.
            for j = 1:nrow
                fprintf(fileID, '0 0 0 0 %.6f 0\n', transformedData(j));
            end
            
            fclose(fileID);
        end
        
        %% 5. Finalize Cache (Optional)
        finalizeAndSave(resultStruct, config, cacheFolder);
    end
    