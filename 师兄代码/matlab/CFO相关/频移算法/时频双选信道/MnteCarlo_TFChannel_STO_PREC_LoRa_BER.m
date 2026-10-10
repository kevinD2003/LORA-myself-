%% STO+多径+多普勒的LoRa计算误码率；
%% LoRa通信参数
B=250e3;
SF=10;
M=2^SF;
%% 信道参数
load('6path.mat');
%% 两径信道
num = 6;
hi = g(1:num) / g(1);
epsilon = fd(1:num) * M / B;
ui=ceil(tau(1:num) * B);

% hi = g / g(1);
% epsilon = fd * M / B;
% ui=ceil(tau * B);

% %% VehB channel
% power=[-2.5 0 -12.8 -10.0 -25.2 -16];%dB
% delay=[0 300 8900 12900 17100 20000];%ns
% hi=10.^(power/10);
% ui=ceil(B*delay*10^-9);
%% 假设收发双方相距5km(考虑仅由传播时延引起的STO)
distance = 5e3;%200m
t_sto = distance / (3e8);
N_t_sto = B * t_sto;%归一化
In_sto = floor(N_t_sto);%整数STO
Fr_sto = mod(N_t_sto,1);%小数STO
%% 
SNR=-25:1:30;
% times=1000000;
times = 1000;
N_error_max=200;
BER_PREC=zeros(1,length(SNR));
BER_LoRa=zeros(1,length(SNR));
tic;
h=waitbar(0,'waiting,SF=10');
for ii=1:1:length(SNR)
    error=0;
    error_LoRa = 0;
    for iii=1:1:times
        if error<N_error_max
            [error1, error_lora]=PREC(M,epsilon,ui,hi,In_sto,Fr_sto,SNR(ii));
            error=error+error1;
            error_LoRa = error_LoRa + error_lora;
            N=iii;
        else
            break;
        end
    end
    BER_PREC(1,ii)=error/N/2;
    BER_LoRa(1,ii)=error_LoRa/N/2;
%     if BER_PREC(1,ii)<1E-6 &&  BER_LoRa(1,ii)<1E-6
%         break;
%     end
    waitbar(ii/length(SNR),h,['SNR=',num2str(SNR(ii)),'dB']);
end

toc;
close(h);
%% 画图
figure;
semilogy(SNR,BER_PREC,'-o');hold on
semilogy(SNR,BER_LoRa,'g-^')
xlabel('SNR (dB)');ylabel('BER');
grid on;
ylim([10^-6 1]);
% xlabel('SNR(dB)','FontName','Times New Roman','FontSize',12);
% ylabel('$BER$','FontName','Times New Roman','Interpreter','latex','FontSize',12);grid on;
ylim([10^-6 1]);
legend('PREC', 'LoRa');

%% 
function [error, error_lora] = PREC(M,epsilon,ui,hi,In_sto,Fr_sto,SNR)
N_upchirp = 2;
error = 0;
error_lora = 0;
aa = randi([0 M-1]);
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(1)/M));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(1)/M));%前导符号
%% 加STO
STO_in = exp(1j*2*pi*In_sto*k/M);
STO_fr = exp(1j*2*pi*Fr_sto*k/M);
STO_fr = circshift(STO_fr, M-In_sto);
xk_sto = xk .* STO_in .* STO_fr;
xk_preamble_sto = xk_preamble .* STO_in .* STO_fr;
%%
xk_preamble_frame = zeros(1,N_upchirp*M);
for i = 1 : N_upchirp
    xk_preamble_frame((i-1)*M+1 : i*M) = xk_preamble_sto;
end
% % xk_frame=[xk_preamble_sto xk_preamble_sto xk_preamble_sto xk_preamble_sto xk_preamble_sto xk_preamble_sto xk_preamble_sto xk_preamble_sto xk_sto];
xk_frame = [xk_preamble_frame xk_sto];
xk_dp = hi(1) * xk_frame;

% 手动添加高斯噪声
sigPower=sum(abs(xk_dp.*xk_dp))/length(xk_dp);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(xk_frame))+1j*randn(1,length(xk_frame)));
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
%% 多径
rk_mpc = zeros(1,length(xk_frame));
for i = 2 : length(ui)
%     xk_tmp=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(i)/M)) .* STO_in .* STO_fr;
%     xk_preamble_tmp=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(i)/M)) .* STO_in .* STO_fr;%前导符号
    xk_tmp=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));
    xk_preamble_tmp=exp(1j*2*pi*k.*(-1/2+k/2/M));%前导符号
    %% 组帧
    xk_preamble_frame_tmp = zeros(1,N_upchirp*M);
    for ii = 1 : N_upchirp
        xk_preamble_frame_tmp((ii-1)*M+1 : ii*M) = xk_preamble_tmp;
    end
    xk_frame_tmp = [xk_preamble_frame_tmp xk_tmp];
    
%     rk_mpc_tmp = [zeros(1, ui(i)) xk_frame_tmp(1 : end - ui(i))];
    rk_mpc_tmp = [zeros(1, ui(i)) xk_frame_tmp(1 : end - ui(i))];
    for ii = 1 : N_upchirp+1
        rk_mpc_tmp((ii-1)*M+1 : ii*M) = rk_mpc_tmp((ii-1)*M+1 : ii*M) .*exp(1j*2*pi*k.*(epsilon(i)/M)) .* STO_in .* STO_fr;
    end
    rk_mpc = rk_mpc + hi(i)*rk_mpc_tmp;
end


rk1 = xk_dp + noise + rk_mpc;
% xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);%基信号的共轭
xk0 = exp(-1j*2*pi*k.*(-1/2+k/2/M));
%% estimation
r_preamble_ave=zeros(1,M);
%只用N_upchirp个前导码
for o=1:N_upchirp
    r_preamble=rk1((o-1)*M+1:o*M);
    r_preamble_ave=r_preamble_ave+r_preamble;
end
r_preamble_ave=r_preamble_ave/N_upchirp;
% y_upchirp=abs(fft(r_preamble_ave.*xk0))/M;

epsilon_i=0;
eta=0;
Yq_max=0;
eta_o=0;
step=0.1;
while eta_o<=0.9
    y_preamble_tem=abs(fft(r_preamble_ave.*exp(1j*2*pi*k*eta_o/M).*xk0));
    [Yq_max_tmp,epsilon_integer_tmp]=max(y_preamble_tem);
    if Yq_max_tmp > Yq_max
        Yq_max = Yq_max_tmp;
        epsilon_i = epsilon_integer_tmp;
        eta =eta_o;
    end
    eta_o=eta_o+step;
end
y_payload=abs(fft(rk1(N_upchirp*M+1:end).*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
% figure;stem(0:M-1,y_payload);
[~,d]=max(abs(y_payload));
if d - 1 ~= aa
   error = 1; 
end
% %% LoRa
% y_payload_withoutEC=abs(fft(rk1(N_upchirp*M+1:end).*xk0)/M);
% % figure;stem(0:M-1,y_payload_withoutEC);
% [~,d_lora]=max(abs(y_payload_withoutEC));
% if d_lora - 1 ~= aa
%    error_lora = 1; 
% end

end
