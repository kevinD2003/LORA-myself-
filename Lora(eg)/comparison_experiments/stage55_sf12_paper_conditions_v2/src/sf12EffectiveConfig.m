function effective = sf12EffectiveConfig(cfg)
%SF12EFFECTIVECONFIG Remove non-simulation manifest metadata for comparison.

effective = cfg;
if isfield(effective.receiver,'manifest')
    effective.receiver = rmfield(effective.receiver,'manifest');
end
end
