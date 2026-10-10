%% 补偿法，采用频移的方式（将小数倍的频移补全至整数倍）。
%% 小数部分CFO的估计与补偿。
%% 多径多普勒信道
% 信道（1）：epsilon：0.53（40km/h）0.8（60km/h） ui=1229(Tc/3)；
SF=12;
M=2^SF;
epsilon=[0.53 0.8];
ui=M;
aa=M/2;%randi([0 M-1]);
k=0:1:M-1;  
% 直达径信号
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(1)/M));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(1)/M));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
% rk1=awgn(Sd,SNR,'measured');
rk1 = Sd;

% 多径信号
xk_mul=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(2)/M));
xk_preamble_mul=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(2)/M));%前导符号
Sd_mul=[xk_preamble_mul xk_preamble_mul xk_preamble_mul xk_preamble_mul xk_preamble_mul xk_preamble_mul xk_preamble_mul xk_preamble_mul xk_mul];
Sd_mul=[zeros(1,ui) Sd_mul(1:length(Sd_mul)-ui)];

rk1=rk1+Sd_mul;
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
[~,epsilon_integer_estimation]=max(y_preamble_fc);
o=8;%只用一个前导码
y_payload_withoutEC=abs(fft(rk1(o*M+1:end).*xk0)/M);
y_payload=abs(fft(rk1(o*M+1:end).*xk0.*exp(1j*2*pi*k*(-epsilon_integer_estimation+eta_fraction_estimation+1)/M)))/M;
[~,d]=max(abs(y_payload));


figure;
% subplot(2,1,1)
stem(0:M-1,y_payload_withoutEC,"Marker","none","LineWidth",2);
xlabel("Frequency bin q");ylabel("|Y_q|/M");xlim([0 M-1]);ylim([0 1]);
legend(['epsilon = ', num2str(epsilon(1))]);
title("payload without new algorithm")

figure;
% % subplot(2,1,2)
stem(0:M-1,y_payload,"Marker","none","LineWidth",2);
xlabel("Frequency bin q");ylabel("|Y_q|/M");xlim([0 M-1]);ylim([0 1]);
legend(['epsilon = ', num2str(epsilon(1))]);
title("payload with new algorithm")
