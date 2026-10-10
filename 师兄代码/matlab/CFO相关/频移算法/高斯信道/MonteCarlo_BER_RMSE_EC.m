%% A Low-Complexity LoRa Synchronization Algorithm Robust to Sampling Time Offsets
%% 小数部分CFO的估计与补偿。
%% Monte Carlo实验
B=500e3;
SF=12;
SNR=-25:-20;
% SNR=-10;
% SNR=-16:-4;
lambda=[0.8];
BER_EC=zeros(length(lambda),length(SNR));
RMSE_EC=zeros(length(lambda),length(SNR));
% times=[100000*ones(1,4) 10000000*ones(1,2)];
times=[10000*ones(length(lambda),length(SNR))];
tic;
h=waitbar(0,'SF=12,\lambda=0.8');
for j=1:length(lambda)
    for jj=1:length(SNR)
        error_iotj2022=0;
        rmse=0;
        for jjj=1:times(jj)
            % [error1,rmse1]=IOTJ2022(SF,lambda(j),SNR(jj));
            % a = -0.5;
            % b = 0.5;
            % 生成[0,1]区间内的均匀分布随机数
            % random_number = rand();
            % 将随机数缩放到[a, b]区间
            % f = a + (b - a) * random_number;
            % [error1,rmse1]=IOTJ2022(SF,f,SNR(jj));
%             ep=-0.5:0.1:0.5;
            ep = 0.8;
%             index=randi([1 11],1,1);
%             [error1,rmse1]=IOTJ2022(SF,ep(index),SNR(jj));
            [error1,rmse1]=IOTJ2022(SF,ep,SNR(jj));
            error_iotj2022=error_iotj2022+error1;
            rmse=rmse+rmse1;
        end
        BER_EC(j,jj)=error_iotj2022/times(jj)/2;
        RMSE_EC(j,jj)=sqrt(rmse/(times(jj)));
        waitbar(jj/length(SNR),h,['\lambda=0.8;SNR=' num2str(SNR(jj))]);
    end
%     waitbar(j/length(lambda),h,['\lambda=' num2str(lambda(j))]);
end
toc;
close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
% c=['#64B6EA', '#FB8857', '#A788EB', '#80D172', '#FC7A77', '#61D4D5'];
c =['r';'y';'g';'c';'m'];
figure;
for f=1:length(lambda)
semilogy(SNR,BER_EC(f,:),'Color',c(f),'LineStyle','-','Marker',m(f));hold on
end
xlabel('SNR');ylabel('BER');
% legend('\lambda=0,DNC','\lambda=0,IOTJ2022','\lambda=0.1,DNC','\lambda=0.1,IOTJ2022','\lambda=0.2,DNC','\lambda=0.2,IOTJ2022','\lambda=0.3,DNC','\lambda=0.3,IOTJ2022','\lambda=0.4,DNC','\lambda=0.4,IOTJ2022','\lambda=0.5,DNC','\lambda=0.5,IOTJ2022','\lambda=0.6,DNC','\lambda=0.6,IOTJ2022','\lambda=0.7,DNC','\lambda=0.7,IOTJ2022');
% legend('\lambda=0,DNC','\lambda=0,IOTJ2022','\lambda=0.2,DNC','\lambda=0.2,IOTJ2022','\lambda=0.4,DNC','\lambda=0.4,IOTJ2022','\lambda=0.5,DNC','\lambda=0.5,IOTJ2022','\lambda=0.7,DNC','\lambda=0.8,IOTJ2022')
legend('\lambda=0.8,DNC','\lambda=0.8,IOTJ2022');
grid on;
figure;
RMSE_dB = 10*log10(RMSE_EC);
plot(SNR,RMSE_dB,'b-x');
% ylim([10^-2 1])
xlabel('SNR');ylabel('RMSE (dB)');
grid on;

%% 
function [error1,rmse]=IOTJ2022(SF,lambda,SNR)
M=2^SF;
k=0:M-1;
n=0:8*M-1;
a=randi([0 M-1]);
% Nc=7;
% Nc=7;
Nc=2;
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+lambda/M));
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+lambda/M));
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
S=[xk_preamble xk];
rk=awgn(S,SNR,'measured');
lambda_CFO=0;
for l=2:Nc
    y_l_1=rk((l-2)*M+1:(l-1)*M);
    y_l=rk((l-1)*M+1:l*M);
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
 for o=1:8
     r_preamble_integer=r_preamble_integer+fft(rk((o-1)*M+1:o*M).*xk0_preamble((o-1)*M+1:o*M).*exp(-1j*2*pi*lambda_CFO*((o-1)*M+1:o*M)/M));
 end
 r_preamble_integer= r_preamble_integer/8;
Yq_preamble_integer=r_preamble_integer;
[~,a_preamble]=max(Yq_preamble_integer);
%% 对payload的处理
r_payload=rk(8*M+1:end);
Y_payload=fft(xk0.*r_payload.*exp(-1j*2*pi*lambda_CFO*k/M));%% dechrip+小数部分补偿+DFT；
Y_payload=[Y_payload(a_preamble:end) Y_payload(1:a_preamble-1)];%% 整数部分循环移位；也可以在dechirp后面做循环移位，再进行DFT。
[~,d]=max(abs(Y_payload/M));
if d-1==a
    error1=0;
else
    error1=1;
end

rmse=(mod(lambda,M)-mod((lambda_CFO+a_preamble-1),M))^2;
% rmse=(lambda-lambda_CFO)^2;

end
