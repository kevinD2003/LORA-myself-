%% Robust LoRa Modulation Scheme in the Presence of Residual Carrier Frequency Offset
SF=12;
SNR=-25:-5;
times=10000;
f_CFO=0.6/2^10;
BER_LoRa=zeros(1,length(SNR));
BER_R=zeros(1,length(SNR));
%% LoRa
tic
h=waitbar(0,'LoRa modulation,waiting.....');
for i=1:length(SNR)
    error_LoRa=0;
    for ii=1:times
        error_LoRa=error_LoRa+N_LoRa(SF,f_CFO,SNR(i));
    end
    BER_LoRa(i)=2*error_LoRa/2/times;
    waitbar(i/length(SNR),h,['LoRa modulation,SNR=',num2str(SNR(i))]);
end
close(h);
% propose 
h=waitbar(0,'Robust LoRa modulation,waiting.....');
for i=1:length(SNR)
    error_r=0;
    for ii=1:times
        error_r=error_r+N_R(SF,f_CFO,SNR(i));
    end
    BER_R(i)=2*error_r/2/times;
    waitbar(i/length(SNR),h,['Robust LoRa modulation,SNR=',num2str(SNR(i))]);
end
close(h);
toc;
%% 画图
% figure;
semilogy(SNR,BER_LoRa,'b-x');hold on;
semilogy(SNR,BER_R,'r-o');hold on;
xlim([-25 -5]);ylim([10^-3 1]);
grid on

%% LoRa
function error=N_LoRa(SF,f_CFO,SNR)
ac=randi([0 2^SF-1]);
n=0:1:2^SF-1;
xk=exp(1j*2*pi*f_CFO*n).*exp(1j*2*pi*n.*(ac/2^SF-1/2+n/2/2^SF));
xk0=exp(-1j*2*pi*n.*(-1/2+n/2/2^SF));
rk=awgn(xk,SNR,'measured');
Yq=abs(fft(rk.*xk0));
[~,decision]=max(Yq);
if (decision-1)==ac
    error=0;
else
    error=1;
end
end

%% propose
function error=N_R(SF,f_CFO,SNR)
m=ceil(-1-log2(abs(f_CFO)))-1;
if m<SF
    M=m;
else
    M=SF;
end
% Ap=randi([0 1],1,M);
% ap=0;
% for i=M:-1:1
%     ap=ap+Ap(i)*2^(M-i)*2^(SF-M);
% end
% ap=ap*2^(SF-M);
% n=0:1:2^SF-1;
% xk=exp(1j*2*pi*f_CFO*n).*exp(1j*2*pi*n.*(ap/2^SF-1/2+n/2/2^SF));
% xk0=exp(-1j*2*pi*n.*(-1/2+n/2/2^SF));
ap=randi([0,2^M-1]);
n=0:1:2^M-1;
xk=exp(1j*2*pi*f_CFO*n).*exp(1j*2*pi*n.*(ap/2^M-1/2+n/2/2^M));
xk0=exp(-1j*2*pi*n.*(-1/2+n/2/2^M));
tk=[xk zeros(1,2^SF-2^M)];
% rk=awgn(xk,SNR,'measured');
rk=awgn(tk,SNR,'measured');
% rk=awgn(tk,SNR);
Yq=abs(fft(rk(1:2^M).*xk0));
[~,decision]=max(Yq);
if ((decision-1))==ap
    error=0;
else
    error=1;
end
% Yq1=zeros(1,2^M);
% for i=1:2^M
%     Yq1(i)=Yq((i-1)*2^(SF-M)+1);
% end
% [~,decision]=max(Yq1);
% [~,decision]=max(Yq);
% if ((decision-1)*2^(SF-M))==ap
%     error=0;
% else
%     error=1;
% end


end
