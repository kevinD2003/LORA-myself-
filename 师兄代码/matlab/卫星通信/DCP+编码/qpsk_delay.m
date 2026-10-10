M = 4;
data = randi([0, M - 1], 1, 1000);
data_QPSK = pskmod(data, M, pi / M);
data_QPSK_delay_signal = [zeros(1, randi([0, 1000])) data_QPSK]; % 以填充0的方式
