% 定义大气噪声功率谱密度函数
function noisePSD = atmosphericNoisePSD(f_center, B_bandwidth, T_atm, RH, alt, pressure)
    % 参数：中心频率（Hz），带宽（Hz），大气温度（K），相对湿度，高度（km），大气压力（Pa）
    % 假设大气噪声功率谱密度与中心频率、带宽、大气温度、相对湿度、高度和大气压力有关
    K = 1.38e-23; % 玻尔兹曼常数（J/K）
    noisePSD = K * T_atm * B_bandwidth * (1 - RH) * alt * pressure; % 大气噪声功率谱密度（W/Hz）
end

% 设置参数
f_center = 1500e6; % 中心频率（Hz）
B_bandwidth = 1000000; % 带宽（Hz）
T_atm = 290; % 大气温度（K）
RH = 50; % 相对湿度（%）
alt = 300; % 高度（km）
pressure = 101325; % 大气压力（Pa）

% 计算大气噪声功率谱密度
noisePSD = atmosphericNoisePSD(f_center, B_bandwidth, T_atm, RH, alt, pressure);

% 显示结果
disp('大气噪声功率谱密度 (W/Hz): ');
disp(noisePSD);
% 定义大气噪声功率计算函数
function noisePower = atmosphericNoisePower(f_center, B_bandwidth, T_atm, RH, alt, pressure)
    % 参数：中心频率（Hz），带宽（Hz），大气温度（K），相对湿度，高度（km），大气压力（Pa）
    % 假设大气噪声功率与中心频率、带宽、大气温度、相对湿度、高度和大气压力有关
    K = 1.38e-23; % 玻尔兹曼常数（J/K）
    noisePower = K * T_atm * B_bandwidth * (1 - RH) * alt * pressure; % 大气噪声功率（W）
end

% 设置参数
f_center = 1500e6; % 中心频率（Hz）
B_bandwidth = 1000000; % 带宽（Hz）
T_atm = 290; % 大气温度（K）
RH = 50; % 相对湿度（%）
alt = 300; % 高度（km）
pressure = 101325; % 大气压力（Pa）

% 计算大气噪声功率
noisePower = atmosphericNoisePower(f_center, B_bandwidth, T_atm, RH, alt, pressure);

% 显示结果
disp('大气噪声功率 (W): ');
disp(noisePower);
