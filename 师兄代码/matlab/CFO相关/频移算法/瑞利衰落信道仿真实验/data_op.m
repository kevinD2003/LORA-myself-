%% Doppler-RayleighFading Channel；数据处理
%% PRC
SNR1=[];
BER1=[];
for i=1:5:length(BER_FD_Shift)
    SNR1=[SNR1 SNR(i)];
    BER1=[BER1 BER_FD_Shift(i)];
end
figure;semilogy(SNR1,BER1,'r-o');grid on


%% EC
SNR2=[];
BER2=[];
for i=1:5:length(BER_IOTJ2022)
    SNR2=[SNR2 SNR(i)];
    BER2=[BER2 BER_IOTJ2022(i)];
end
figure;semilogy(SNR2,BER2,'b-+');grid on


%% MF
SNR3=[];
BER3=[];
for i=1:5:length(BER_MF)
    SNR3=[SNR3 SNR(i)];
    BER3=[BER3 BER_MF(i)];
end
figure;semilogy(SNR3,BER3,'m-d');grid on

%% DCSS
SNR4=[];
BER4=[];
for i=1:5:length(BER_DCSS)
    SNR4=[SNR4 SNR(i)];
    BER4=[BER4 BER_DCSS(i)];
end
figure;semilogy(SNR4,BER4,'g-*');grid on