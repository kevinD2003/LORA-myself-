%% 计算有效传输速率 Effective Data Transmission Rate
% load('10time_SF_12_8_upchirps_LoRa_MF_DCSS_EC_NA_TQ28_BER.mat')
N_frame=33;
B=125e3;
% LoRa_EDTR=zeros(1,length(SNR));
% DCSS_EDTR=zeros(1,length(SNR));
% MF_EDTR=zeros(1,length(SNR));
% EC_EDTR=zeros(1,length(SNR));
% FD_Shift_EDTR=zeros(1,length(SNR));
%% 计算有效传输速率
LoRa_EDTR=(1-2*BER_LoRa)*SF*(883*N_frame*(30-N_upchirp))/(883*N_frame*30*2^SF/B);
DCSS_EDTR=(1-2*BER_DCSS)*SF*(883*N_frame*(30-N_upchirp-1))/(883*N_frame*30*2^SF/B);
MF_EDTR=(1-2*BER_MF)*SF*(883*N_frame*(30-N_upchirp))/(883*N_frame*30*2^SF/B);
EC_EDTR=(1-2*BER_EC)*SF*(883*N_frame*(30-N_upchirp))/(883*N_frame*30*2^SF/B);
FD_Shift_EDTR=(1-2*BER_FD_Shift)*SF*(883*N_frame*(30-N_upchirp))/(883*N_frame*30*2^SF/B);

%%
figure;
plot(SNR,LoRa_EDTR,'Color','k','LineStyle','-','Marker','.');hold on;
plot(SNR,DCSS_EDTR,'Color','g','LineStyle','-.','Marker','*');hold on;
plot(SNR,MF_EDTR,'Color','m','LineStyle','-.','Marker','square');hold on;
plot(SNR,EC_EDTR,'Color',[0.07,0.62,1.00],'LineStyle','-.','Marker','+');hold on;
plot(SNR,FD_Shift_EDTR,'Color','r','LineStyle','-.','Marker','o');hold on;
legend('LoRa','DCSS','MF','EC','NA');
ylabel('Effective Data Transmission Rate (bit/s)');xlabel('SNR (dB)');
title(['TQ28 Satellite Channel, SF = ' num2str(SF) ', B = 125kHz']);
grid on


%% 柱状图
EDTR_=zeros(length(SNR),5);
for i=1:length(SNR)
    EDTR_(i,:)=[LoRa_EDTR(i) DCSS_EDTR(i) MF_EDTR(i) EC_EDTR(i) FD_Shift_EDTR(i)];

end
figure;
bar(SNR,EDTR_,'BarWidth',1);
ylabel('Effective Data Transmission Rate (bit/s)');xlabel('SNR (dB)');
title('TQ28 Satellite Channel, SF = 12, B = 125kHz');
xlim([-25.5 -9.5])
legend('LoRa','DCSS','MF','EC','NA');
