clear all;
close all;

% 参数设置
Fs = 1000;             % 采样率
T = 1/Fs;              % 采样周期
Ts = 1/Fs;             % 符号周期
N = 1000;              % 采样点数
t = (0:N-1)*T;         % 时间序列

% QPSK调制
data = randi([0,3],1,N/2);  % 随机生成0-3的整数作为调制数据
symbols = pskmod(data, 4, pi/4);  % QPSK调制，相位偏移为pi/4
baseband_signal = rectpulse(symbols, Fs/Ts);  % 符号重复采样

% 信号加噪声
SNR_dB = 10;  % 信噪比（单位：dB）
signal_power = mean(abs(baseband_signal).^2);
noise_power = signal_power / 10^(SNR_dB/10);
noise = sqrt(noise_power) * (randn(1,N/2) + 1j*randn(1,N/2)); % 调整噪声大小
received_signal = baseband_signal + noise;

% Costas环同步
carrier_frequency = 10;  % 信号的载波频率
phase_offset_estimate = zeros(1,N);
loop_filter_state = 0;
loop_bandwidth = 0.01;
loop_damping_factor = sqrt(2)/2;
for n = 2:N
    error = angle(received_signal(n)*conj(received_signal(n-1)));
    loop_filter_state = loop_filter_state + (loop_bandwidth * error - loop_damping_factor * loop_filter_state) * T;
    phase_offset_estimate(n) = phase_offset_estimate(n-1) + carrier_frequency * T + loop_filter_state;
end

% 调制解调
demodulated_signal = received_signal .* exp(-1j*phase_offset_estimate);
demodulated_symbols = pskdemod(demodulated_signal, 4, pi/4);

% 结果可视化
figure;
subplot(2,1,1);
plot(t, real(received_signal));
hold on;
plot(t, imag(received_signal));
xlabel('时间');
ylabel('接收信号');
title('接收信号');

subplot(2,1,2);
stem(data);
hold on;
stem(real(demodulated_symbols), 'r');
xlabel('符号序号');
ylabel('调制数据');
title('调制数据和解调数据');
legend('原始数据', '解调数据');