%% LoRa under Carrier Frequency Offset with Rayleigh Fading
%% Monte Carlo实验 CFO+Rayleigh Fading
SF=12;
SNR=-25:5:20;
% SNR = -6;
epsilon=0.8;
BER_LoRa=zeros(1,length(SNR));
times=100;
tic;
h=waitbar(0,['SF=' num2str(SF) 'LoRa, Rayleigh Fading + CFO']);
for j=1:length(SNR)
    error_lora=0;
    for jjj=1:times
        [error]=LoRa(SF,epsilon,SNR(j));
        error_lora=error_lora+error;
    end
    BER_LoRa(j)=error_lora/times/2;
    if(BER_LoRa(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['LoRa, Rayleigh Fading + CFO.  SNR = ' num2str(SNR(j))]);

end
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
semilogy(SNR,BER_LoRa,'LineWidth',1,'Color','b','LineStyle','-','Marker','+');hold on
xlabel('SNR');ylabel('BER');
legend('LoRa,Rayleigh Fading');
grid on;

%% 
function [error]=LoRa(SF,epsilon,SNR)
M=2^SF;
k=0:M-1;
n=0:8*M-1;
a=randi([0 M-1]);
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(1)/M));
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+epsilon(1)/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
S=[xk_preamble xk];

%% 手动添加高斯噪声
sigPower=sum(abs(S.*S))/length(S);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(S))+1j*randn(1,length(S)));
%% 瑞利信道
omega = 1;
h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
rk=h_rayleigh*S+noise;
r_payload=rk(8*M+1:end);
%% 未补偿DNC
Y_payload_DNC=fft(xk0.*r_payload);
[~,dnc]=max(abs(Y_payload_DNC/M));
if dnc-1==a
    error=0;
else
    error=1;
end

end
