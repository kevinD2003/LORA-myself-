%% 多径+多普勒的LoRa计算误码率；
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
%% 是否23交织
BICS_on = 1;
%% 
SNR=-25:1:30;
times=10000000;
% times = 100000;
N_error_max=2000;
BER_PREC=zeros(1,length(SNR));
BER_LoRa=zeros(1,length(SNR));
BER_Approx=zeros(1,length(SNR));
tic;
h=waitbar(0,'waiting,SF=10');
for ii=1:1:length(SNR)
    error=0;
    error_LoRa = 0;
    for iii=1:1:times
        if error<N_error_max
            [error1, error_lora]=PREC(M,epsilon,ui,hi,SNR(ii),BICS_on);
            error=error+error1;
            error_LoRa = error_LoRa + error_lora;
            N=iii;
        else
            break;
        end
    end
    BER_PREC(1,ii)=error/N/2;
    BER_LoRa(1,ii)=error_LoRa/N/2;
    if BER_PREC(1,ii)<1E-6 && BER_LoRa(1,ii)<1E-6
        break;
    end
    waitbar(ii/length(SNR),h,['SNR=',num2str(SNR(ii)),'dB']);
end

toc;
close(h);
%% 计算理论误码率
a = M / 2;
Aq_ncoh=getAq(a,SF,epsilon,ui,hi);
Aq=Aq_ncoh(a+1)/M;
% Aq=sin(pi*epsilon(1))/sin(pi*epsilon(1)/M)*exp(1j*pi*(1-1/M))/M;
Aq=abs(Aq);
% Aq=(Aq+Aq_ncoh(a+1)/M)/2;
Aq_ncoh(a+1)=0;
Aq_ncoh=sort(Aq_ncoh,'descend')/M;
% H=harmonic(M-2);%调和数
for i=1:1:length(SNR)
    SNR_dB=10^(SNR(i)/10);
    N_SI=getN(SF,Aq_ncoh,SNR_dB);
    nsi(1,i)=N_SI;%%%%%%%%%%%%%%%%%%%%%%%
    H=harmonic(M-N_SI-1);%调和数
    %噪声引起的误码率
    Pe_N=qfunc(Aq*sqrt(2*SNR_dB*M)-sqrt(2*H));
    %多径引起的误码率
    Pe_I=1;
    for k=1:N_SI
        Pe_I=Pe_I*(1-qfunc((Aq-Aq_ncoh(k))*sqrt(SNR_dB*M)));
    end
    %总误码率
    BER_Approx(1,i)=0.5*(1- (1-Pe_N)*Pe_I);
end 

