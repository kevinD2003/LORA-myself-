%% 卫星多普勒信道，多种抗频偏方案BER性能对比 。
%% 天启28星
% SF=7,B=125k;preamble:8,payload:22;883s,每秒钟33帧。
% SF=12,B=125k;preamble:8,payload:22;883s,每秒钟1帧。
%% Monte Carlo实验 CFO。
load('TQ28_CFO.mat');
B = 125e3;
SF=7;
M = 2^SF;
N_frame=33;
if SF==12
    N_frame=1;
end
N_upchirp=8;
N_payload=22+(8-N_upchirp);%数据块的装载
% SNR=-12:1:0;
SNR=-25:1:0;
BER_PRC=zeros(1,length(SNR));
BER_EC=zeros(1,length(SNR));
RMSE_PRC=zeros(1,length(SNR));
RMSE_EC=zeros(1,length(SNR));
times=883;
tic;
h=waitbar(0,['SF=' num2str(SF) ',TQ28']);
%% New Algorithm
for j=1:length(SNR)
    error_prc=0;
    rmse_prc=0;
    for jj=1:times
        epsilon = F_cfo(jj) * M / B;
        for jjj = 1 : N_frame
            [error1,rmse1]=PRC(SF,epsilon,SNR(j),N_payload,N_upchirp);
            error_prc=error_prc+error1;
            rmse_prc=rmse_prc+rmse1;
        end
    end
    BER_PRC(j)=error_prc/(times*N_payload*N_frame)/2;
    RMSE_PRC(j)=sqrt(rmse_prc/(times*N_frame));
    % if(BER_PRC(j)<1E-6)
    %     break;
    % end
    waitbar(j/length(SNR),h,['New AlgorithmSNR= ' num2str(SNR(j))]);
end



%% EC IOTJ2022
for j=1:length(SNR)
    error_ec=0;
    rmse_ec=0;
    for jj=1:times
        lambda = F_cfo(jj) * M / B;
        for jjj=1:N_frame
           [error1,rmse1]=EC(SF,lambda,SNR(j),N_payload,N_upchirp);
           error_ec=error_ec+error1;
           rmse_ec=rmse_ec+rmse1;
        end
    end
    BER_EC(j)=error_ec/(times*N_payload*N_frame)/2;
    RMSE_EC(j)=sqrt(rmse_ec/(times*N_frame));
    % if(BER_EC(j)<1E-6)
    %     break;
    % end
    waitbar(j/length(SNR),h,['EC,SNR=' num2str(SNR(j))]);
end

toc;
close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
c =['r';'y';'g';'c';'m'];
figure;
% for f=1:length(epsilon)
% % semilogy(SNR,BER_LoRa(f,:),'LineWidth',1,'Color','b','LineStyle','-','Marker',m(f));hold on
% semilogy(SNR,BER_FD_Shift(f,:),'Color',c(f),'LineStyle','-','Marker',m(f));hold on
% end
semilogy(SNR,BER_PRC,'Color','r','LineStyle','-','Marker','o');hold on;
semilogy(SNR,BER_EC,'Color',[0.07 0.62 1],'LineStyle','-','Marker','v');hold on
title(['TQ28 Satellite Channel, SF = ' num2str(SF) ', B = ' num2str(B) 'kHz']);
legend(['PRC,' num2str(N_upchirp) ' upchirps'],['EC,' num2str(N_upchirp) ' upchirps']);
xlabel('SNR');ylabel('BER')
figure;
semilogy(SNR,RMSE_PRC,'r-o');hold on;
semilogy(SNR,RMSE_EC,'b-x');
legend(['PRC,' num2str(N_upchirp) ' upchirps'],['EC,' num2str(N_upchirp) ' upchirps']);
xlabel('SNR');ylabel('RMSE')
grid on;




%% New Algorithm
function [error1,rmse]=PRC(SF,epsilon,SNR,N_payload,N_upchirp)
error1=0;
M=2^SF;
aa=randi([0 M-1], 1, N_payload);
k=0:1:M-1;
%% 调制
xk_payload=zeros(1,M*N_payload);
for i=1:N_payload
    xk_payload((i-1)*M+1:i*M)=exp(1j*2*pi*k.*(aa(i)/M-1/2+k/2/M+epsilon/M));
end
xk_pre=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
xk_preamble=zeros(1,M*N_upchirp);
for ii=1:1:N_upchirp
    xk_preamble((ii-1)*M+1:ii*M)=xk_pre;
