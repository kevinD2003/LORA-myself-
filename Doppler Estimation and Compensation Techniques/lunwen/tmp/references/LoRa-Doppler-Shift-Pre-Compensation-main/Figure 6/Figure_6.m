% Author: Muhammad Asad Ullah
% Email: Asad.Ullah@vtt.fi
clear all
close all
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fc: 400.45 MHz carrier frequency in downlink 
% fc_prime: 401.45 MHz nominal carrier frequency in uplink     
% fd: Theoratical Doppler shift in downlink
% fd_prime: Theoratical Doppler shift in uplink
% timestamps: Timestamps when real-world LoRa packet was received by TinyGS
% FP: Predicted Doppler shift values from TinyGS
% FE: Frequency Error (estimated Doppler shift) values from TinyGS 
% t: theoratical time instant
% fe: extrapolated Frequency Error (estimated Doppler shift) in downlink
% fe_prime: extrapolated Frequency Error (estimated Doppler shift) in uplink

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% TinyGS real-world data
% Time stamps when LoRa packet was received by TinyGS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fc_downlink = 400.45e6;    %% Downlink carrier frequency
fc_prime = 401.45e6;      %% Uplink carrier frequency
BW = 31.25e3;              %% Uplink bandwidth
h_518 = 518e3;             %% orbital height 518 km
h_200 = 200e3;             %% orbital height 200 km
F_static = (25/100)*BW;    %% LoRa Doppler shift tolerance 
% t                        %% t is the time of visibility window

%% FP_400MHz (this data is from TinyGS)
%% PE_400MHz (this data is from TinyGS)
%% timestamps (this data is from TinyGS)

%% Timestamp (this data is from TinyGS)
timestamps= datetime({'Jun 11, 2024 02:23:59', 'Jun 11, 2024 02:23:29', ...
                         'Jun 11, 2024 02:23:14', 'Jun 11, 2024 02:22:44', ...
                         'Jun 11, 2024 02:22:29', 'Jun 11, 2024 02:22:14', ...
                         'Jun 11, 2024 02:21:59', 'Jun 11, 2024 02:21:44', ...
                         'Jun 11, 2024 02:21:14', 'Jun 11, 2024 02:20:59', ...
                         'Jun 11, 2024 02:20:44', 'Jun 11, 2024 02:20:29', ...
                         'Jun 11, 2024 02:20:14', 'Jun 11, 2024 02:19:59' ...
                         'Jun 11, 2024 02:19:44', 'Jun 11, 2024 02:19:29', ...
                         'Jun 11, 2024 02:19:14', 'Jun 11, 2024 02:18:59', ...
                         'Jun 11, 2024 02:18:44', 'Jun 11, 2024 02:18:29', ...
                         'Jun 11, 2024 02:18:14', 'Jun 11, 2024 02:17:59'});

%% Predicted Doppler values (this data is from TinyGS)
FP_400MHz = [-9171.80, -9043.21, -8956.43, -8718.06, ...
                       -8554.57, -8350.22, -8092.89, -7766.38, ...
                       -6813.99, -6126.95, -5251.64, -4157.45, ...
                       -2836.52, -1324.63,288.65, 1878.65, 3329.12, 4569.41, ...
                       5581.61, 6384.19, 7011.43, 7499.47];

%% Frequency Error values (this data is from TinyGS)
PE_400MHz = [8380.22, 8262.78, 8128.56, 7843.35, ...
                     7675.58, 7474.25, 7189.04, 6803.16, ...
                     5729.42, 5008.00, 4018.14, 2810.18, ...
                     1384.12, -276.82,-2088.76, -3800.04, -5393.88, -6736.05, ...
                     -7860.13, -8732.54, -9386.85, -9906.95];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Theoratical Doppler shift calculation and exrapolation: Downlink
[fd_518 t SlantRange el] = DopplerModelFunction (fc_downlink,h_518);   %% fd is theoratical in downlink 
Fe_518 = interp1(FP_400MHz, PE_400MHz, fd_518, 'linear', 'extrap');    %% fe is extrapolation of FP_400MHz and PE_400MHz: in downlink 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Theoratical Doppler shift calculation and exrapolation: Uplink
[fd_uplink_518 t_prime_518 SlantRange el_518] = DopplerModelFunction (fc_prime,h_518);    %% Uplink
% Extrapolation

% It is important to note that fd_prime in equation (11) is theoretical 
% and does not account for errors caused by transmitter and receiver oscillators deviations, 
% nor does it fully reflect empirical behavior. To better approximate the empirical behavior, 
% we extrapolate fd_prime using TinyGS's data on predicted Doppler shift FP and estimated Doppler shift FE.
% Let fe_prime be the  linear extrapolation of fd_prime. 
% Given this, the satellite receives the uplink signal at

fe_uplink_518 = interp1(FP_400MHz, PE_400MHz, fd_uplink_518, 'linear', 'extrap');          %% Uplink

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Doppler shift pre compensation
f_prime_518=(fc_prime+Fe_518*(fc_prime/fc_downlink));                                       % f_prime in Equation (10): pre-compensation
[fd_prime_518 t_prime_518 SlantRange el_518] = DopplerModelFunction (f_prime_518,h_518);    % fd_prime in Equation (11)
Fe_prime_518 = interp1(FP_400MHz, PE_400MHz, fd_prime_518, 'linear', 'extrap');

