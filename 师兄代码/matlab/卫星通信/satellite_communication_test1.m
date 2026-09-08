startTime = datetime(2020,1,11,14,50,0);
stopTime = startTime + days(3);
sampleTime = 60;                         % In seconds
sc = satelliteScenario( ...
    startTime,stopTime,sampleTime);
sat = satellite(sc,"gpsAlmanac.txt");
orbitProp = sat(1).OrbitPropagator;
elements = orbitalElements(sat(1));
name = "Madrid Deep Space Communications Complex";
lat =40.43139;                                    % In degrees
lon =-4.24806;                                    % In degrees
gs = groundStation(sc, ...
    Name=name,Latitude=lat,Longitude=lon);
ac = access(sat,gs);
v = satelliteScenarioViewer(sc,ShowDetails=false);
campos(v, ...
    29, ...                                        % Latitude in degrees
    -19, ...                                       % Longitude in degrees
    7.3e7);                                        % Altitude in meters
% Calculate propagation delay from each satellite to the ground station.
% The latency function internally performs access analysis and returns NaN
% whenever there is no access.
[delay,time] = latency(sat,gs);
figure;
plot(time,delay(1,:)*1000)                  % Plot in milliseconds
xlim([time(1) time(end)])
title("First Satellite's Latency vs. Time")
xlabel("Simulation Time")
ylabel("Latency (ms)")
grid on

latencyRate = diff(delay,1,2)/sampleTime;
figure;
plot(time(1:end-1),latencyRate(1,:)*1e6)          % Plot in microseconds/second
xlim([time(1) time(end-1)])
title("First Satellite's Latency Rate vs. Time")
xlabel("Simulation Time")
ylabel("Latency Rate (\mus/s)")
grid on


% Emitted carrier frequency in Hz
fc = 5e9;
% Calculate Doppler shift and get additional information about Doppler. The
% Doppler information output contains relative velocity and Doppler rate.
% The dopplershift function internally performs access analysis and returns
% NaN whenever there is no access.
[fShift,time,dopplerInfo] = dopplershift(sat,gs,Frequency=fc);
figure;
plot(time,fShift(1,:)/1e3)                        % Plot in kHz
xlim([time(1) time(end)])
title("First Satellite's Doppler Shift vs. Time")
xlabel("Simulation Time")
ylabel("Doppler Shift (kHz)")
grid on

figure;
plot(time(1:end-1),dopplerInfo.DopplerRate(1,:))  % Plot in Hz/s
xlim([time(1) time(end-1)])
title("First Satellite's Doppler Rate vs. Time")
xlabel("Simulation Time")
ylabel("Doppler Rate (Hz/s)")
grid on

sat(1).ShowLabel = true;
show(sat(1).Orbit);
groundTrack(sat(1), ...
    LeadTime=12*3600);   % In seconds
campos(v,84,-176,7.3e7);

play(sc)