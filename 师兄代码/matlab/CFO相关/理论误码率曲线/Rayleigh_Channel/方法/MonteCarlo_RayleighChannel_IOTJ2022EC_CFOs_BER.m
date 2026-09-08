%% A Low-Complexity LoRa Synchronization Algorithm Robust to Sampling Time Offsets
%% 小数部分CFO的估计与补偿。
%% Monte Carlo实验
B=500e3;
SF=10;
SNR=-25:25;
lambda=[0.5];
BER_IOTJ2022=zeros(length(lambda),length(SNR));
% times=[100000*ones(1,4) 10000000*ones(1,2)];
times=[1000*ones(1,length(SNR))];
tic;
h=waitbar(0,['SF=' num2str(SF) ',\lambda=' num2str(lambda)]);
for j=1:length(lambda)
    for jj=1:length(SNR)
        error_lora=0;
        error_iotj2022=0;
        for jjj=1:times(jj)
            [error1]=IOTJ2022(SF,lambda(j),SNR(jj));
            error_iotj2022=error_iotj2022+error1;
        end
        BER_IOTJ2022(j,jj)=error_iotj2022/times(jj)/2;
        waitbar(jj/length(SNR),h,['\lambda=' num2str(lambda) ';SNR=' num2str(SNR(jj))]);
    end
end
toc;
close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
% c=['#64B6EA', '#FB8857', '#A788EB', '#80D172', '#FC7A77', '#61D4D5'];
c =['r';'y';'g';'c';'m'];
figure;
for f=1:length(lambda)
semilogy(SNR,BER_IOTJ2022(f,:),'Color',c(f),'LineStyle','-','Marker',m(f));hold on
end
xlabel('SNR');ylabel('BER');
legend(['SF=' num2str(SF) '\epsilon=' num2str(lambda)]);
grid on;

%% 
function [error1]=IOTJ2022(SF,lambda,SNR)
M=2^SF;
k=0:M-1;
n=0:8*M-1;
a=randi([0 M-1]);
Nc=7;
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+lambda/M));
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+lambda/M));
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));%8个前导码
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
S=[xk_preamble xk];
%% 手动添加高斯噪声
sigPower=sum(abs(S.*S))/M;
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(S))+1j*randn(1,length(S)));
%% 瑞利信道
omega = 1;
h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
rk=h_rayleigh*S+noise;
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


end