%% 画图
figure;
semilogy(SNR,BER_PREC,'-o');hold on
semilogy(SNR,BER_LoRa,'g-^')
xlabel('SNR (dB)');ylabel('BER');
grid on;
ylim([10^-6 1]);
% legend(['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',ε=' num2str(epsilon(2))] );
% legend('三径信道，时延为0,6,10');

hold on
semilogy(SNR,BER_Approx(1,:),'r--*');hold on;%
% xlabel('SNR(dB)','FontName','Times New Roman','FontSize',12);
% ylabel('$BER$','FontName','Times New Roman','Interpreter','latex','FontSize',12);grid on;
ylim([10^-6 1]);
legend('PREC', 'LoRa', 'LoRa, Approx');
if BICS_on == 1
   legend('BICS-PREC', 'BICS-LoRa', 'LoRa, Approx'); 
end
% xlim([-25 35]);
% legend(['$L=' num2str(L) ',ncoh,Approx$'],'FontName','Times New Roman','Interpreter','latex','FontSize',8);
% legend(['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',v1=' num2str(v(1) * 18 / 5) 'km/h, v2=' num2str(v(2) * 18 / 5) 'km/h, simu'],...
%     ['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',v1=' num2str(v(1) * 18 / 5) 'km/h, v2=' num2str(v(2) * 18 / 5) 'km/h, Approx']);
% legend(['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',ε1=' num2str(epsilon(1)) ',ε2=' num2str(epsilon(2)) ', simu'],...
%     ['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',ε1=' num2str(epsilon(1)) ',ε2=' num2str(epsilon(2)) ', Approx']);

%%
function [Aq_ncoh]=getAq(a,SF,epsilon,ui,hi)
%获得理论叠加的多径在解调域上形成的幅值
M=2^SF;
Yq_t=zeros(1,M);
for q=0:1:M-1
    for i=1:length(ui)
        Yq_tem1=sin(pi*(1-ui(i)/M)*(q-a-epsilon(i)+ui(i)));
        Yq_tem2=sin(pi*(1/M)*(q-a-epsilon(i)+ui(i)));
        Yq_t_tem=(Yq_tem1/Yq_tem2)*exp(-1j*pi*(q*(1+ui(i)/M-1/M)+(a+epsilon(i))*(-1+ui(i)/M+1/M)-ui(i)/M));
        Yq_t(q+1)=Yq_t(q+1)+hi(i)*Yq_t_tem;
    end
end
for i=1:length(ui)
    if mod(epsilon(i),1)==0
       Yq_t(a+epsilon(i)-ui(i)+1)=0;
    end
end
for i=1:length(ui)
    if mod(epsilon(i),1)==0
       Yq_t(a+epsilon(i)-ui(i)+1)=Yq_t(a+epsilon(i)-ui(i)+1)+hi(i)*(M-ui(i));
    end
end
Aq_ncoh=abs(Yq_t);
% figure;
% plot(0:M-1,Aq_ncoh/M);
end

%% 获取干扰集的个数
function N=getN(SF,Aq_ncoh,SNR_dB)
M=2^SF;
N=0;
for i=1:M
    Aq_ncoh_tem=SNR_dB*(Aq_ncoh(i))^2*M;
    if 10*log10(Aq_ncoh_tem)>=1.3
        N=N+1;
    end
end

end


function [error, error_lora] = PREC(M,epsilon,ui,hi,SNR,BICS_on)
error = 0;
error_lora = 0;
aa = randi([0 M-1]);
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(1)/M));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(1)/M));%前导符号
%% 23交织
if BICS_on == 1
   xk = [xk(1 : M/4) xk(M/2 + 1 : 3 * M/4) xk(M/4 + 1 : M/2) xk(3 * M/4 + 1: M)];
   xk_preamble = [xk_preamble(1 : M/4) xk_preamble(M/2 + 1 : 3 * M/4) xk_preamble(M/4 + 1 : M/2) xk_preamble(3 * M/4 + 1: M)]; 
end
%% 组帧
xk_frame=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
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
    xk_tmp=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(i)/M));
    xk_preamble_tmp=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(i)/M));%前导符号
    %% 23交织
    if BICS_on == 1
        xk_tmp = [xk_tmp(1 : M/4) xk_tmp(M/2 + 1 : 3 * M/4) xk_tmp(M/4 + 1 : M/2) xk_tmp(3 * M/4 + 1: M)];
        xk_preamble_tmp = [xk_preamble_tmp(1 : M/4) xk_preamble_tmp(M/2 + 1 : 3 * M/4) xk_preamble_tmp(M/4 + 1 : M/2) xk_preamble_tmp(3 * M/4 + 1: M)];
    end
    %% 组帧
    xk_frame=[xk_preamble_tmp xk_preamble_tmp xk_preamble_tmp xk_preamble_tmp xk_preamble_tmp xk_preamble_tmp xk_preamble_tmp xk_preamble_tmp xk_tmp];
    %% 加时延
    rk_mpc_tmp = [zeros(1, ui(i)) xk_frame(1 : end - ui(i))];
    rk_mpc = rk_mpc + hi(i)*rk_mpc_tmp;
end


rk1 = xk_dp + noise + rk_mpc;
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);%基信号的共轭
r_preamble_ave=zeros(1,M);
%只用N_upchirp个前导码
N_upchirp=8;
for o=1:N_upchirp
    r_preamble=rk1((o-1)*M+1:o*M);
    r_preamble_ave=r_preamble_ave+r_preamble;
end
r_preamble_ave=r_preamble_ave/N_upchirp;
payload = rk1(N_upchirp*M+1:end);
%% 解交织
if BICS_on == 1
   r_preamble_ave = [r_preamble_ave(1: M/4) r_preamble_ave(M/2 + 1 : 3*M/4) r_preamble_ave(M/4 + 1 : M/2) r_preamble_ave(3*M/4 + 1 : M)]; 
   payload = [payload(1: M/4) payload(M/2 + 1 : 3*M/4) payload(M/4 + 1 : M/2) payload(3*M/4 + 1: M)];
end

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

y_payload=abs(fft(payload.*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
[~,d]=max(abs(y_payload));
if d - 1 ~= aa
   error = 1; 
end
%% LoRa
y_payload_withoutEC=abs(fft(payload.*xk0)/M);
[~,d_lora]=max(abs(y_payload_withoutEC));
if d_lora - 1 ~= aa
   error_lora = 1; 
end

end
