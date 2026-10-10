% 生成原始数据
t = 0:0.01:10;
data = randi([0 3], 1, length(t));

% 进行QPSK调制
qpsk_symbols = pskmod(data, 4, pi/4);

% 添加高斯噪声
% noisy_symbols = awgn(qpsk_symbols, 10);
noise_symbols=qpsk_symbols;

% 手动设置时延
delay = 20; % 设置为自己想要的时延
delayed_symbols = [zeros(1, delay), noisy_symbols(1:end-delay)];

% 进行互相关计算
correlation = xcorr(qpsk_symbols, delayed_symbols);

% 找到峰值对应的延迟
[~, index] = max(correlation);
actual_delay = index - length(qpsk_symbols);

% 将信号向右移动，达到同步
synchronized_symbols = circshift(delayed_symbols, -actual_delay);

% 反调制获得同步后的数据
sync_data = pskdemod(synchronized_symbols, 4, pi/4);

% 绘制结果
figure;
plot(t, data, 'r', t, sync_data, 'g');
legend('原始数据', '同步数据');
xlabel('时间');
ylabel('数据');