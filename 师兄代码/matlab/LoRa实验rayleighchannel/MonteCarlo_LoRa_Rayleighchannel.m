SF=12;
M=2^SF;
SNR=-30:1:25;
times=1000000;
N_error_max=20000000;
BER=zeros(1,length(SNR));
tic;
h=waitbar(0,'waiting,SF=7');
for ii=1:1:length(SNR)
    error=0;
    error_2=0;
    for iii=1:1:times
        if error<N_error_max
            a=randi([0 M-1]);
            [error1]=Nerror(M,SNR(ii),a);
            error=error+error1;
            N=iii;
        else
            break;
        end
    end
    BER(1,ii)=error/N/2;
    if BER(1,ii)<1E-6
        break;
    end
     waitbar(ii/length(SNR),h,['SNR=',num2str(SNR(ii)),'dB']);
end
toc;
close(h);
%% 计算瑞利信道理论值
Pb=zeros(1,length(SNR));
H=harmonic(M-1);%调和数
for i=1:length(SNR)
    snr=10^(SNR(i)/10);
    Pb(i)=0.5*(qfunc(-sqrt(2*H))-sqrt(M*snr/(M*snr+1))*exp(-2*H/(2*(M*snr+1)))*qfunc(sqrt((M*snr)/(M*snr))*(-sqrt(2*H)+sqrt(2*H)/(M*snr+1))));
end

%%
figure;
semilogy(SNR,BER,'b--p','Markersize',8);hold on 
semilogy(SNR,Pb,'r--s','Markersize',8);hold on
xlabel('SNR(dB)');ylabel('BER');
legend('SF=12,Rayleigh channel,simu','SF=12,Payleigh channel,Approx');
ylim([10^(-4) 1]);
grid on
%% LoRa
function [aerror]=Nerror(M,SNR,aa)
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
%% 手动添加高斯噪声
sigPower=sum(abs(xk.*xk))/M;
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,M)+1j*randn(1,M));
%% 瑞利信道
omega = 1;
h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
rk2=h_rayleigh*xk+noise;
Yq2=fft(rk2.*xk0)/M;
Yq2=abs(Yq2);%非相干解调
[~,decision2]=max(Yq2);
    if ((decision2-1) ~= aa)
        aerror = 1;
    else
        aerror = 0;
    end
end

