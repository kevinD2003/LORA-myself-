% 生成两个不同频率的信号
fs = 100; % 采样率
t = 0:1/fs:5; % 时间范围

f1 = 10; % 第一个信号频率
x1 = sin(2*pi*f1*t); % 第一个信号

f2 = 15; % 第二个信号频率
x2 = sin(2*pi*f2*t); % 第二个信号

% 利用互相关计算信号之间的时间差
[corr, lag] = xcorr(x1, x2); % 计算互相关
[~, idx] = max(abs(corr)); % 找到互相关的峰值索引

time_shift = lag(idx)/fs; % 时间差

% 将第二个信号向后移动时间差
if time_shift > 0
    x2_sync = [zeros(1, round(time_shift*fs)), x2(1:end-round(time_shift*fs))];
else
    x2_sync = [x2(round(-time_shift*fs)+1:end), zeros(1, -round(time_shift*fs))];
end

% 绘制原始信号和同步后的信号
figure;
subplot(2, 1, 1);
plot(t, x1, 'b', t, x2, 'r');
title('原始信号');
legend('信号1', '信号2');

subplot(2, 1, 2);
plot(t, x1, 'b', t, x2_sync, 'r');
title('同步后的信号');
legend('信号1', '信号2（同步后）');