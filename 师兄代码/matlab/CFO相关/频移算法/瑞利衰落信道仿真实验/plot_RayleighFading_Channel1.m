
figure;
load("BER_RayleighFading_EC_8upchirp.mat");
semilogy(SNR,BER_LoRa,'LineStyle','-','LineWidth',1,'Marker','v','Color','k');hold on;

load("BER_Rayleighfading_MF.mat");
semilogy(SNR,BER_MF,'LineStyle','-','LineWidth',1,'Marker','square','Color','m');hold on;

load("BER_RayleighFading_DCSS.mat");
semilogy(SNR,BER_DCSS,'LineStyle','-','LineWidth',1,'Marker','*','Color','g');hold on;

load("BER_rayleighFading_new_algorithm_8upchirps.mat");
semilogy(SNR,BER_FD_Shift,'LineStyle','-','LineWidth',1,'Marker','o','Color','r');hold on;

semilogy(SNR,BER_IOTJ2022,'LineStyle','-','LineWidth',1,'Marker','x','Color','b');hold on;

% load("BER_rayleighFading_new_algorithm_8upchirps.mat");
% semilogy(SNR,BER_FD_Shift,'LineStyle','-','LineWidth',1,'Marker','o','Color','r');hold on;

load("BER_RayleighFading_new_algorithm.mat");
semilogy(SNR,BER_FD_Shift,'LineStyle','-.','LineWidth',1,'Marker','pentagram','Color','r');hold on;

load("BER_RayleighFading_EC_BER_IOTJ2022.mat");
semilogy(SNR,BER_IOTJ2022,'LineStyle','-.','LineWidth',1,'Marker','+','Color','b');hold on;

load("BER_LoRa_RayleighChannel_Approximation.mat");
semilogy(SNR,Pb,'LineStyle','-.','LineWidth',1,'Color',[0.5 0.5 0.5]);hold on;

grid on;
ylim([10^-5 1]);
legend('LoRa',...
    'MF',...
    'DCSS',...
    'New Algorithm,8upchirps',...
    'EC,8upchirps',...
    'New Algorithm,2upchirps',...
    'EC,2upchirps',...
    'LoRa,Rayleigh Channel,Approx');
