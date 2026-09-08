% 信号参数
dataLength = 2720;  % 数据长度
frameLength = 3104; % 帧长度

% 系统参数
frequency = 2.4e9;  % 信号频率（Hz）
distance_ground_to_satellite = 3e7;  % 地面到卫星的距离（米）
distance_satellite_to_ground_station = 3e6;  % 卫星到地面基站的距离（米）
pathLossExponent_ground_to_satellite = 2;  % 地面到卫星的路径损耗指数
pathLossExponent_satellite_to_ground_station = 2;  % 卫星到地面基站的路径损耗指数
rainLossFactor = 0.1;  % 雨水损耗因子
cloudLossFactor = 0.05;  % 云雾损耗因子

% 接收机参数
noiseTemperature = 120;  % 噪声温度（K）
noiseFigure_ground_station = 1.5;  % 地面基站接收机噪声系数（dB）
noiseFigure_satellite = 1.5;  % 卫星接收机噪声系数（dB）
receiverGtoT_ground_station = 18.41;  % 地面基站接收机G/T值（dB/K）
receiverGtoT_satellite = -17;  % 卫星接收机G/T值（dB/K）
LNA_gain_ground_station = 45;  % 地面基站低噪声放大器增益（dB）

% 误码率和丢包率计数器
errorBits = 0;
totalBits = 0;
packetLoss = 0;
totalPackets = 0;

% 发送和接收过程的循环
numIterations = 86400;  % 模拟一天的发送和接收过程（每秒一次，共86400秒）
for i = 1:numIterations
    
    % 生成随机数据
    data = randi([0 1], dataLength, 1);
    
    % 构建帧结构
    frame = [zeros(64, 1); zeros(64, 1); zeros(128, 1); data; zeros(128, 1)];
    
    % QPSK调制
    modulatedData = pskmod(frame, 4);
    
    % 添加路径损耗（地面到卫星）
    receivedPower_satellite = modulatedData / ((4 * pi * distance_ground_to_satellite * frequency / 3e8)^pathLossExponent_ground_to_satellite);
    
    % 添加雨水损耗
    receivedPower_satellite = receivedPower_satellite * rainLossFactor;
    
    % 添加云雾损耗
    receivedPower_satellite = receivedPower_satellite * cloudLossFactor;
    
    % 添加噪声（卫星）
    receivedSignal_satellite = awgn(receivedPower_satellite, receiverGtoT_satellite + noiseFigure_satellite - 10 * log10(noiseTemperature));
    
    % 添加路径损耗（卫星到地面基站）
    receivedPower_ground_station = receivedSignal_satellite / ((4 * pi * distance_satellite_to_ground_station * frequency / 3e8)^pathLossExponent_satellite_to_ground_station);
    
    % 添加低噪声放大器增益（地面基站）
    receivedPower_ground_station = receivedPower_ground_station * 10^(LNA_gain_ground_station / 10);
    
    % 添加噪声（地面基站）
    receivedSignal_ground_station = awgn(receivedPower_ground_station, receiverGtoT_ground_station + noiseFigure_ground_station - 10 * log10(noiseTemperature));
    
    % QPSK解调
    rxBits = pskdemod(receivedSignal_ground_station, 4);
    
    % 统计错误比特数
    errorBits = errorBits + sum(data ~= rxBits(257:2976));
    totalBits = totalBits + dataLength;
    
    % 统计丢包数
    if any(data ~= rxBits(257:2976))
        packetLoss = packetLoss + 1;
    end    
    totalPackets = totalPackets + 1;
end

% 计算误码率和丢包率
bitErrorRate = errorBits / totalBits;
packetLossRate = packetLoss / totalPackets;

% 显示结果
disp(['Bit Error Rate: ' num2str(bitErrorRate)]);
disp(['Packet Loss Rate: ' num2str(packetLossRate)]);