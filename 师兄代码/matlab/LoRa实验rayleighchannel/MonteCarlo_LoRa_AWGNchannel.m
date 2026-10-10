SF=7;
M=2^SF;
SNR=-20:1:-4;
times=100000;
N_error_max=20000000;
BER=zeros(1,length(SNR));
BER2=zeros(1,length(SNR));
tic;
h=waitbar(0,'waiting,SF=7');
for ii=1:1:length(SNR)
    error=0;
    error_2=0;
    for iii=1:1:times
        if error<N_error_max
            a=randi([0 M-1]);
            [error1,error2]=Nerror(M,SNR(ii),a);
            error=error+error1;
            error_2=error_2+error2;
            N=iii;
        else
            break;
        end
    end
    BER(1,ii)=error/N/2;
     BER2(1,ii)=error_2/N/2;
    if BER(1,ii)<1E-6
        break;
    end
end
toc;
close(h);
%%
figure;
semilogy(SNR,BER,'r-');hold on 
semilogy(SNR,BER2,'b--');
%% LoRa
function [aaerror,aerror]=Nerror(M,SNR,aa)
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));
rk1=awgn(xk,SNR);
%解调,传统
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
Yq=fft(rk1.*xk0)/M;
Yq=abs(Yq);%非相干解调
[~,decision]=max(Yq);
    if ((decision-1) ~= aa)
        aaerror = 1;
    else
        aaerror = 0;
    end
%% 手动添加高斯噪声
sigPower=sum(abs(xk.*xk))/M;
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,M)+1j*randn(1,M));
rk2=xk+noise;
Yq2=fft(rk2.*xk0)/M;
Yq2=abs(Yq2);%非相干解调
[~,decision2]=max(Yq2);
    if ((decision2-1) ~= aa)
        aerror = 1;
    else
        aerror = 0;
    end
end

