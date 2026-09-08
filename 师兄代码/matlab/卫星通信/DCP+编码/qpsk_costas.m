% 设置参数
Fs = 1000; % 采样频率
fc = 50; % 载波频率
M = 4; % QPSK调制，4个相位
delay = 0.1; % 时延（以秒为单位）

% 生成随机数据
data = randi([0 M-1], 1000, 1); % 生成1000个随机QPSK符号

% QPSK调制
modulatedSignal = pskmod(data, M, pi/M); % 使用pskmod函数进行QPSK调制

% 创建载波信号
t = 0:1/Fs:(length(modulatedSignal)-1)/Fs;
carrier = cos(2*pi*fc*t); % 50 Hz正弦载波

% 引入时延，即引入相位变化
delayedSignal = modulatedSignal .* exp(1i*2*pi*fc*(t-delay)); % 对信号引入时延

% 将调制信号调制到高频
modulatedSignalHighFreq = delayedSignal .* carrier';

% 模拟锁相环同步
phaseError = angle(modulatedSignalHighFreq(1)) - angle(carrier(1)); % 计算初始相位误差
for i = 2:length(modulatedSignalHighFreq)
    phaseError = angle(modulatedSignalHighFreq(i)) - angle(carrier(i)); % 计算相位误差
    carrier(i) = cos(2*pi*fc*t(i) + phaseError); % 更新载波相位
    modulatedSignalHighFreq(i) = delayedSignal(i) * carrier(i); % 重新调制信号
end

% 绘制同步后的信号
figure;
subplot(3,1,1);
plot(data, 'o');
title('原始数据');

subplot(3,1,2);
plot(real(modulatedSignalHighFreq), imag(modulatedSignalHighFreq), 'o');
title('引入时延后的调制信号');

subplot(3,1,3);
plot(real(carrier), imag(carrier), 'o');
title('同步后的载波信号');