%% 带频偏的LoRa计算误码率；
B=125e3;
SF=7;
M=2^SF;
SNR=-20:1:5;
times=10000;
% SNR=-6;
% times=1000;
fd=[0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1]*B/M;
BER_MF=zeros(length(fd),length(SNR));
BER_LoRa_Doppler=zeros(length(fd),length(SNR));
%% MF 匹配滤波法
tic;
h2=waitbar(0,'MF,SF=7');
for ii=1:length(fd)
    for i=1:1:length(SNR)
        error_mf=0;
        error_d=0;
        error_LoRa=0;
        for j=1:1:times
            [errormf,errorlora]=MF(M,B,fd(ii),SNR(i));
            error_mf=error_mf+errormf;
            error_LoRa=error_LoRa+errorlora;
        end
        BER_MF(ii,i)=error_mf/times/2;
        BER_LoRa_Doppler(ii,i)=error_LoRa/times/2;
    end
    waitbar(ii/length(fd));
end
toc;
close(h2);

%%
figure;
c=['k';'m';'c';'b';'g';'r'];
m=['x';'d';'s';'*';'+';'o'];
% c=[0 0 0;
%     0.39216 0.58431 0.92941;
%     0.51765 0.43922 1;
%     0 1 1;
%     1 0.5 0;
%     0.6902 0.18824 0.37647;
%     0.51373 0.43529 1;
%     0.06275 0.30588 0.5451;
%     0.5451 0.4902 0.48235;
%     ];
for f=1:6%length(fd)
    semilogy(SNR,BER_MF(f,:),'LineStyle','-','Color',c(f,:),'Marker',m(f));hold on;
    semilogy(SNR,BER_LoRa_Doppler(f,:),'LineStyle','--','Color',c(f,:),'Marker',m(f));hold on;
% semilogy(SNR,BER_MF(f,:),'LineStyle','-');hold on;
% semilogy(SNR,BER_LoRa_Doppler(f,:),'LineStyle','--');hold on;
end
xlabel('SNR(dB)');ylabel('BER');
grid on;
title('MF,LoRa');
% legend('MF,fd=0.5*\Deltaf','MF,fd=0.6*\Deltaf','MF,fd=0.7*\Deltaf','MF,fd=0.8*\Deltaf','MF,fd=0.9*\Deltaf','MF,fd=1.0*\Deltaf');
%xlim([-20 -4])
% title('B=125KHz,SF=7,\Deltaf=B/M=976.5625Hz');
legend('MF,fd=0','LoRa,fd=0','MF,fd=0.1*\Deltaf','LoRa,fd=0.1*\Deltaf','MF,fd=0.2*\Deltaf','LoRa,fd=0.2*\Deltaf','MF,fd=0.3*\Deltaf','LoRa,fd=0.3*\Deltaf','MF,fd=0.4*\Deltaf','LoRa,fd=0.4*\Deltaf','MF,fd=0.5*\Deltaf','LoRa,fd=0.5*\Deltaf');

figure;
c=['k';'m';'c';'b';'g';'r'];
m=['x';'d';'s';'*';'+';'o'];
% c=[0 0 0;
%     0.39216 0.58431 0.92941;
%     0.51765 0.43922 1;
%     0 1 1;
%     1 0.5 0;
%     0.6902 0.18824 0.37647;
%     0.51373 0.43529 1;
%     0.06275 0.30588 0.5451;
%     0.5451 0.4902 0.48235;
%     ];
for f=7:length(fd)
    semilogy(SNR,BER_MF(f,:),'LineStyle','-','Color',c(f-6,:),'Marker',m(f-6));hold on;
    semilogy(SNR,BER_LoRa_Doppler(f,:),'LineStyle','--','Color',c(f-6,:),'Marker',m(f-6));hold on;
% semilogy(SNR,BER_MF(f,:),'LineStyle','-');hold on;
% semilogy(SNR,BER_LoRa_Doppler(f,:),'LineStyle','--');hold on;
end
xlabel('SNR(dB)');ylabel('BER');
grid on;
title('MF,LoRa');
legend('MF,fd=0.6*\Deltaf','LoRa,fd=0.6*\Deltaf','MF,fd=0.7*\Deltaf','LoRa,fd=0.7*\Deltaf','MF,fd=0.8*\Deltaf','LoRa,fd=0.8*\Deltaf','MF,fd=0.9*\Deltaf','LoRa,fd=0.9*\Deltaf','MF,fd=1.0*\Deltaf','LoRa,fd=1.0*\Deltaf');
%% MF算法
function [error,error_LoRa]=MF(M,B,fd,SNR)
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
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=(y_preamble/8);
% y_preamble=y_preamble.^2;
% y_preamble=y_preamble/max(y_preamble);
y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;
% y_payload=y_payload.^2;
% y_payload=y_payload/max(y_payload);
Yq=y_payload;
%圆周相关运算
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble.*y_tem);
end
%解调
[~,decision]=max(R);
if ((decision-1) ~= aa)
    error = 1;
else
    error = 0;
end
%LoRa非相干解调
[~,decision_LoRa]=max(Yq);
if ((decision_LoRa-1) ~= aa)
    error_LoRa = 1;
else
    error_LoRa = 0;
end
end

