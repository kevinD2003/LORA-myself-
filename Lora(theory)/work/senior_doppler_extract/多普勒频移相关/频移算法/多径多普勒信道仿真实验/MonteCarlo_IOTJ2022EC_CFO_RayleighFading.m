%% A Low-Complexity LoRa Synchronization Algorithm Robust to Sampling Time Offsets
%% 小数部分CFO的估计与补偿。
%% LoRa under Carrier Frequency Offset with Rayleigh Fading
%% Monte Carlo实验 CFO+Rayleigh Fading
SF=12;
SNR=-25:20;
epsilon=[0.8];
N_upchirp=8;
N_payload=1;
BER_IOTJ2022=zeros(1,length(SNR));
% times=[1000*ones(1,6) 10000*ones(1,11) 100000*ones(1,9) 1000000*ones(1,11) 2000000*ones(1,11)];
times=[1000*ones(1,length(SNR))];
tic;
h=waitbar(0,['SF=' num2str(SF) ',IOTJ2022(EC) CFO + Rayleigh Fading']);
for j=1:length(SNR)
    error_lora=0;
    error_iotj2022=0;
    for jjj=1:times(j)
        [error]=IOTJ2022(SF,epsilon,SNR(j),N_upchirp,N_payload);
        error_iotj2022=error_iotj2022+error;
    end
    BER_IOTJ2022(j)=error_iotj2022/(times(j)*N_payload)/2;
    if(BER_IOTJ2022(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['IOTJ2022(EC) CFO + Rayleigh Fading.   SNR=' num2str(SNR(j))]);

end
%     waitbar(j/length(lambda),h,['\lambda=' num2str(lambda(j))]);
toc;
close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
c =['r';'y';'g';'c';'m'];
figure;
% for f=1:length(lambda)
% semilogy(SNR,BER_LoRa(f,:),'LineWidth',1,'Color','b','LineStyle','-','Marker',m(f));hold on
% semilogy(SNR,BER_IOTJ2022(f,:),'Color',c(f),'LineStyle','-','Marker',m(f));hold on
% end
semilogy(SNR,BER_IOTJ2022,'Color','r','LineStyle','-','Marker','v');hold on
xlabel('SNR');ylabel('BER');
legend(['EC,' num2str(N_upchirp) 'upchirps'])
grid on;

%% 
function [error]=IOTJ2022(SF,lambda,SNR,N_upchirp,N_payload)
error=0;
M=2^SF;
k=0:M-1;
n=0:N_upchirp*M-1;
a=randi([0 M-1],1,N_payload);
Nc=7;%7对连续的upchirp，即用了8个upchirp。
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+lambda(1)/M));
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
xk_payload=zeros(1,M*N_payload);
for i=1:1:N_payload
    xk_payload((i-1)*M+1:i*M)=exp(1j*2*pi*k.*(a(i)/M-1/2+k/2/M+lambda(1)/M));
end
S=[xk_preamble xk_payload];
 
%% 手动添加高斯噪声
sigPower=sum(abs(S.*S))/length(S);
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
for j=1:1:N_payload
    y_payload_tmp=r_payload((j-1)*M+1:j*M);
    Y_payload=fft(xk0.*y_payload_tmp.*exp(-1j*2*pi*(lambda_CFO+a_preamble-1)*k/M));%% dechrip+小数部分补偿+DFT；
    % Y_payload=[Y_payload(a_preamble:end) Y_payload(1:a_preamble-1)];%% 整数部分循环移位；也可以在dechirp后面做循环移位，再进行DFT。
    [~,d]=max(abs(Y_payload/M));
    if d-1~=a(j)
        error=error+1;
    end
end

 
end
