function formal = lora_dynamic_doppler_formalize_result(raw)
%LORA_DYNAMIC_DOPPLER_FORMALIZE_RESULT 生成正式扫描的统计输出字段。
%   零错误 BER 以 NaN 表示；一错误水平和近似 95%% 上界另行保存。

if ~isstruct(raw) || ~isfield(raw, "bit_errors") || ...
        ~isfield(raw, "total_bits") || ~isfield(raw, "ber") || ...
        raw.total_bits <= 0 || raw.bit_errors < 0
    error("lora:InvalidFormalResult", ...
        "Raw result must contain nonnegative errors and positive total bits.");
end
formal = raw;
formal.raw_ber = raw.ber;
formal.one_count_level = 1/raw.total_bits;
formal.upper_95_approx = -log(0.05)/raw.total_bits;
if raw.bit_errors == 0
    formal.ber = NaN;
end
end
