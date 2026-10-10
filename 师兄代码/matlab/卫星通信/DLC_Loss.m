% 电子密度剖面数据（示例数据，仅供参考）
% h = [100 200 300 400 500]; % 高度（km）
% Ne = [1e11 5e10 2e10 1e10 5e9]; % 电子密度（electrons/m³）
h=500;%(km)
Ne=1e11;
% 频率信息
f = 400e6; % 频率（Hz）

% 计算电离层的电导率
sigma = 1.65e-4 * Ne ./ f^2;

% 传播路径的长度
D = 36000e3; % 传播路径长度（m）

% 计算电离层吸收损耗
% A = 8.686 * sigma * D;
A = 8.686 * sigma * D;

disp(['电离层吸收损耗：', num2str(A), ' dB']);



% frequency = 400e6;  % 100 MHz
% lon_t = -74.0059;  % 发射地点的经度
% lat_t = 40.7128;   % 发射地点的纬度
% h_t = 10;          % 发射高度（m）
% lon_r = -122.4194; % 接收地点的经度
% lat_r = 37.7749;   % 接收地点的纬度
% h_r = 5;           % 接收高度（m）
% hmF2 = 500;        % F2层最大电子密度高度（km）
% N_mF2 = 1e11;      % F2层电子密度（electrons/m³）
% date_time = '2024-05-16 12:00:00'; % 日期和时间
% 
% propagationLoss = calculatePropagationLoss(frequency, lon_t, lat_t, h_t, lon_r, lat_r, h_r, hmF2, N_mF2, date_time);
% 
% disp(['电离层传播衰减为 ', num2str(propagationLoss), ' dB']);
% 
% function propagationLoss = calculatePropagationLoss(frequency, lon_t, lat_t, h_t, lon_r, lat_r, h_r, hmF2, N_mF2, date_time)
%     % 参数说明：
%     % frequency: 信号频率（Hz）
%     % lon_t, lat_t: 发射地点的经度和纬度
%     % h_t: 发射高度（m）
%     % lon_r, lat_r: 接收地点的经度和纬度
%     % h_r: 接收高度（m）
%     % hmF2: F2层最大电子密度高度（km）
%     % N_mF2: F2层电子密度（electrons/m³）
%     % date_time: 日期和时间
% 
%     % 计算发射地点到F2层的传播距离（km）
%     D1 = sqrt((lon_t - lon_r)^2 + (lat_t - lat_r)^2) * 111.13
% 
%     % 计算发射地点到F2层的斜率
%     S1 = (hmF2 - h_t) / D1;
% 
%     % % 计算损耗系数（α）
%     % alpha = (40.3 * 10^-6) * N_mF2 * frequency^2;
%     % 
%     % 计算电离层传播损耗（dB）
%     % propagationLoss = alpha * D1 * sqrt(1 + S1^2);
%     sigma = 1.65e-4 * N_mF2 ./ frequency^2;
%     A = 8.686 * sigma * D1;
%     propagationLoss =A;
% 
% disp(['电离层吸收损耗：', num2str(A), ' dB']);
% end