function text = v4CanonicalJson(value)
%V4CANONICALJSON Stable JSON encoding with recursively sorted struct fields.
text = jsonencode(localSort(value));
end

function value = localSort(value)
if isstruct(value)
    names = sort(fieldnames(value));
    ordered = cell(size(value));
    for element = 1:numel(value)
        item = struct();
        for index = 1:numel(names)
            name = names{index};
            item.(name) = localSort(value(element).(name));
        end
        ordered{element} = item;
    end
    if numel(ordered) == 1, value = ordered{1}; else, value = ordered; end
elseif iscell(value)
    for index = 1:numel(value), value{index} = localSort(value{index}); end
end
end