end

%% 组帧
xk_frame=[xk_preamble xk_payload];
%% 加噪
rk1=awgn(xk_frame,SNR,'measured');
%% 解帧
rk_preamble=rk1(1:N_upchirp*M);
rk_payload=rk1(N_upchirp*M+1:end);
%% 解调
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);%基信号的共轭
% 前导码的处理
r_pre_ave=zeros(1,M);
%只用num个前导码
for o=1:N_upchirp
    rk_pre=rk_preamble((o-1)*M+1:o*M);
    r_pre_ave=r_pre_ave+rk_pre;

end
r_pre_ave=r_pre_ave/N_upchirp;

eta_fraction=(0:0.1:1);
Yq_max=zeros(1,length(eta_fraction));
for i=1:length(eta_fraction)
    y_preamble_tem=abs(fft(r_pre_ave.*exp(1j*2*pi*k*eta_fraction(i)/M).*xk0));
    Yq_max(i)=max(y_preamble_tem);
end
[~,eta_fraction_estimation]=max(Yq_max);
eta_fraction_estimation=eta_fraction(eta_fraction_estimation);%(eta_fraction_estimation-1)/10;
r_preamble_fc=r_pre_ave.*exp(1j*2*pi*k*eta_fraction_estimation/M);
y_preamble_fc=abs(fft(r_preamble_fc.*xk0))/M;

[~,epsilon_integer_estimation]=max(y_preamble_fc);
% 数据块的处理
for j=1:N_payload
    y_payload=abs(fft(rk_payload((j-1)*M+1:j*M).*xk0.*exp(1j*2*pi*k*(-epsilon_integer_estimation+eta_fraction_estimation+1)/M)))/M;
    [~,d]=max(abs(y_payload));
    if d-1~=aa(j)
        error1=error1+1;
    end
end

rmse=(mod(epsilon,M)-mod((epsilon_integer_estimation-eta_fraction_estimation-1),M))^2;

end


%% EC IOTJ2022
function [error1,rmse]=EC(SF,lambda,SNR,N_payload,N_upchirp)
error1=0;
M=2^SF;
k=0:M-1;
n=0:N_upchirp*M-1;
a=randi([0 M-1],1,N_payload);
Nc=7;
if N_upchirp==2
    Nc=2;
end
%% 调制
xk_payload=zeros(1,M*N_payload);
for i=1:N_payload
    xk_payload((i-1)*M+1:i*M)=exp(1j*2*pi*k.*(a(i)/M-1/2+k/2/M+lambda/M));
end
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+lambda/M));
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
%% 组帧
xk_frame=[xk_preamble xk_payload];
%% 加噪
rk1=awgn(xk_frame,SNR,'measured');
% %% 手动添加高斯噪声
% sigPower=sum(abs(S.*S))/length(S);
% reqSNR=10^(SNR/10);
% noisePower=sigPower/reqSNR;
% noise=sqrt(noisePower/2)*(randn(1,length(S))+1j*randn(1,length(S)));
% %% 瑞利信道
% omega = 1;
% h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
% rk=h_rayleigh*S+noise;
%% 解帧
rk_preamble=rk1(1:N_upchirp*M);
rk_payload=rk1(N_upchirp*M+1:end);


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
 for o=1:N_upchirp
     r_preamble_integer=r_preamble_integer+fft(rk_preamble((o-1)*M+1:o*M).*xk0_preamble((o-1)*M+1:o*M).*exp(-1j*2*pi*lambda_CFO*((o-1)*M+1:o*M)/M));
 end
 r_preamble_integer= r_preamble_integer/N_upchirp;
Yq_preamble_integer=r_preamble_integer;
[~,a_preamble]=max(Yq_preamble_integer);
%% 对payload的处理
for j=1:N_payload
    Y_payload=fft(xk0.*rk_payload((j-1)*M+1:j*M).*exp(-1j*2*pi*(lambda_CFO+a_preamble-1)*k/M));%% dechrip+小数部分补偿+DFT；
    % Y_payload=[Y_payload(a_preamble:end) Y_payload(1:a_preamble-1)];%% 整数部分循环移位；也可以在dechirp后面做循环移位，再进行DFT。
    [~,d]=max(abs(Y_payload/M));
    if d-1~=a(j)
        error1=error1+1;
    end
end


rmse=(mod(lambda,M)-mod((lambda_CFO+a_preamble-1),M))^2;

end
