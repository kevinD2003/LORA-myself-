clear;clc;
startTime = datetime(2023,8,11,00,05,34);                %起始时间
stopTime = startTime + seconds(5*3600);                    %结束时间
sampleTime = 300;                                      %抽样时间（场景分辨率）单位：秒
sc = satelliteScenario(startTime,stopTime,sampleTime); %建立场景
% LEO_sat = satellite(sc,'starlink_leo.tle');
v = satelliteScenarioViewer(sc,"ShowDetails",false);