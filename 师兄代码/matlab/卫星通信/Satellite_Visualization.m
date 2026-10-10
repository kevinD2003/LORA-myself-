startTime = datetime(2024,5,5,15-8,0,0);
stopTime = startTime + days(1);
sampleTime = 20;
sc = satelliteScenario(startTime,stopTime,sampleTime);

% sat = satellite(sc,"eccentricOrbitSatellite.tle");%tle是两行根数文件
sat = satellite(sc,"sat.tle");%tle是两行根数文件
show(sat)
groundTrack(sat,"LeadTime",1200);
ele1 = orbitalElements(sat(1));%tle文件的第一个卫星
% ele2 = orbitalElements(sat(2));
% ele3 = orbitalElements(sat(3));

time = datetime(2024,5,5,15-8,0,0);
pos = states(sat(1),time,"CoordinateFrame","geographic");
%% 地面基站
name = ["天麓湖站区"];
lat = [23.230095];
lon = [113.423508];
gs = groundStation(sc,"Name",name,"Latitude",lat, ...
    "Longitude", lon);
% % %% DCP 数据采集平台
% nameDCP = ["DCP终端"];
% latDCP = [23.173239];
% lonDCP = [113.432504];
% gsDCP = groundStation(sc,"Name",nameDCP,"Latitude",latDCP, ...
%     "Longitude", lonDCP);
%% 计算传播时延
[delay,time] = latency(sat,gs);
figure;
plot(time,delay(1,:)*1000) 
% plot(time,delay(3,:)*1000)                  % Plot in milliseconds
xlim([time(1) time(end)])
title("FENGYUN 2F's Latency vs. Time")
xlabel("Simulation Time UTC")
ylabel("Latency (ms)")
grid on

% latencyRate = diff(delay,1,2)/sampleTime;
% figure;
% plot(time(1:end-1),latencyRate(1,:)*1e6)          % Plot in microseconds/second
% xlim([time(1) time(end-1)])
% title("FENGYUN 2F's Latency Rate vs. Time")
% xlabel("Simulation Time")
% ylabel("Latency Rate (\mus/s)")
% grid on

%% 计算多普勒
% Emitted carrier frequency in Hz
fc = 1.6875e9;% downlink
% fc = 401.5e3;% uplink
% Calculate Doppler shift and get additional information about Doppler. The
% Doppler information output contains relative velocity and Doppler rate.
% The dopplershift function internally performs access analysis and returns
% NaN whenever there is no access.

[fShift,time,dopplerInfo] = dopplershift(sat,gs,Frequency=fc);
% [fShift,time,dopplerInfo] = dopplershift(sat,gsDCP,Frequency=fc);

figure;
plot(time,fShift(1,:)/1e3) 
% plot(time,fShift(3,:)/1e3)                        % Plot in kHz
xlim([time(1) time(end)])
title("FENGYUN 2F's Doppler Shift vs. Time")
xlabel("Simulation Time UTC")
ylabel("Doppler Shift (kHz)")
grid on

% figure;
% plot(time(1:end-1),dopplerInfo.DopplerRate(1,:))  % Plot in Hz/s
% xlim([time(1) time(end-1)])
% title("FENGYUN 2F's Doppler Rate vs. Time")
% xlabel("Simulation Time")
% ylabel("Doppler Rate (Hz/s)")
grid on


%% 可视化
time = datetime(2024,5,5,15-8,0,0);
[az,elev,r] = aer(gs(1),sat(1),time);
% [az,elev,r] = aer(gs(3),sat(3),time);
% [az,elev,r] = aer(gsDCP(1),sat(3),time);
play(sc);