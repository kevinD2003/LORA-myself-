%% 卫星多普勒信道，多种抗频偏方案BER性能对比 。
%% 天启28星
% SF=7,B=125k;preamble:8,payload:22;883s,每秒钟33帧。
% SF=12,B=125k;preamble:8,payload:22;883s,每秒钟1帧。
%% Monte Carlo实验 CFO。
load('TQ28_CFO.mat');
B = 125e3;
SF=12;
M = 2^SF;
N_frame=33;
if SF==12
    N_frame=1;
end
N_upchirp=2;
N_payload=22+(8-N_upchirp);%数据块的装载
% SNR=-12:1:0;
SNR=-25:0;
BER_FD_Shift=zeros(1,length(SNR));
BER_DCSS=zeros(1,length(SNR));
BER_LoRa=zeros(1,length(SNR));
BER_IOTJ2022=zeros(1,length(SNR));
BER_MF=zeros(1,length(SNR));
times=883;
tic;
h=waitbar(0,['SF=' num2str(SF) ',TQ28']);

%% LoRa
for j=1:length(SNR)
    error_lora=0;
    for jj=1:times
        lambda = F_cfo(jj) * M / B;
        for jjj=1:N_frame
           [error2]=LoRa(SF,lambda,SNR(j),N_payload,N_upchirp);
           error_lora=error_lora+error2;
        end
    end
    BER_LoRa(j)=error_lora/(times*N_payload*N_frame)/2;
    if(BER_LoRa(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['LoRa,SNR=' num2str(SNR(j))]);
end


%% New Algorithm
for j=1:length(SNR)
    error=0;
    for jj=1:times
        epsilon = F_cfo(jj) * M / B;
        for jjj = 1 : N_frame
            [error1]=FD_Shift(SF,epsilon,SNR(j),N_payload,N_upchirp);
            error=error+error1;
        end
    end
    BER_FD_Shift(j)=error/(times*N_payload*N_frame)/2;
    if(BER_FD_Shift(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['New AlgorithmSNR= ' num2str(SNR(j))]);
end

%% MF
for i=1:1:length(SNR)
    error_mf=0;
   for j=1:1:times
       epsilon = F_cfo(j) * M / B;
       for jj=1:N_frame
           [errormf]=MF(M,epsilon,SNR(i),N_payload,N_upchirp);
           error_mf=error_mf+errormf;
       end
   end
   BER_MF(i)=error_mf/(N_frame*N_payload*times)/2;
   if BER_MF(i)<1E-6
       break;
   end
   waitbar(i/length(SNR),h,['MF,SF=' num2str(SF) ',SNR=' num2str(SNR(i))]);
end

%% EC IOTJ2022
for j=1:length(SNR)
    error_iotj2022=0;
    for jj=1:times
        lambda = F_cfo(jj) * M / B;
        for jjj=1:N_frame
           [error1]=IOTJ2022(SF,lambda,SNR(j),N_payload,N_upchirp);
           error_iotj2022=error_iotj2022+error1;
        end
    end
    BER_IOTJ2022(j)=error_iotj2022/(times*N_payload*N_frame)/2;
    if(BER_IOTJ2022(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['EC,SNR=' num2str(SNR(j))]);
end

%% DCSS
for j=1:length(SNR)
    error_dcss=0;
    for jj=1:times
        epsilon = F_cfo(jj) * M / B;
        for jjj=1:N_frame
            error=DCSS(SF,epsilon,SNR(j),N_payload);
            error_dcss=error_dcss+error;
        end
        
    end
    BER_DCSS(j)=error_dcss/(times*(N_payload-1)*N_frame)/2;
    if(BER_DCSS(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['DCSS,SNR=' num2str(SNR(j))]);
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
semilogy(SNR,BER_LoRa,'LineWidth',1,'Color','b','LineStyle','-','Marker','+');hold on
semilogy(SNR,BER_FD_Shift,'Color','r','LineStyle','-','Marker','o');hold on;
semilogy(SNR,BER_IOTJ2022,'Color',[0.07 0.62 1],'LineStyle','-','Marker','v');hold on
semilogy(SNR,BER_DCSS,'LineStyle','-','Color','g','Marker','*');hold on;
semilogy(SNR,BER_MF,'m-s');hold on;
title(['TQ28 Satellite Channel, SF = ' num2str(SF) ', B = ' num2str(B) 'kHz']);
legend(['LoRa'],['New Algorithm,' num2str(N_upchirp) ' upchirps'],['EC,' num2str(N_upchirp) ' upchirps'],...
    ['DCSS,' num2str(N_upchirp) ' upchirps'],['MF,' num2str(N_upchirp) ' upchirps']);
xlabel('SNR');ylabel('BER')
grid on;


%% LoRa
function [error]=LoRa(SF,lambda,SNR,N_payload,N_upchirp)
error=0;
M=2^SF;
k=0:M-1;
n=0:N_upchirp*M-1;
a=randi([0 M-1],1,N_payload);
%% 调制
xk_payload=zeros(1,M*N_payload);
for i=1:N_payload
    xk_payload((i-1)*M+1:i*M)=exp(1j*2*pi*k.*(a(i)/M-1/2+k/2/M+lambda/M));
end
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+lambda/M));
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
%% 组帧
xk_frame=[xk_preamble xk_payload];%因为LoRa用不到前导码的upchirp，其实只传数据部分即可。
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


%% 未补偿DNC
for j=1:N_payload
    Y_payload_DNC=fft(xk0.*rk_payload((j-1)*M+1:j*M));
    [~,dnc]=max(abs(Y_payload_DNC/M));
    if dnc-1~=a(j)
        error=error+1;
    end
end

end


%% New Algorithm
function [error1]=FD_Shift(SF,epsilon,SNR,N_payload,N_upchirp)
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
end


%% DCSS
function error_dcss=DCSS(SF,epsilon,SNR,N_payload)
error_dcss=0;
M=2^SF;
Sp=randi([1 M-1],1,N_payload);
Dp=zeros(1,length(Sp));
Dp(1)=Sp(1);
for i=2:N_payload
    Dp(i)=mod((Sp(i)+Dp(i-1)),M);
end
k=0:1:M-1;
xk_payload=zeros(1,N_payload*M);
for ii=1:N_payload
    xk_payload((ii-1)*M+1:ii*M)=exp(1j*2*pi*k.*(Dp(ii)/M-1/2+k/2/M+epsilon/M));%调制
end
xk_pre=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导码
xk_preamble=[xk_pre xk_pre xk_pre xk_pre xk_pre xk_pre xk_pre xk_pre];
xk_frame=[xk_preamble xk_payload];%组帧
rk1=awgn(xk_frame,SNR,'measured');
% %% 手动添加高斯噪声
% sigPower=sum(abs(Sk_frame.*Sk_frame))/length(Sk_frame);
% reqSNR=10^(SNR(j)/10);
% noisePower=sigPower/reqSNR;
% noise=sqrt(noisePower/2)*(randn(1,length(Sk_frame))+1j*randn(1,length(Sk_frame)));
% %% 瑞利信道
% omega = 1;
% h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
% Rk_frame=h_rayleigh*Sk_frame+noise;

%% 解帧
rk_preamble=rk1(1:8*M);
rk_payload=rk1(8*M+1:end);
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
Dp_ncoh=zeros(1,N_payload);
for o=1:N_payload
    Yq=abs(fft(rk_payload((o-1)*M+1:o*M).*xk0)/M);
    %     figure;plot(0:M-1,Yq);
    [~,decision]=max(Yq);
    Dp_ncoh(o)=decision-1;
end
Sp_ncoh=zeros(1,N_payload);

for iii=2:N_payload
    Sp_ncoh(iii)=mod(Dp_ncoh(iii)-Dp_ncoh(iii-1),M);
    if Sp_ncoh(iii)~=Sp(iii)
        error_dcss=error_dcss+1;
    end
end
end


%% EC IOTJ2022
function [error1]=IOTJ2022(SF,lambda,SNR,N_payload,N_upchirp)
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

end



%% MF算法
function [error1]=MF(M,epsilon,SNR,N_payload,N_upchirp)
error1=0;
aa=randi([0 M-1], 1, N_payload);
k=0:1:M-1;
%% 调制
xk_payload=zeros(1,M*N_payload);
for i=1:N_payload
    xk_payload((i-1)*M+1:i*M)=exp(1j*2*pi*k.*(aa(i)/M-1/2+k/2/M+epsilon/M));
end
xk_pre=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
xk_preamble=zeros(1,M*N_upchirp);
for ii=1:N_upchirp
    xk_preamble((ii-1)*M+1:ii*M)=xk_pre;
end
%% 组帧
xk_frame=[xk_preamble xk_payload];
%% 加噪
rk1=awgn(xk_frame,SNR,'measured');
%% 解帧
rk_preamble=rk1(1:N_upchirp*M);
rk_payload=rk1(N_upchirp*M+1:end);
alpha=0.25;
% %% 手动添加高斯噪声
% sigPower=sum(abs(Sd.*Sd))/length(Sd);
% reqSNR=10^(SNR/10);
% noisePower=sigPower/reqSNR;
% noise=sqrt(noisePower/2)*(randn(1,length(Sd))+1j*randn(1,length(Sd)));
% %% 瑞利信道
% omega = 1;
% h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
% rk1=h_rayleigh*Sd+noise;

xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);%基信号的共轭
y_preamble=zeros(1,M);
for o=1:N_upchirp
    r_pre=rk_preamble((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_pre.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=y_preamble/N_upchirp;%取平均
for j=1:N_payload
    y_payload=abs(fft(rk_payload((j-1)*M+1:j*M).*xk0))/M;
    %圆周相关运算
    R=zeros(1,M);
    for d=1:M
        y_tem=[y_payload(d:end) y_payload(1:d-1)];
        R(d)=sum(y_preamble.*y_tem);
    end
    %解调,传统
    [~,decision]=max(R);
    if ((decision-1) ~= aa(j))
        error1 =error1 + 1;
    end
end

end
