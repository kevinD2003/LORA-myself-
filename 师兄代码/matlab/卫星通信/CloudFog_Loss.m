%% 云雾衰落
%% ITU-R P.804-8
% f = 1.7e9; % 下行频率 1.7 GHz
f = 400e6;%上行 400MHz
T_cloud = 273; % 云的温度，假设为0°C
M_cloud = 0.5; % 云水含量，单位为g/m^3
d = 2.5; % 路径长度，单位为km

loss = Cloud_Loss(f, T_cloud, M_cloud, d);
disp(loss); % 显示云雾损耗

function cloud_loss = Cloud_Loss(f, T_cloud, M_cloud, d)
    theta = 300 / T_cloud;
    Epsilon_0 = 77.66 + 103.3 * (theta - 1);
    Epsilon_1 = 0.0671 * Epsilon_0;
    Epsilon_2 = 3.52;
    fp = 20.2 - 146 * (theta - 1) + 316 * (theta - 1)^2;
    fs = 39.8 * fp;
    Epsilon_p = (Epsilon_0 - Epsilon_1) / (1 + (f / fp)^2) + ...
                (Epsilon_1 - Epsilon_2) / (1 + (f / fs)^2) + Epsilon_2;
    Epsilon_pp = f * (Epsilon_0 - Epsilon_1) / (fp * (1 + (f / fp)^2)) + ...
                 f * (Epsilon_1 - Epsilon_2) / (fs * (1 + (f / fs)^2));
    eta = (2 + Epsilon_p) / Epsilon_pp;
    KL = 0.819 * f / (Epsilon_pp * (1 + eta^2));
    % 已×d
    gamma_c = KL * M_cloud * d;
    cloud_loss = gamma_c;
end
