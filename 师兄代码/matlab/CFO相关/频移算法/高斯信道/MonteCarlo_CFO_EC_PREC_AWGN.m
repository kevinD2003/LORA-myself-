%% Monte Carlo实验，多普勒-高斯信道
SF=8;
M = 2^SF;
% SNR=-25:1:-20;
SNR=-16:-4;
BER_PREC=zeros(1,length(SNR));
BER_EC=zeros(1,length(SNR));
RMSE_PREC=zeros(1,length(SNR));
RMSE_EC=zeros(1,length(SNR));
epsilon=0.8;
N_upchirp=8;
N_payload=1;
times=10000;
tic;
h=waitbar(0,['SF=' num2str(SF) ',计算中']);
% close(h);
%% methods
for j=1:length(SNR)
    error_prec=0;
    error_ec=0;
    rmse_prec=0;
    rmse_ec=0;
    for jj = 1 : times
        epsilon=rand();%SF=12,B=250k时，v=[0 75]km/h
        [error1,error2,rmse1,rmse2]=methods_PREC_EC(SF,epsilon,SNR(j),N_payload,N_upchirp);
        error_prec=error_prec+error1;
        error_ec=error_ec+error2;
        rmse_prec=rmse_prec+rmse1;
        rmse_ec=rmse_ec+rmse2;
    end
    BER_PREC(j)=error_prec/(times*N_payload)/2;
    BER_EC(j)=error_ec/(times*N_payload)/2;
    RMSE_PREC(j)=sqrt(rmse_prec/(times));
    RMSE_EC(j)=sqrt(rmse_ec/(times));
    % if(BER_PRC(j)<1E-6 && BER_EC(j)<1E-6)
    %     break;
    % end
    waitbar(j/length(SNR),h,['methods, SNR= ' num2str(SNR(j))]);
end
close(h);
toc;
% close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
c =['r';'y';'g';'c';'m'];
figure;
semilogy(SNR,BER_EC,'Color',[0.07 0.62 1],'LineStyle','-','Marker','v');hold on
semilogy(SNR,BER_PREC,'Color','r','LineStyle','-','Marker','o');hold on;
%title(['TQ28 Satellite Channel, SF = ' num2str(SF) ', B = 125kHz']);
legend(['EC,' num2str(N_upchirp) ' upchirps'],['PRC,' num2str(N_upchirp) ' upchirps']);
xlabel('SNR (dB)');ylabel('BER')
grid on;

figure;
plot(SNR,10*log10(RMSE_EC),'Color',[0.07 0.62 1],'LineStyle','-','Marker','v');hold on
plot(SNR,10*log10(RMSE_PREC),'Color','r','LineStyle','-','Marker','o');hold on;
%title(['TQ28 Satellite Channel, SF = ' num2str(SF) ', B = 125kHz']);
legend(['EC,' num2str(N_upchirp) ' upchirps'],['PRC,' num2str(N_upchirp) ' upchirps']);
xlabel('SNR (dB)');ylabel('RMSE (dB)')
grid on;


 % save(['RicianFading' num2str(cycle_times) 'time_' 'SF_' num2str(SF) '_' num2str(N_upchirp) '_upchirps_EC_PRC_TQ28_BER.mat'],...
 %    "BER_EC",'BER_PRC', ...
 %    'SNR','SF','B','N_upchirp','N_frame');
%% methods PRC ＆ EC 
function [error1,error2,rmse1,rmse2]=methods_PREC_EC(SF,epsilon,SNR,N_payload,N_upchirps)
error1=0;
error2=0;
M=2^SF;
aa=randi([0 M-1], 1, N_payload);
k=0:1:M-1;
%% PRC
%% 调制
xk_payload=zeros(1,M*N_payload);
for i=1:N_payload
    xk_payload((i-1)*M+1:i*M)=exp(1j*2*pi*k.*(aa(i)/M-1/2+k/2/M+epsilon/M));
end
xk_pre=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
xk_preamble=zeros(1,M*N_upchirps);
for ii=1:1:N_upchirps
    xk_preamble((ii-1)*M+1:ii*M)=xk_pre;
end

