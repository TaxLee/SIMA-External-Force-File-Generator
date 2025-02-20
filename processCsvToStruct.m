function resultStruct = processCsvToStruct(config)
% processCsvToStruct Processes a high-fidelity CSV file into a nested structure.
%
%   resultStruct = processCsvToStruct(config)
%
%   Inputs:
%       config - Structure with fields read from config.json containing:
%           .filename       - CSV file name.
%           .filePath       - Folder where the CSV file is located.
%           .dataLines      - Cell array with start and end lines (e.g., [2, "Inf"]).
%           .fixedColCount  - The number of fixed columns (e.g., 8).
%
%   Outputs:
%       resultStruct   - Nested structure with processed data.
%
%   This function reads the CSV file, extracts a hierarchical variable
%   naming structure from the data, and creates a nested structure where each
%   leaf node contains parameter information and a vector of y-values.
%
% Author: Shuijin Li
% Email: lishuijin@nbu.edu.cn
% Date: 2025.01.15
%

%% Setup file paths and import options
absFilePath = config.input_file;

% Create import options using detectImportOptions
opts = detectImportOptions(absFilePath);
% Adjust dataLines based on config (assume first row is header/comment)
opts.DataLines = [str2double(config.dataLines{1}), Inf];

% Set fixed column names for the first fixedColCount columns.
fixedNames = {'ColA','ColB','ColC','ColD','ColE','ColF','ColG','ColH'};
opts.VariableNames(1:length(fixedNames)) = fixedNames;
% Set these columns as character arrays; extra columns (y-values) will be read as text.
opts = setvartype(opts, fixedNames, 'char');

% Read the table.
disp('Reading CSV file...');
dataTable = readtable(absFilePath, opts);

%% Determine total number of y-value columns (if any)
allVars = dataTable.Properties.VariableNames;
yValStart = config.fixedColCount + 1;  % e.g. 9 if fixedColCount=8
numYCols = length(allVars) - config.fixedColCount;
fprintf('Found %d y-value columns.\n', numYCols);

%% Initialize the overall result structure.
resultStruct = struct;
numRows = height(dataTable);

%% Process each row of the table.
for i = 1:numRows
    % Log progress every 1000 rows (or as needed)
    if mod(i, 10) == 0
        fprintf('Processing row %d of %d...\n', i, numRows);
    end

    % --- (a) Extract columns A to H ---
    colA = strtrim(dataTable.ColA{i});  % Final variable name
    colC = strtrim(dataTable.ColC{i});  % Full hierarchical name
    colD = strtrim(dataTable.ColD{i});  % e.g., 'xunit=s'
    colE = strtrim(dataTable.ColE{i});  % e.g., 'yunit=Nm' or 'yunit=m/s'
    colF = strtrim(dataTable.ColF{i});  % e.g., 'ten=40000'
    colG = strtrim(dataTable.ColG{i});  % e.g., 'dx=0.1000000149011612'
    colH = strtrim(dataTable.ColH{i});  % e.g., 'x0=0.1000000149011612'

    % --- (b) Build the hierarchical tokens using the length-based removal ---
    lenA = length(colA);
    if length(colC) > lenA
        parentStr = colC(1:end-lenA);
    else
        parentStr = '';
    end
    % Remove any trailing non-alphanumeric characters (e.g. punctuation, spaces).
    parentStr = regexprep(parentStr, '[\s\W]+$', '');
    % Split the parent string into tokens using '.' as delimiter.
    if ~isempty(parentStr)
        tokens = regexp(parentStr, '\.', 'split');
        tokens = cellfun(@strtrim, tokens, 'UniformOutput', false);
    else
        tokens = {};
    end
    tokens = cellfun(@(s) matlab.lang.makeValidName(s), tokens, 'UniformOutput', false);

    % Process colA to form the final (leaf) field name.
    finalField = matlab.lang.makeValidName(colA);
    tokens{end+1} = finalField;

    % --- (c) Parse parameter values from columns D-H ---
    getVal = @(str, key) strrep(str, [key '='], '');
    xunitVal = getVal(colD, 'xunit');
    yunitVal = getVal(colE, 'yunit');
    tenVal   = str2double(getVal(colF, 'ten'));
    dxVal    = str2double(getVal(colG, 'dx'));
    x0Val    = str2double(getVal(colH, 'x0'));

    % --- (d) Parse y-values up to the length specified by tenVal ---
    startCol = yValStart;
    endCol   = min(yValStart + tenVal - 1, width(dataTable));

    % 1) Extract the row as a cell array (1xN)
    rowCell = table2cell(dataTable(i, startCol:endCol));

    % 2) Convert everything to string and then to double in one pass.
    %    Non-numeric cells become NaN if they do not convert cleanly.
    %    (Empty strings, '', also become NaN.)
    yValsTemp = str2double(strtrim(string(rowCell)));

    % 3) Overwrite positions that are *already numeric* to avoid any string-conversion ambiguity.
    %    This covers cases where the cell is a numeric scalar (double) rather than a string.
    isNumCell = cellfun(@(c) isnumeric(c) && isscalar(c), rowCell);
    yValsTemp(isNumCell) = [rowCell{isNumCell}];

    % If the row has fewer columns than tenVal, optionally pad with NaN.
    neededLength = endCol - startCol + 1;
    if neededLength < tenVal
        padVals = nan(1, tenVal);
        padVals(1:neededLength) = yValsTemp;
        yValsTemp = padVals;
    end

    % 4) Ensure column vector
    yVals = yValsTemp(:);

    % If the actual number of columns is less than tenVal, fill remaining with NaN.
    actualLen = endCol - startCol + 1;
    if actualLen < tenVal
        tmp = nan(tenVal, 1);
        % Convert yVals to a numeric column vector, if needed
        if ~isnumeric(yVals)
            if iscell(yVals)
                yVals = cellfun(@(x) str2double(strtrim(x)), yVals);
            else
                yVals = str2double(strtrim(yVals));
            end
        end
        tmp(1:actualLen) = yVals(:);
        yVals = tmp;
    else
        % Convert non-numeric data
        if ~isnumeric(yVals)
            if iscell(yVals)
                yVals = cellfun(@(x) str2double(strtrim(x)), yVals);
            else
                yVals = str2double(strtrim(yVals));
            end
        end
        % Force column vector
        yVals = yVals(:);
    end

    % --- (e) Build the leaf structure for this data series ---
    leafData = struct(...
        'xunit',  xunitVal, ...
        'yunit',  yunitVal, ...
        'ten',    tenVal,   ...
        'dx',     dxVal,    ...
        'x0',     x0Val,    ...
        'yvalue', yVals);

    % --- (f) Insert the leafData into the overall nested result structure ---
    resultStruct = nestedFieldAssign(resultStruct, tokens, leafData);
end

disp('Processing complete.');

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Helper Function: Nested Field Assignment
function S = nestedFieldAssign(S, tokens, value)
% Recursively assigns "value" to the nested field defined by "tokens".
if numel(tokens) == 1
    S.(tokens{1}) = value;
else
    if ~isfield(S, tokens{1}) || ~isstruct(S.(tokens{1}))
        S.(tokens{1}) = struct;
    end
    S.(tokens{1}) = nestedFieldAssign(S.(tokens{1}), tokens(2:end), value);
end
end

