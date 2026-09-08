function combineCaseFigureFiles(case1Png, case2Png, outputPng)
%COMBINECASEFIGUREFILES Join two case panels without changing data.

arguments
    case1Png (1,1) string
    case2Png (1,1) string
    outputPng (1,1) string
end

case1Image = imread(case1Png);
case2Image = imread(case2Png);
if size(case1Image, 1) ~= size(case2Image, 1)
    error('combineCaseFigureFiles:HeightMismatch', ...
        'Case images must have equal heights.');
end
combined = cat(2, case1Image, case2Image);
imwrite(combined, outputPng);
end