%% 组帧
xk_frame=[xk_preamble xk_payload];
%% 加噪
%% 手动添加高斯噪声
sigPower=sum(abs(xk_frame.*xk_frame))/length(xk_frame);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(xk_frame))+1j*randn(1,length(xk_frame)));
% %% 瑞利信道（Rayleigh Fading）
% omega = 1;
% % To generate a Rayleigh fading channel gain
% h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
% % k_factor = 10;
% % % To generate a Rician fading channel gain
% % h_rician = sqrt(k_factor/(k_factor+1)) + sqrt(1/(k_factor+1)) * h_rayleigh;
% % rk1=h_rician*xk_frame+noise;
% rk1=h_rayleigh*xk_frame+noise;
rk1=xk_frame+noise;
%% 解帧
rk_preamble=rk1(1:N_upchirps*M);
rk_payload=rk1(N_upchirps*M+1:end);
%% 解调
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);%基信号的共轭
% 前导码的处理
r_pre_ave=zeros(1,M);
%只用num个前导码
for o=1:N_upchirps
    rk_pre=rk_preamble((o-1)*M+1:o*M);
    r_pre_ave=r_pre_ave+rk_pre;

end
r_pre_ave=r_pre_ave/N_upchirps;
%% 估计
epsilon_i=0;
eta=0;
eta_o=0;
Yq_max=0;
step=0.1;
while eta_o<1
    y_preamble_tem=abs(fft(r_pre_ave.*exp(1j*2*pi*k*eta_o/M).*xk0));
    [Yq_max_tmp,epsilon_integer_tmp]=max(y_preamble_tem);
    if Yq_max_tmp>Yq_max
        Yq_max=Yq_max_tmp;
        eta=eta_o;
        epsilon_i=epsilon_integer_tmp;
    end
    eta_o=eta_o+step;
end
%% 补偿
for j=1:N_payload
    y_payload=abs(fft(rk_payload((j-1)*M+1:j*M).*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
    [~,d]=max(abs(y_payload));
    if d-1~=aa(j)
        error1=error1+1;
    end
end
% rmse1=(epsilon-(epsilon_i-eta-1))^2;
rmse1=(epsilon-(epsilon_i-eta-1))^2;





%% EC
n=0:N_upchirps*M-1;
Nc=7;
% Nc=3;
if N_upchirps==2
    Nc=2;
end
%% 调制
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+epsilon/M));
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
%% 组帧
xk_frame=[xk_preamble xk_payload];
% rk1=h_rician*xk_frame+noise;
% rk1=h_rayleigh*xk_frame+noise;
rk1=xk_frame+noise;
%% 解帧
rk_preamble=rk1(1:N_upchirps*M);
rk_payload=rk1(N_upchirps*M+1:end);
lambda_CFO=0;
for l=2:Nc
    y_l_1=rk_preamble((l-2)*M+1:(l-1)*M);
    y_l=rk_preamble((l-1)*M+1:l*M);
    Y_l=fft(y_l.*xk0_preamble((l-1)*M+1:l*M));
    Y_l_1=fft(y_l_1.*xk0_preamble((l-2)*M+1:(l-1)*M));
    [~,i]=max(abs(Y_l));
    lambda_cfo=0;
    for p=-2:2
        n=mod(i+p,M);
        if n==0
            n=M;
        end
        lambda_cfo=lambda_cfo+Y_l(n)*conj(Y_l_1(n));
    end
    lambda_CFO=lambda_CFO+lambda_cfo;
end
lambda_CFO=angle(lambda_CFO)/pi/2;
%% 整数部分 循环移位
r_preamble_integer=zeros(1,M);
 for o=1:N_upchirps
     r_preamble_integer=r_preamble_integer+fft(rk_preamble((o-1)*M+1:o*M).*xk0_preamble((o-1)*M+1:o*M).*exp(-1j*2*pi*lambda_CFO*((o-1)*M+1:o*M)/M));
 end
 r_preamble_integer= r_preamble_integer/N_upchirps;
Yq_preamble_integer=r_preamble_integer;
[~,a_preamble]=max(Yq_preamble_integer);
%% 对payload的处理
for j=1:N_payload
    Y_payload=fft(xk0.*rk_payload((j-1)*M+1:j*M).*exp(-1j*2*pi*(lambda_CFO+a_preamble-1)*k/M));%% dechrip+小数部分补偿+DFT；此处'-1'是因为matlab中数值的索引是从1开始的，但是整数部分的估计范围是0~M-1
    % Y_payload=[Y_payload(a_preamble:end) Y_payload(1:a_preamble-1)];%% 整数部分循环移位；也可以在dechirp后面做循环移位，再进行DFT。
    [~,d]=max(abs(Y_payload/M));
    if d-1~=aa(j)
        error2=error2+1;
    end
end
rmse2=(epsilon-(a_preamble-1+lambda_CFO))^2;
% rmse2=(epsilon+(lambda_CFO))^2;
end


