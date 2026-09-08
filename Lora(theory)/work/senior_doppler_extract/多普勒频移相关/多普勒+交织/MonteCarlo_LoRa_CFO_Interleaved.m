%% 多径+多普勒的LoRa计算误码率；
B=250e3;
epsilon=[0.2];
% epsilon = 0;
%% 
SF=7;
M=2^SF;
SNR=-15:15;
times=10000000;
N_error_max=2000;
BER=zeros(1,length(SNR));
tic;
h=waitbar(0,'waiting,SF=10');
for ii=1:1:length(SNR)
    error=0;
    for iii=1:1:times
        if error<N_error_max
            [error1]=Nerror(M,epsilon,SNR(ii));
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

%% 画图
figure;
semilogy(SNR,BER,'-o')
xlabel('SNR(dB)');ylabel('BER');
grid on;
ylim([10^-6 1]);
legend(['SF=' num2str(SF) ',ε=' num2str(epsilon) ',LoRa'] );
%% 
function [aaerror]=Nerror(M,epsilon,SNR)
a=randi([0 M-1]);
% a=M/2;
k=0:1:M-1;
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
rkm=zeros(1,M);
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M));%直达径信号
%% Interleaved
xk=[xk(1:M/4) xk(M/2+1:3*M/4) xk(M/4+1:M/2) xk(3*M/4+1:end)];
xk=xk.*exp(1j*2*pi*k.*(epsilon(1)/M));%直达径信号交织后加多普勒
%% 加噪
sigPower=sum(abs(xk.*xk))/M;
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,M)+1j*randn(1,M));
rk=xk+rkm+noise;%先加噪再衰减；
%% Deinterleaved
rk=[rk(1:M/4) rk(M/2+1:3*M/4) rk(M/4+1:M/2) rk(3*M/4+1:end)];
%% 
Yq=abs(fft(rk.*xk0)/M);%非相干解调
% figure;stem(0:M-1,Yq);
[~,decision]=max(Yq);
    if ((decision-1) ~= a)
        aaerror = 1;
    else
        aaerror = 0;
    end
end
