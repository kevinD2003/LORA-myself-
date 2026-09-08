% 设置参数
Fs = 1000; % 采样频率
fc = 50; % 载波频率
M = 4; % QPSK调制，4个相位

% 生成随机数据
data = randi([0 M-1], 1000, 1); % 生成1000个随机QPSK符号

% QPSK调制
modulatedSignal = pskmod(data, M, pi/M); % 使用pskmod函数进行QPSK调制

% 创建载波信号
t = 0:1/Fs:(length(modulatedSignal)-1)/Fs;
carrier = cos(2*pi*fc*t); % 50 Hz正弦载波

% 将调制信号调制到高频
modulatedSignalHighFreq = modulatedSignal .* carrier';

% 绘制调制后的信号
figure;
subplot(3,1,1);
plot(data, 'o');
title('原始数据');

subplot(3,1,2);
plot(real(modulatedSignal), imag(modulatedSignal), 'o');
title('QPSK调制信号');

subplot(3,1,3);
plot(real(modulatedSignalHighFreq), imag(modulatedSignalHighFreq), 'o');
title('调制到高频后的信号');