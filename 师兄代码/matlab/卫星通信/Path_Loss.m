%% 路径损耗
d = 36000; % 传播距离km，例如10公里
f = 0.4; % 信号频率GHz，例如2.4GHz
path_loss = free_space_path_loss(d, f);
disp(['路径损耗: ', num2str(path_loss), ' dB']);
function PL = free_space_path_loss(d, f)
    % d: 传播距离 (km)
    % f: 信号频率 (GHz)
    Gt = 44;%发送端天线增益dB
    Gr = 1;%接收端天线增益dB
    c = 29.979; % 光速 in真空 (km/ms)
    lambda = c / (f * 1e3); % 波长 (km)
    % L = 20 * log10(d) + 20 * log10(f) - 147.55; % 自由空间路径损耗 (dB)
    PL = -10*log10(Gt*Gr*lambda^2/((4*pi)^2*d^2));%dB ， 弗里斯公式
end


