function provenance = attachFigureProvenance(figureHandle, rows)
% Attach source topics, fields, conversions, and validation evidence to a figure.

    variableNames = { ...
        'DisplayedSignal', 'SourceTopic', 'SourceField', 'InstanceID', ...
        'Unit', 'Operation', 'EvidenceClass', 'Validation'};

    if istable(rows)
        provenance = rows;
    else
        provenance = cell2table(rows, 'VariableNames', variableNames);
    end

    setappdata(figureHandle, 'FLIPDataProvenance', provenance);
    existingMenu = findall(figureHandle, 'Type', 'uimenu', ...
        'Tag', 'flipViewDataProvenance');

    if isempty(existingMenu)
        uimenu(figureHandle, ...
            'Text', 'View Data Provenance...', ...
            'Tag', 'flipViewDataProvenance', ...
            'MenuSelectedFcn', @(menuHandle, ~) ...
                showFigureProvenance(ancestor(menuHandle, 'figure')));
    end

end
