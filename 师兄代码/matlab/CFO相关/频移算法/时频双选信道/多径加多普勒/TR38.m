%% 
% 参数设置
fc = 868e6; % 载波频率 (Hz)
v = 100/3.6; % 移动速度 (m/s)
c = 3e8; % 光速 (m/s)
T_s = 1e-6; % 采样时间 (s)
N = 6; % 多径分量数量，包含主径
L = 100; % 大尺度衰落 (dB)

% 计算最大多普勒频移
fd_max = v*fc/c;

% 初始化多径参数
tau = zeros(N, 1); % 多径时延
g = zeros(N, 1); % 多径增益
fd = zeros(N, 1); % 多普勒频移




% 生成主径信息
% 主径时延设为最小，这里设为 0
tau(1) = 0;
% 主径增益设为相对较大，这里设为 0.8（可根据实际调整）

% g_amp_main = lognrnd(mu, sigma);
g_amp_main = 0.8;
% g_phase_main = 2*pi*rand;
g_phase_main = 0;
g(1) = g_amp_main*exp(1j*g_phase_main);
% 主径多普勒频移
fd(1) = (2*rand - 1)*fd_max;
rng(0); % 固定随机种子确保结果可复现  
mu = 3; % 对数变换后正态分布的均值  
sigma = 0.5; % 对数变换后正态分布的标准差    
% 生成其余多径参数
for i = 2:N
    % 随机生成多径时延 (假设在 0 到 10 微秒之间)
    tau(i) =  lognrnd(mu, sigma, 1, 1);
    tau(i) = min(tau(i), 100); % 确保时延不超过100微秒  100e-6*rand;
    g_amp = 0.5*rand;
%     g_amp = lognrnd(mu, sigma);
    % 随机生成多径增益相位 (在 0 到 2*pi 之间)
    g_phase = 2*pi*rand;
%     g(i) = g_amp*exp(1j*g_phase);
    g(i) = g_amp;
    % 随机生成多普勒频移 (在 -fd_max 到 fd_max 之间)
    fd(i) = (2*rand - 1)*fd_max;
end

% 打印每个多径分量的多普勒频移信息
disp('每个多径分量的多普勒频移 (Hz):');
for i = 1:N
    fprintf('多径分量 %d: %.2f Hz\n', i, fd(i));
end

% 绘制每个多径分量的多普勒频移
figure;
plot(1:N, fd, 'bo-');
xlabel('多径分量序号');
ylabel('多普勒频移 (Hz)');
title('各多径分量的多普勒频移');
grid on;

%% 计算离散时间信道冲激响应
n = 0:100; % 时间索引
h = zeros(size(n));
for i = 1:N
    h = h + g(i)*exp(1j*2*pi*fd(i)*n*T_s).*double(n == round(tau(i)/T_s))*exp(-L/20);
end

% 绘制信道冲激响应
figure;
stem(n*T_s, abs(h));
xlabel('Time (s)');
ylabel('Magnitude');
title('Channel Impulse Response');