fr_prime_518 = f_prime_518 - (Fe_prime_518);                                                % Equation (12)
% At a given time t, the actual Doppler shift experienced by a 
% satellite is calculated as the difference between the nominal 
% uplink carrier frequency fc_prime and the received frequency fr_prime
% representing the frequency at which the uplink signal arrives at the satellite
F_Doppler_actual_518 = fr_prime_518 - fc_prime;


%% Let's do same for h = 200 km

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Theoratical Doppler shift calculation and exrapolation: Downlink
[fd_200 t_prime_200 SlantRange el_200] = DopplerModelFunction (fc_prime,h_200);   %Downlink
Fe_200 = interp1(FP_400MHz, PE_400MHz, fd_200, 'linear', 'extrap');         %Downlink

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Doppler shift pre compensation
f_prime_200=(fc_prime+Fe_200*(fc_prime/fc_downlink));

[fd_prime_200 t_prime_200 SlantRange el_200] = DopplerModelFunction (f_prime_200,h_200);   % fd_prime in Equation (11)
Fe_prime_200 = interp1(FP_400MHz, PE_400MHz, fd_prime_200, 'linear', 'extrap');

fr_prime_200 = f_prime_200 - (Fe_prime_200);                                               % Equation (12)
F_Doppler_actual_200 = fr_prime_200 -fc_prime;


Loss_static_518 = zeros(length(fd_uplink_518),1);
Loss_static_Compensated_518 = zeros(length(fd_uplink_518),1);
for Doppler_loop=1:1:length(el_518)
    if abs(fe_uplink_518(Doppler_loop))>=F_static
        Loss_static_518(Doppler_loop) = 1;
    else
        Loss_static_518(Doppler_loop) = 0;
    end
end

for Doppler_loop=1:1:length(el_518)
    if abs(F_Doppler_actual_518(Doppler_loop))>=F_static
        Loss_static_Compensated_518(Doppler_loop) = 1;
    else 
        Loss_static_Compensated_518(Doppler_loop) = 0;
    end
end


Loss_static_200 = zeros(length(fd_200), 1);
Loss_static_Compensated_200 = zeros(length(fd_200), 1);

for Doppler_loop = 1:1:length(el_200)
    if abs(Fe_200(Doppler_loop)) >= F_static
        Loss_static_200(Doppler_loop) = 1;
    else
        Loss_static_200(Doppler_loop) = 0;
    end
end

for Doppler_loop = 1:1:length(el_200)
    if abs(F_Doppler_actual_200(Doppler_loop)) >= F_static
        Loss_static_Compensated_200(Doppler_loop) = 1;
    else 
        Loss_static_Compensated_200(Doppler_loop) = 0;
    end
end


close all
f1=figure(1); % new numbered figure 
set(gcf, 'Units', 'centimeters'); % set units 
%set(gcf,'TickLabelInterpreter', 'latex')
LineWidth = 2;
axesFontSize = 18;
legendFontSize = 14;
% setting size & position
afFigurePosition = [2 7 19 11]; % [pos_x pos_y width_x width_y] 
set(gcf, 'Position', afFigurePosition,'PaperSize',[19 11],'PaperPositionMode','auto'); % [left bottom width height], setting printing properties 
% plotting
subplot(221)

scatter(t_prime_518,el_518,'blue','filled');
hold on
scatter(t_prime_518(find(Loss_static_518)),el_518(find(Loss_static_518)),'red','filled');
ylabel('Elevation Angle [$^{\circ}$]','Color','k','Interpreter','Latex','FontSize', axesFontSize)
title('(a) Legacy','Interpreter','Latex','FontSize', axesFontSize)
grid on
axis tight
subplot(222)
scatter(t_prime_518,el_518,'blue','filled');
hold on
scatter(t_prime_518(find(Loss_static_Compensated_518)),el_518(find(Loss_static_Compensated_518)),'red','filled');

title('(b) Proposed','Interpreter','Latex','FontSize', axesFontSize)
grid on
 axis tight
subplot(223)

scatter(t_prime_200,el_200,'blue','filled');
hold on
scatter(t_prime_200(find(Loss_static_200)),el_200(find(Loss_static_200)),'red','filled');
ylabel('Elevation Angle [$^{\circ}$]','Color','k','Interpreter','Latex','FontSize', axesFontSize)
%title('(a) Legacy','Interpreter','Latex','FontSize', axesFontSize)
grid on
legend('successful','failed','Location','southeast','NumColumns',2, 'Interpreter', 'Latex','FontSize',12)
 xlabel('Time, $t$ [s]','Interpreter','latex','FontSize', axesFontSize)
  axis tight
subplot(224)
scatter(t_prime_200,el_200,'blue','filled');
hold on
scatter(t_prime_200(find(Loss_static_Compensated_200)),el_200(find(Loss_static_Compensated_200)),'red','filled');
xlabel('Time, $t$ [s]','Interpreter','latex','FontSize', axesFontSize)
grid on
axis tight