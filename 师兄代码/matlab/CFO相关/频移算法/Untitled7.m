%% 补偿法，采用频移的方式（将小数倍的频移补全至整数倍）。
%% 小数部分CFO的估计与补偿。
SF=10;
epsilon=[30.3];
M=2^SF;
aa=64;%randi([0 M-1]);
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon/M));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
% Sd=[Sd(10:end) zeros(1,9)];
% SNR = -13;
% 手动添加高斯噪声
sigPower=sum(abs(Sd.*Sd))/length(Sd);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(Sd))+1j*randn(1,length(Sd)));
%% 瑞利信道（Rayleigh Fading）
% omega = 1;
% h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
% %% Rician Fading （莱斯衰落）
% k_factor = 6;
% To generate a Rician fading channel gain
% h_rician = sqrt(k_facrtor/(k_factor+1)) + sqrt(1/(k_factor+1)) * h_rayleigh;


%% 
% rk1=h_rayleigh*Sd+noise;

% rk1 =h_rayleigh * Sd;
% rk1 = Sd + noise;
rk1 = Sd ;
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
r_preamble_ave=zeros(1,M);
%只用N_upchirp个前导码
N_upchirp=8;
for o=1:N_upchirp
    r_preamble=rk1((o-1)*M+1:o*M);
    r_preamble_ave=r_preamble_ave+r_preamble;
end
r_preamble_ave=r_preamble_ave/N_upchirp;
epsilon_i=0;
eta=0;
Yq_max=0;
eta_o=0;
step=0.1;
L_sto = 70;lamda_sto = 0.67;
STO_fr = exp(1j*2*pi*lamda_sto*k/M);
STO_fr = circshift(STO_fr, M-L_sto+1);
while eta_o<=0.9

    y_preamble_tem=abs(fft(r_preamble_ave.*exp(1j*2*pi*k*eta_o/M).*xk0.* exp(1j*2*pi*L_sto*k/M) .* STO_fr));
%     y_preamble_tem=abs(fft(r_preamble_ave.*exp(1j*2*pi*k*eta_o/M).*xk0.* exp(1j*2*pi*(L_sto+lamda_sto)*k/M)));
    [Yq_max_tmp,epsilon_integer_tmp]=max(y_preamble_tem);
    if Yq_max_tmp > Yq_max
        Yq_max = Yq_max_tmp;
        epsilon_i = epsilon_integer_tmp;
        eta =eta_o;
    end
    eta_o=eta_o+step;
end

%% 
o=8;%只用一个前导码
payload_dechirp=rk1(o*M+1:end).*xk0;
payload = payload_dechirp .* exp(1j*2*pi*L_sto*k/M) .* STO_fr;
y_payload_withoutEC=abs(fft(payload));
y_payload=abs(fft(payload.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
figure;stem(0:M-1,y_payload,"Marker","none","LineWidth",1);

