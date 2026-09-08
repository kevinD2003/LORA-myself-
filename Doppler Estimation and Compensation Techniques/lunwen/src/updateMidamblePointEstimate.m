function updatedEstimateHz = updateMidamblePointEstimate( ...
    currentEstimateHz, residualEstimateHz, innovationGain)
%UPDATEMIDAMBLEPOINTESTIMATE Eq. (17) residual-frequency update.

arguments
    currentEstimateHz double
    residualEstimateHz double
    innovationGain (1,1) double {mustBeInRange(innovationGain, 0, 1)} = 1
end

validateattributes(currentEstimateHz, {'numeric'}, {'size', size(residualEstimateHz)});
updatedEstimateHz = currentEstimateHz + ...
    innovationGain*residualEstimateHz;
end
