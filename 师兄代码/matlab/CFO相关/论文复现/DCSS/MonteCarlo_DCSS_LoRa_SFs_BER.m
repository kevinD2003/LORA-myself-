%% 多普勒频偏采用差分编码,多次。卫星通信那篇差分编码复现。
B=125e3;fd=0*B/M;%不受到多普勒频偏
SF=7:12;
SNR=[-13:-5;
    -16:-8;
    -19:-11;
    -22:-14;
    -25:-17;
    -28:-20];
BER_DCSS=zeros(length(SF),length(SNR));
BER_LoRa=zeros(length(SF),length(SNR));
times=1000000;
tic;
h=waitbar(0,'计算中');
for j=1:length(SF)
    M=2^SF(j);
    %% 差分编码
    for jj=1:length(SNR)
        error_dcss=0;
        for jjj=1:times
            error_dcss=error_dcss+DCSS(M,SNR(j,jj),fd,B);
        end
        BER_DCSS(j,jj)=error_dcss/times/2;
    end
    %% LoRa非相干解调
    for jj=1:length(SNR)
        error_lora=0;
        for jjj=1:times
            error_lora=error_lora+LoRa(M,SNR(j,jj),fd,B);
        end
        BER_LoRa(j,jj)=error_lora/times/2;
    end
    waitbar(j/length(SNR));
end
toc;
close(h);
%%
marker=['x';
    'd';
    's';
    '*';
    '+';
    'o';];
c=[0 0 0;
    0 0 1;
    1 0 0;
    1 0.5 0;
    1 0 1;
    0.41961 0.55686 0.13725;];
figure;
for i=1:length(SF)
    semilogy(SNR(i,:),BER_LoRa(i,:),'LineStyle','-','Marker',marker(i,:),'Color',c(i,:));hold on;
    semilogy(SNR(i,:),BER_DCSS(i,:),'LineStyle','--','Marker',marker(i,:),'Color',c(i,:));hold on;
end
grid on;
xlim([-26 -6]);ylim([10^-5 0.5]);
%% DCSS
function error_dcss=DCSS(M,SNR,fd,B)
N_symbol=2;
error_dcss=0;
Sp=randi([0 M-1],1,N_symbol);
Dp=zeros(1,length(Sp));
Dp(1)=Sp(1);
for i=2:N_symbol
    Dp(i)=mod((Sp(i)+Sp(i-1)),M);
end
k=0:1:M-1;
Sk=zeros(1,N_symbol*M);
for ii=1:N_symbol
    Sk((ii-1)*M+1:ii*M)=exp(1j*2*pi*k.*(Dp(ii)/M-1/2+k/2/M+fd/B));%调制
end
Rk=awgn(Sk,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
Dp_ncoh=zeros(1,N_symbol);
for iii=1:N_symbol
    Yq=abs(fft(Rk((iii-1)*M+1:iii*M).*xk0)/M);
    [~,decision]=max(Yq);
    Dp_ncoh(iii)=decision-1;
end
Sp_ncoh=zeros(1,N_symbol);

for iiii=2:N_symbol
    Sp_ncoh(iiii)=mod(Dp_ncoh(iiii)-Dp_ncoh(iiii-1),M);
    if Sp_ncoh(iiii)~=Sp(iiii)
        error_dcss=1;
    end
end
end
%% LoRa
function [aaerror]=LoRa(M,SNR,fd,B)
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
