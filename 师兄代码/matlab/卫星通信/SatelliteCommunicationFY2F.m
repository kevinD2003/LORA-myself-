sc = satelliteScenario;
sat = satellite(sc,"eccentricOrbitSatellite.tle");
la = 40.0; lon = 50; al = 100;
gs = groundStation(sc, la, lon, 'Altitude', al, 'Name','My_station');

time_center    = datetime(2020,1,11,14,50,0) + days(2/24+50/24/60);
StartTime      = time_center  - minutes(20);
StopTime       = time_center  + minutes(20);
sc.StartTime  = StartTime;
sc.StopTime   = StopTime;
sc.SampleTime = 60;

ac = access(sat, gs);
play(sat)

[po,vel] = states(sat,'Coordinateframe','ecef');

t  = seconds(-1200 : 60 : 1200) + time_center  ;
for i = 1 : 2400/60 + 1
    [az,el(i),r1(i)] = aer(gs(1),sc(1), t(i));
end

tx = transmitter(gs(1), 'frequency', 1e9, 'Power', 30, 'SystemLoss', 3, 'Bitrate', 1);
rx1 = receiver(sc(1),  'SystemLoss', 0, 'GainToNoiseTemperatureRatio', -22);

gaussianAntenna(tx,'DishDiameter',0.2);
gaussianAntenna(rx1,'DishDiameter',0.2);

l1 = link (tx,rx1);

for i = 1 : 2400/60 + 1
    enba(i) = ebno(l1,t(i));
end

