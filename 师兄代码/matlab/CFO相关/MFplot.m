% 画 图用
%带频偏的LoRa计算误码率；
B=125e3;
SF=7;
M=2^SF;
% SNR=-20:1:10;
SNR=10;
times=1;
%  f=rand(1,1);
%  f=f*B/(2*M)
%  f/B
fd=976.5625;%多普勒频偏Hz
% fd=0;
BER_Doppler=zeros(1,length(SNR));
BER_LoRa=zeros(1,length(SNR));
BER_MF=zeros(1,length(SNR));
tic;
h=waitbar(0,'LoRa,SF=7,fd=1200Hz');
for i=1:1:length(SNR)
    error=0;
    errorL=0;
   for j=1:1:times
       [error1,error2]=Nerror(M,B,fd,SNR(i));
       error=error+error1;
       errorL=errorL+error2;
   end
   BER_Doppler(i)=error/times/2;
   BER_LoRa(i)=errorL/times/2;
   waitbar(i/length(SNR));
end
toc;
close(h);


h=waitbar(0,'MF,SF=7,fd=1200Hz');
for i=1:1:length(SNR)
    error_mf=0;
   for j=1:1:times
       error_mf=error_mf+MF(M,B,fd,SNR(i));
   end
   BER_MF(i)=error_mf/times/2;
   waitbar(i/length(SNR));
end
toc;
close(h);
%%
figure;
semilogy(SNR,BER_LoRa,'b-o');hold on;
semilogy(SNR,BER_Doppler,'r-*');hold on;
semilogy(SNR,BER_MF,'m-s');hold on;
xlabel('SNR(dB)');ylabel('BER');
grid on;
legend('LoRa,f_d=0 ','LoRa,f_d=\Deltaf','MF,f_d=\Deltaf');
%xlim([-20 -4])
title('B=125KHz,SF=7,\Deltaf=B/M=976.5625Hz');
%% LoRa调制解调；受到多普勒频偏影响的LoRa调制解调。
function [aaerror,aaerrorL]=Nerror(M,B,fd,SNR)
aa=randi([0 M-1]);
k=0:1:M-1;  
xk_Doppler=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));%受到多普勒频偏影响的LoRa信号
xk_LoRa=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));%不受多普勒频移
rk1=awgn(xk_Doppler,SNR,'measured');
rk2=awgn(xk_LoRa,SNR,'measured');
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


%% MF算法
function error=MF(M,B,fd,SNR)
% aa=randi([0 M-1]);
aa=M/2;
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk];
% rk1=awgn(Sd,SNR,'measured');
rk1=Sd;
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:1
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
figure;subplot(3,1,2);plot(0:M-1,y_preamble);xlabel('q');ylabel('X_q_2');xlim([0 M-1]);title('SF=7,前导码a=0');hold on;
% y_preamble=y_preamble/1;
y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;
subplot(3,1,1);plot(0:M-1,y_payload);xlabel('q');ylabel('X_q_1');xlim([0 M-1]);title('SF=7,数据块a=64');hold on;
%圆周相关运算
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble_tem.*y_tem);
end
subplot(3,1,3);plot(0:M-1,R);xlabel('d');ylabel('R');xlim([0 M-1]);title('圆周相关');hold on;
%解调,传统
[~,decision]=max(R);
if ((decision-1) ~= aa)
    error = 1;
else
    error = 0;
end
end