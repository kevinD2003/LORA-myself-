%% 补偿法，采用频移的方式（将小数倍的频移补全至整数倍）。
%% 小数部分CFO的估计与补偿。
%% 多径多普勒信道
% 信道（1）：epsilon：0.53（40km/h）0.8（60km/h） ui=1229(Tc/3)；
SF=7;
M=2^SF;
epsilon=[0.5];
ui=M;
aa=M/2;%randi([0 M-1]);
k=0:1:M-1;  
% 直达径信号
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(1)/M));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(1)/M));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
% rk1=awgn(Sd,SNR,'measured');
rk1 = Sd;

xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
r_preamble_ave=zeros(1,M);
%只用num个前导码
num=2;
for o=1:num
    r_preamble=rk1((o-1)*M+1:o*M);
    r_preamble_ave=r_preamble_ave+r_preamble;

end
r_preamble_ave=r_preamble_ave/num;

eta_fraction=(0:0.1:1);
Yq_max=zeros(1,length(eta_fraction));
for i=1:length(eta_fraction)
    y_preamble_tem=abs(fft(r_preamble_ave.*exp(1j*2*pi*k*eta_fraction(i)/M).*xk0));
    Yq_max(i)=max(y_preamble_tem);
end
[~,eta_fraction_estimation]=max(Yq_max);
eta_fraction_estimation=eta_fraction(eta_fraction_estimation);%(eta_fraction_estimation-1)/10;
r_preamble_fc=r_preamble_ave.*exp(1j*2*pi*k*eta_fraction_estimation/M);
y_preamble_fc=abs(fft(r_preamble_fc.*xk0))/M;






% 定义eta_o的值
eta_o_values = (0:0.1:0.9); % 您可以根据需要调整步长

% 初始化一个用于存储y_preamble_fc值的矩阵
Yq_max_matrix = zeros(length(k), length(eta_o_values));

% 对每个eta_o值计算y_preamble_fc
for i = 1:length(eta_o_values)
    eta_o = eta_o_values(i);
    r_preamble_fc = r_preamble_ave .* exp(1j*2*pi*k*eta_o/M);
    y_preamble_fc = abs(fft(r_preamble_fc .* xk0))/M;
    Yq_max_matrix(:, i) = y_preamble_fc;
end

% 创建网格坐标
[k_grid, eta_o_grid] = meshgrid(k, eta_o_values);

% 绘制三维图
figure;
stem3(k_grid, eta_o_grid, Yq_max_matrix);
xlabel('k');
ylabel('eta_o');
zlabel('y_preamble_fc');
title('3D Plot of y_preamble_fc vs. k and eta_o');
