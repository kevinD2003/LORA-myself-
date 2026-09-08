%% 根据噪声温度计算噪声功率
% 定义玻尔兹曼常数
k = 1.38e-23; % 焦耳/开尔文
% 定义噪声温度和噪声带宽
T = 183; % 噪声温度，单位为开尔文
% T=randi([22,32],1,24)+273.15;
B = 400e3; % 系统带宽，单位为赫兹
% 计算噪声功率
P = k * T * B;
% 将噪声功率转换为dBm
P_dB = 10 * log10(P)+30;

% 输出噪声功率的分贝值
display(P_dB);
%定义热噪声功率谱密度函数
function noisePSD = thermalNoisePSD(T_noise, B_bandwidth)
    % 参数：噪声温度（K），带宽（Hz）
    K = 1.38e-23; % 玻尔兹曼常数（J/K）
    noisePSD = K * T_noise * B_bandwidth; % 热噪声功率谱密度（W/Hz）
end
% 
% % 定义模拟噪声信号的函数
% function noiseSignal = generateNoiseSignal(noisePSD, N_samples, f_sampling)
%     % 参数：噪声功率谱密度（W/Hz），采样点数，采样频率（Hz）
%     % 生成随机噪声信号
%     noiseSignal = randn(N_samples, 1); % 生成N_samples个随机样本
%     noiseSignal = noiseSignal / sqrt(N_samples); % 归一化噪声信号
%     % 添加噪声功率谱密度
%     noiseSignal = noiseSignal .* sqrt(noisePSD * f_sampling); % 添加噪声功率谱密度
% end
% 
% % 设置参数
% T_noise = 464; % 噪声温度（K）
% B_bandwidth = 400e3; % 带宽（Hz）
% N_samples = 1000000; % 采样点数
% f_sampling = 100000000; % 采样频率（Hz）
% 
% % 计算热噪声功率谱密度
% noisePSD = thermalNoisePSD(T_noise, B_bandwidth);
% 
% % 生成噪声信号
% noiseSignal = generateNoiseSignal(noisePSD, N_samples, f_sampling);
% 
% % 显示结果
% % disp('热噪声功率谱密度 (W/Hz): ');
% % disp(noisePSD);
% % disp('噪声信号 (sample): ');
% % disp(noiseSignal);
