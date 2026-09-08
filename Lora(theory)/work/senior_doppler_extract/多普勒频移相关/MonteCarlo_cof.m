%带频偏的LoRa计算误码率；
B=125e3;
SF=7;
M=2^SF;
SNR=-20:1:5;
times=10000000;
%  f=rand(1,1);
%  f=f*B/(2*M)
%  f/B
%  f=-250;
f=0;
BER=zeros(1,length(SNR));
BERL=zeros(1,length(SNR));
tic;
h=waitbar(0,'waiting,SF=7,fd=-250Hz');
for i=1:1:length(SNR)
    error=0;
    errorL=0;
   for j=1:1:times
       a=randi([0 M-1]);
       [error1,error2]=Nerror(M,B,f,SNR(i),a);
       error=error+error1;
       errorL=errorL+error2;
   end
   BER(i)=error/times/2;
   BERL(i)=errorL/times/2;
   waitbar(i/length(SNR));
end
toc;
close(h);
%%
figure;
semilogy(SNR,BER,'r-o');hold on;
semilogy(SNR,BERL,'b-o');hold on;
xlabel('SNR(dB)');ylabel('BER');
grid on;
%%
legend('LoRa f_d=-250','LoRa f_d=0 ');
%xlim([-20 -4])
%%
function [aaerror,aaerrorL]=Nerror(M,B,f,SNR,aa)
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+f/B));
xkL=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));%不受多普勒频移
rk1=awgn(xk,SNR);
rk2=awgn(xkL,SNR);
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
    YqL=fft(rk2.*xk0)/M;
    YqL=abs(YqL);%非相干解调
    [~,decisionL]=max(YqL);
    if ((decisionL-1) ~= aa)
        aaerrorL = 1;
    else
        aaerrorL = 0;
    end
end