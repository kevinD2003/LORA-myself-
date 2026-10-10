%% 查找判决门限
%带频偏的LoRa计算误码率；
B=125e3;
SF=9;
M=2^SF;
SNR=-20:1:5;
times=1000000;
% SNR=-6;
% times=1000;
fd=0.7*B/M;%多普勒频偏Hz
BER_Doppler=zeros(1,length(SNR));
BER_LoRa=zeros(1,length(SNR));
BER_MF=zeros(1,length(SNR));
BER_MF_IBD=zeros(1,length(SNR));
Ratio_MF=zeros(length(SNR),times);
Ratio_min=zeros(1,length(SNR));
Ratio_max=zeros(1,length(SNR));
Ratio_mean=zeros(1,length(SNR));
%% MF 匹配滤波法
tic;
h2=waitbar(0,'MF,SF=7,fd=0.8*\Deltaf');
for i=1:1:length(SNR)
   for j=1:1:times
       Ratio_MF(i,j)=MF(M,B,fd,SNR(i));
   end
   Ratio_min(i)=min(Ratio_MF(i,:));
   Ratio_max(i)=max(Ratio_MF(i,:));
   Ratio_mean(i)=sum(Ratio_MF(i,:))/times;
   waitbar(i/length(SNR));
end
toc;
close(h2);

%%
figure;
plot(SNR,Ratio_min,'b-');hold on;
plot(SNR,Ratio_max,'r-');hold on;
plot(SNR,Ratio_mean,'g-');hold on;
xlabel('SNR(dB)');ylabel('Ratio');
grid on;
legend('min','max','mean');
title('0.7')
% legend('LoRa,f_d=0 ','LoRa,f_d=0.7*\Deltaf','MF,f_d=0.7*\Deltaf','MF-块内分集,f_d=0.7*\Deltaf');
%xlim([-20 -4])
% title('B=125KHz,SF=7,\Deltaf=B/M=976.5625Hz');
%% MF算法
function [ratio]=MF(M,B,fd,SNR)
aa=randi([0 M-1]);
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
rk1=awgn(Sd,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:8
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=(y_preamble/8);
ratio=y_preamble(1)/y_preamble(2);

end

