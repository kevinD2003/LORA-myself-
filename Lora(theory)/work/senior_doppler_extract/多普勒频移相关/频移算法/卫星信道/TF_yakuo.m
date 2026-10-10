startTime = datetime(2024,5,5,8,12,24);%年/月/日/时/分/秒
stopTime = startTime + hours(0.032768/3600);%hours(0.5);%days(1);
sampleTime = 0.000256;%s
sc = satelliteScenario(startTime,stopTime,sampleTime);

% sat = satellite(sc,"eccentricOrbitSatellite.tle");%tle是两行根数文件
sat = satellite(sc,"TianQi.tle");%tle是两行根数文件
show(sat)
groundTrack(sat,"LeadTime",1200);
ele1 = orbitalElements(sat(1));%tle文件的第一个卫星
% ele2 = orbitalElements(sat(2));
% ele3 = orbitalElements(sat(3));

time = datetime(2024,5,5,8,12,24);%datetime(2024,5,5,8,0,0);
pos = states(sat(1),time,"CoordinateFrame","geographic");
%% 地面基站
name = ["华南理工大学逸夫科学馆"];
lat = 23.152405;
lon = [113.347733];
gs = groundStation(sc,"Name",name,"Latitude",lat, ...
    "Longitude", lon);

%% 计算传播时延
% [delay,time] = latency(sat,gs);
% figure;
% plot(time,delay(1,:)*1000) 
% % plot(time,delay(3,:)*1000)                  % Plot in milliseconds
% xlim([time(1) time(end)])
% title("TianQi 28's Latency vs. Time")
% xlabel("Simulation Time UTC")
% ylabel("Latency (ms)")
% grid on

% latencyRate = diff(delay,1,2)/sampleTime;
% figure;
% plot(time(1:end-1),latencyRate(1,:)*1e6)          % Plot in microseconds/second
% xlim([time(1) time(end-1)])
% title("TianQi 28's Latency Rate vs. Time")
% xlabel("Simulation Time")
% ylabel("Latency Rate (\mus/s)")
% grid on

%% 计算多普勒
% Emitted carrier frequency in Hz
fc = 868e6;% downlink
% fc = 401.5e3;% uplink
% Calculate Doppler shift and get additional information about Doppler. The
% Doppler information output contains relative velocity and Doppler rate.
% The dopplershift function internally performs access analysis and returns
% NaN whenever there is no access.

[fShift,time,dopplerInfo] = dopplershift(sat,gs,Frequency=fc);
% [fShift,time,dopplerInfo] = dopplershift(sat,gsDCP,Frequency=fc);

figure;
subplot(2,1,1);
plot(time,fShift(1,:)/1e3) 
% plot(time,fShift(3,:)/1e3)                        % Plot in kHz
xlim([time(1) time(end)])
title("TianQi 28's Doppler Shift vs. Time")
xlabel("Simulation Time UTC")
ylabel("Doppler Shift (kHz)")
grid on

% figure;
subplot(2,1,2)
plot(time(1:end-1),dopplerInfo.DopplerRate(1,:))  % Plot in Hz/s
xlim([time(1) time(end-1)])
title("TianQi 28's Doppler Rate vs. Time")
xlabel("Simulation Time")
ylabel("Doppler Rate (Hz/s)")
grid on


%% 可视化
time = datetime(2024,5,5,8,12,24);%datetime(2024,5,5,8,0,0);
[az,elev,r] = aer(gs(1),sat(1),time);
% [az,elev,r] = aer(gs(3),sat(3),time);
% [az,elev,r] = aer(gsDCP(1),sat(3),time);
play(sc);