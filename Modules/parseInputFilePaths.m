function filePaths = parseInputFilePaths(config)
% parseInputFilePaths Converts config.input_file into a cell array of file paths
%
%   filePaths = parseInputFilePaths(config)
%
%   This function parses the 'input_file' field from the config structure.
%   It supports both the old and new configuration formats. In the new format,
%   each file entry is a struct containing at least a 'path' field.
%
%   Parameters:
%       config - Configuration structure containing 'input_file'.
%
%   Returns:
%       filePaths - Cell array of file path strings.

if ~isfield(config, 'input_file') || isempty(config.input_file)
    error('No "input_file" specified in config.');
end

if ischar(config.input_file) || isstring(config.input_file)
    % Single file path as a string
    filePaths = {char(config.input_file)};

elseif iscell(config.input_file)
    % Cell array of file paths
    filePaths = config.input_file;

elseif isstruct(config.input_file)
    % Struct with file entries, possibly in the new format
    filePaths = {};
    structFields = fieldnames(config.input_file);
    for iF = 1:numel(structFields)
        fileEntry = config.input_file.(structFields{iF});

        if isstruct(fileEntry)
            % New config format: struct with 'path' and possibly other fields
            if isfield(fileEntry, 'path') && ~isempty(fileEntry.path)
                filePaths{end+1} = fileEntry.path; %#ok<AGROW>
            else
                error('Each entry in "input_file" struct must contain a "path" field.');
            end
        elseif ischar(fileEntry) || isstring(fileEntry)
            % Old config format: direct file path as string
            filePaths{end+1} = char(fileEntry); %#ok<AGROW>
        else
            error(['Unsupported format for "input_file" entry: ', structFields{iF}]);
        end
    end

else
    error('"input_file" must be a string, cell array of strings, or struct with file entries.');
end

if isempty(filePaths)
    error('No valid file paths found in "input_file".');
end
end
