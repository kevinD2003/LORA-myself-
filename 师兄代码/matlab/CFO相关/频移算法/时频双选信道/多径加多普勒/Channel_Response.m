% 仿真参数设置
fc = 868e6; % 载波频率 (Hz)
v = 60/3.6; % 车辆速度 (m/s)
T = 1e-3; % 采样时间 (s)
simTime = 1; % 仿真时间 (s)
numSamples = simTime / T; % 采样点数
c = 3e8; % 光速 (m/s)

% 多径分量参数
numPaths = 3;
pathGains_dB = [-3, -6, -9]; % 路径增益 (dB)
pathGains = 10.^(pathGains_dB/10); % 转换为线性增益
pathDelays = [0, 0.5e-6, 1e-6]; % 路径时延 (s)
maxDopplerShift = v * fc / c; % 最大多普勒频移 (Hz)
dopplerShifts = [0, 0.5*maxDopplerShift, maxDopplerShift]; % 各路径的多普勒频移 (Hz)

% 初始化信道响应
channelResponse = zeros(numSamples, numPaths);

% 生成多径信道响应
for n = 1:numSamples
    t = (n-1) * T;
    for p = 1:numPaths
        % 计算多普勒相移
        dopplerPhase = 2*pi * dopplerShifts(p) * t;
        % 生成信道响应
        channelResponse(n, p) = pathGains(p) * exp(1j * dopplerPhase);
    end
end

% 多径时延信息
disp('多径时延 (s):');
disp(pathDelays);

% 多普勒信息
disp('多普勒频移 (Hz):');
disp(dopplerShifts);