%% 雨衰落建模
R=[randi([25 50],1,4) 0 randi([0 10],1,3)];%2024年5月5日15：00-2024年5月6日14：59降雨率
% R=0.7;
% R=[randi([50 100],1,2) randi([25 50],1,10) zeros(1,3) randi([0 10],1,9)];
% R = 10; % 降雨率，单位mm/h
attenuation=zeros(1,length(R));
f = 1.7; % 信号频率，单位GHz
pol = 'H'; % 极化方式，'H'表示水平极化
theta = 15; % 路径仰角，单位度
for i=1:length(R)
    d=2500;%m距离
    attenuation(i) = rain_attenuation_model(R(i), f, pol, theta,d);
    disp(['雨衰落: ', num2str(attenuation(i)), ' dB']);
end
function rain_attenuation = rain_attenuation_model(R, f, pol, theta,d)
    % R: 降雨率 (mm/h)
    % f: 信号频率 (GHz)
    % pol: 极化方式 ('H' 表示水平，'V' 表示垂直)
    % theta: 路径仰角 (度)
    % 根据ITU-R P.838-3中的表格查找k和alpha的值
    % 查表：https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.838-3-200503-I!!PDF-C.pdf
    
    if(f==1.7)    
        k = 0.00006; % 查表
        alpha = 1.0185; % 查表
    else
        k = 2e-5;%f=400M
        alpha = 0.95;
    end
    % 计算雨衰落
    rain_attenuation = k * (R^alpha)*d;
    % 这里简化处理，实际中需要根据ITU-R P.838-3的建议进行更复杂的计算
end
