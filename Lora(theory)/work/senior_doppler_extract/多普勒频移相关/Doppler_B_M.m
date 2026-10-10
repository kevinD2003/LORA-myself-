%带频偏的LoRa计算误码率；
%计算不同多普勒频移的误码率
B=125e3;
SF=10;
M=2^SF;
SNR=-30:1:0;
times=1000;
%  f=rand(1,1);
%  f=f*B/(2*M)
%  f/B
f=B/M;
d=1:10;
fd=B/M*0.1*d;%多普勒频偏Hz
BER_Doppler=zeros(length(fd),length(SNR));
BER_MF=zeros(length(fd),length(SNR));
BER_LoRa=zeros(1,length(SNR));

%LoRa调制解调
for i=1:1:length(SNR)
        errorl=0;
        for j=1:1:times
            errorl=errorl+LoRa(M,SNR(i));
        end
        BER_LoRa(i)=errorl/times/2;
end

%受到多普勒频偏的LoRa调制解调
tic;
h=waitbar(0,'计算受到多普勒频偏的LoRa');
for o=1:length(fd)
    for i=1:1:length(SNR)
        errord=0;
        for j=1:1:times
            errord=errord+Nerror(M,B,fd(o),SNR(i));
        end
        BER_Doppler(o,i)=errord/times/2;
    end
    waitbar(o/length(fd));
end
toc;
close(h);

% %匹配滤波法
% tic;
% h=waitbar(0,'MF计算多普勒频偏的误码率');
% for o=1:length(fd)
%     for i=1:1:length(SNR)
%         errormf=0;
%         for j=1:1:times
%             errormf=errormf+MF(M,B,fd(o),SNR(i));
%         end
%         BER_MF(o,i)=errormf/times/2;
%     end
%     waitbar(o/length(fd));
% end
% toc;
% close(h);


%%
figure;
c=[1 0 0;
    0 1 0;
    1 0.5 0;
    1 0 1;
    0 1 1;
    1 1 0;
    0.5 0 0;
    0.5 0.5 0.5;
    0 0 1;
    0.67 0 1];
semilogy(SNR,BER_LoRa,'b-o');hold on;
for o=1:length(fd)
    semilogy(SNR,BER_Doppler(o,:),'-*','Color',c(o,:));hold on;
end
xlabel('SNR(dB)');ylabel('BER');title('B=125KHz, SF=10, \Deltaf=B/M=122.0703Hz')
grid on;
%%
% legend('LoRa,f_d=1200','LoRa,f_d=0 ','MF,f_d=1200Hz');
%xlim([-20 -4])
legend('f_d=0','f_d=0.1×\Deltaf','f_d=0.2×\Deltaf','f_d=0.3×\Deltaf','f_d=0.4×\Deltaf','f_d=0.5×\Deltaf','f_d=0.6×\Deltaf','f_d=0.7×\Deltaf','f_d=0.8×\Deltaf','f_d=0.9×\Deltaf','f_d=1.0×\Deltaf')
%% 受到多普勒频偏影响的LoRa调制解调。
function [aaerror]=Nerror(M,B,fd,SNR)
aa=randi([0 M-1]);
k=0:1:M-1;  
xk_Doppler=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));%受到多普勒频偏影响的LoRa信号
rk1=awgn(xk_Doppler,SNR,'measured');
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
%% LoRa调制解调；
function [error]=LoRa(M,SNR)
aa=randi([0 M-1]);
k=0:1:M-1;  
xk_LoRa=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));%不受多普勒频移
rk2=awgn(xk_LoRa,SNR,'measured');
%解调,传统
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
YqL=fft(rk2.*xk0)/M;
YqL=abs(YqL);%非相干解调
[~,decisionL]=max(YqL);
if ((decisionL-1) ~= aa)
    error = 1;
else
    error = 0;
end
end

%% MF算法
function error=MF(M,B,fd,SNR)
aa=randi([0 M-1]);
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk];
rk1=awgn(Sd,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:1
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
% y_preamble=y_preamble/1;
y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;
%圆周相关运算
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble_tem.*y_tem);
end
%解调,传统
[~,decision]=max(R);
if ((decision-1) ~= aa)
    error = 1;
else
    error = 0;
end
end
