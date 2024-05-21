function Result = convertCSV2TargetObject(filename)


    targetKeys = {'RA','Dec','Index','TargetName','DeltaRA','DeltaDec', ...
        'ExpTime', 'NperVisit','MaxNobs','LastJD','GlobalCounter',...
        'NightCounter','Priority'};
    dataTypes = {'char','char','double','char','double','double',...
        'double','double','double','double','double',...
        'double','double'};
    defaultValues = {0, 0, 0, 'target', 0, 0, ...
        20, 20, Inf, 0, 0, ...
        0,1};
    
    dataTypeDict = containers.Map(targetKeys,dataTypes);
    defaultDict = containers.Map(targetKeys,defaultValues);

    opts = detectImportOptions(filename);
    
    % read only columns that fit Target class
    opts.SelectedVariableNames=opts.VariableNames(ismember(opts.VariableNames,targetKeys));
    
    
    % provide correct data types
    for Icolumn=1:1:length(opts.SelectedVariableNames)
        ColName = string(opts.SelectedVariableNames(Icolumn));
        ColIndex = find(opts.VariableNames==ColName);
        opts.VariableTypes(ColIndex)={dataTypeDict(ColName)};
    end

    
    % list rows that do not fit Target class convention
    SkippedCols = opts.VariableNames(~ismember(opts.VariableNames, opts.SelectedVariableNames));
    if ~isempty(SkippedCols)
        fprintf('\nThe following columns are unknown. Skipping them.\n')
        fprintf(1, '%s \t', SkippedCols{:})
        fprintf('\n\n')
    end
    
    % check if RA and Dec provided
    if ~ismember('RA',opts.SelectedVariableNames) || ~ismember('Dec',opts.SelectedVariableNames)
        fprintf('\n\nCannot read target list: RA or Dec missing.\n\n')
        Result = celestial.Targets;
        return
    end

    % read in relevant columns from table
    tbl = readtable(filename, opts);
    
    % convert RA and Dec to degrees
    Ntargets = height(tbl);
    RA = zeros(Ntargets, 1);
    Dec = zeros(Ntargets, 1);
    for Itarget=1:1:Ntargets
        RA(Itarget) = str2double(tbl.RA{Itarget});
        Dec(Itarget) = str2double(tbl.Dec{Itarget});
        if isnan(RA(Itarget))
            [RATemp, DecTemp, ~]=celestial.coo.convert2equatorial(tbl.RA{Itarget},tbl.Dec{Itarget});
            RA(Itarget) = RATemp;
            Dec(Itarget) = DecTemp;
        end
    end
    
    Cols  = targetKeys;
    Ncols = numel(Cols);

    % loop over columns and assign default or provided value
    Result = celestial.Targets;
    for Icol=1:1:Ncols
        if strcmp(Cols{Icol},'RA')
            Result.Data.RA = RA;
            
        elseif strcmp(Cols{Icol},'Dec')
            Result.Data.Dec = Dec;
            
        elseif ismember(Cols{Icol},tbl.Properties.VariableNames)
            Result.Data.(Cols{Icol}) = tbl.(Cols{Icol});
            
        else
            Result.Data.(Cols{Icol}) = ones(Ntargets,1)*defaultDict(Cols{Icol});
        end
    end
    
    
    if ~ismember('Index',tbl.Properties.VariableNames)
        Result.Data.Index = (1:1:Ntargets).';
    end
    
    if ~ismember('TargetName',tbl.Properties.VariableNames)
        Result.Data.TargetName = celestial.Targets.radec2name(RA, Dec);
    end
    
    % sanitize TargetName removing spaces, underscores and other illegal
    % characters
    Result.Data.TargetName = strrep(Result.Data.TargetName,'_','=');
    Result.Data.TargetName = strrep(Result.Data.TargetName,'*','=');
    Result.Data.TargetName = strrep(Result.Data.TargetName,'?','=');
    
    %if ~ismember('NperVisit',tbl.Properties.VariableNames)
    %    Result.Data.NperVisit = ones(Ntargets,1)*NperVisit;
    %    fprintf('Number of images per visit: %i\n', NperVisit)
    %end
    
    %sort by priority
    %Result.Data=sortrows(Result.Data,'Priority','descend');
    %Result.Data.Index = linspace(1,length(Results.Data.Index),length(Results.Data.Index));
    
    %Result
    %Result.Data
    
end
