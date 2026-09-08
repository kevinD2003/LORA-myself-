% % 输入参数
% EIRP = 50; % 卫星的等效辐射功率（单位：dBW）
% G_satellite = 30; % 卫星天线的增益（单位：dBi）
% L_satellite = 0; % 卫星链路的传输损耗（单位：dB）
% L_downlink = 135; % 下行链路的传输损耗（单位：dB）
% L_uplink = 115; % 上行链路的传输损耗（单位：dB）
% NF = 1.5; % 噪声系数（单位：dB）
% G_T = -15; % G/T（单位：dBi/K）
% G_receiver = 10^(G_T/10) * 290; % 接收机天线的增益（单位：dBi）
% L_receiver = 1; % 接收机链路的传输损耗（单位：dB）
% 
% % 计算SNR
% k = 1.38e-23; % 玻尔兹曼常数（单位：J/K）
% T = 120; % 系统的噪声温度（单位：K）
% SNR = EIRP + G_satellite - L_satellite - L_downlink - L_uplink - 10 * log10(k*T) - NF + G_receiver - L_receiver;
% 
% % 输出结果
% disp(['SNR: ' num2str(SNR) ' dB']);



% 输入参数
EIRP = 43; % 卫星的等效辐射功率（单位：dBm）
G_satellite = 0; % 卫星天线的增益（单位：dBi）
L_satellite = 2; % 卫星链路的传输损耗（单位：dB）
L_downlink = 190; % 下行链路的传输损耗（单位：dB）
L_uplink = 179; % 上行链路的传输损耗（单位：dB）
NF_satellite = 1.5; % 卫星端的噪声系数（单位：dB）
G_T = -17; % G/T（单位：dBi/K）
G_receiver = 10^(G_T/10) * 120; % 接收机天线的增益（单位：dBi）
L_receiver = 1; % 接收机链路的传输损耗（单位：dB）
NF_receiver = 1.5; % 接收机端的噪声系数（单位：dB）
G_LNA = 45; % LNA的增益（单位：dB）

% 计算SNR
k = 1.38e-23; % 玻尔兹曼常数（单位：J/K）
T = 120; % 系统的噪声温度（单位：K）
% SNR = EIRP + G_satellite - L_satellite - L_downlink - L_uplink - NF_satellite + G_LNA + G_receiver - L_receiver - NF_receiver - 10 * log10(k*T);
SNR = EIRP + G_satellite - L_satellite -L_uplink - NF_satellite + G_receiver - L_receiver - NF_receiver - 10 * log10(k*T)-52-randi([0 3]);
% SNR = EIRP + G_satellite - L_satellite - L_downlink -  G_LNA + G_receiver - L_receiver - NF_receiver - 10 * log10(k*T);
% 输出结果
disp(['SNR: ' num2str(SNR) ' dB']);