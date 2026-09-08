function config = lora_dynamic_doppler_figure17_pilot_config()
%LORA_DYNAMIC_DOPPLER_FIGURE17_PILOT_CONFIG 配置 Figure 17 粗网格预检。
%   CONFIG = LORA_DYNAMIC_DOPPLER_FIGURE17_PILOT_CONFIG() 从已经验证的
%   动态 Doppler BER 配置派生论文 Figure 17 的粗网格。场景起始时刻
%   始终由 LORA_FIGURE17_GEOMETRY 推导，不能改为论文近似常数。

config = lora_dynamic_doppler_ber_config();
geometry = lora_figure17_geometry();

config.profile = "paper_figure17_reference";
config.spreadingFactors = 5:12;
config.snrDb = -30:2:10;
config.targetBitErrors = 500;
config.maxBitsPerPoint = 1e7;
config.dopplerModel = "paper_piecewise_linear";
config.timeMode = "fixed_orbit_start_independent_symbols";
config.orbitScenarios(1).startTimeSec = geometry.highRateTimeSec;
config.orbitScenarios(2).startTimeSec = geometry.highShiftTimeSec;
config.resume = true;
end
