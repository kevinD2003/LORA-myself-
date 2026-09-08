%带频偏的LoRa计算误码率；
SF=7;
M=2^SF;
SNR=-15:1:-5;
times=10000000;
N_error_max=2000;
BER=zeros(1,length(SNR));
tic;
h=waitbar(0,['waiting,SF=' num2str(SF) '!']);
for i=1:1:length(SNR)
    error=0;
    for ii=1:1:times
        if error<N_error_max
            a=randi([0 M-1]);
            [error1]=Nerror(M,SNR(i),a);
            error=error+error1;
            N=ii;
        else
            break;
        end
    end
    BER(i)=error/N/2;
    if BER(i)<1E-6
        break;
    end
    waitbar(i/length(SNR),h,['SNR=',num2str(SNR(i)),'dB, 已完成']);
end

toc;
close(h);


%% 画图
figure;
semilogy(SNR,BER);
xlabel('SNR(dB)');ylabel('BER');
grid on;
%%
function [aaerror]=Nerror(M,SNR,aa)
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));
rk1=awgn(xk,SNR,'Measured');
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
end