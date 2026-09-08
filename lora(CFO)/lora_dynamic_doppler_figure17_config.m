function config = lora_dynamic_doppler_figure17_config()
%LORA_DYNAMIC_DOPPLER_FIGURE17_CONFIG 配置正式 Figure 17 BER 扫描。
%   SNR 的 1 dB 步长是本项目声明的 Monte Carlo 网格，不是论文公开信息。

config = lora_dynamic_doppler_figure17_pilot_config();
config.snrDb = -30:1:10;
config.targetBitErrors = 2000;
config.maxBitsPerPoint = 5e7;
config.profile = "paper_figure17_reference";
config.resume = true;
config.snrGridProvenance = "project_declared_1_dB_grid";
end
