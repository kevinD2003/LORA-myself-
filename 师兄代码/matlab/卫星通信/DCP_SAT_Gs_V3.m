%% DCP->FY->GS
% 上行链路401.1MHz，下行链路1.6875GHz
%QPSK门特卡罗实验计算BER
load('delay_doppler.mat');
Receiver_Sensitivity=-80;%dBm
B=300e3;%系统带宽
M=4;%QPSK调制，M=4。
times=4320;%每20s发送一次，一天4320次
% 新结构
New_BER=zeros(1,8);%误码率
New_PER=zeros(1,8);%丢包率
New_count=zeros(1,8);%丢包个数
New_syncode=ones(1,32)*3;%载波同步
New_sqecode=randi([0 M-1],1,32);%序列码
New_scode=[1 1 1 1 3 2 1 2 1 1 0 1 0 1 2 0 1 3 2 3 3 2 2 3 1 1 0 3 1 2 1 3 1 2 3 2 2 1 0 2 3 0 1 3 0 2 0 1 1 3 0 0 1 2 2 0 0 1 0 2 3 3 0 2];%独特码
New_fecode=randi([0 M-1],1,64);%帧尾
% 旧结构
Old_BER=zeros(1,8);%误码率
Old_PER=zeros(1,8);%丢包率
Old_count=zeros(1,8);%丢包个数
Old_syncode=ones(1,160)*3;%载波同步
Old_sqecode=randi([0 M-1],1,80);%序列码
Old_scode=[1 1 1 1 3 2 1 2 1 1 0 1 0 1 2 0 1 3 2 3 3 2 2 3 1 1 0 3 1 2 1 3];%独特码
Old_fecode=randi([0 M-1],1,256);%帧尾
for i=1:1:8%每三个钟统计一次
    New_error=0;
    Old_error=0;
    for ii=1:1:times/8
        data=randi([0,M-1],1,1360);
        New_frame=[New_syncode New_sqecode New_scode data New_fecode];
        New_Sat_Flag=0;
        Old_Sat_Flag=0;
        % uplink
        isUplink=1;%上行链路
        loss1=rain_loss(i,isUplink);
        loss2=cloudfog_loss(i,isUplink);
        New_y=pskmod(New_frame,M,pi/M)*exp(-1j*2*pi*uplink_doppler(ii+(i-1)*times/8)/300e3);%M=4，QPSK调制。
        New_sigPower=sum(abs(New_y).^2)/length(New_y);
        Sat_reqSNR=culSNR(i,isUplink,loss1,loss2);
        New_r_Sat=awgn(New_y,Sat_reqSNR,'measured');
        New_r_Sat_scode=pskdemod(New_r_Sat(33:128),M,pi/M);
        if culerror([New_sqecode New_scode],New_r_Sat_scode)>0
            New_count(i)=New_count(i)+1;%如果校验失败，丢包
        end
  
        Old_frame=[Old_syncode Old_sqecode Old_scode data Old_fecode];
        Old_y=pskmod(Old_frame,M,pi/M)*exp(-1j*2*pi*uplink_doppler(ii+(i-1)*times/8)/300e3);%M=4，QPSK调制.
        Old_sigPower=sum(abs(Old_y).^2)/length(Old_y);
        Old_r_Sat=awgn(Old_y,Sat_reqSNR,'measured');
        Old_r_Sat_scode=pskdemod(Old_r_Sat(161:272),M,pi/M);
        if culerror([Old_sqecode Old_scode],Old_r_Sat_scode)>0
            Old_count(i)=Old_count(i)+1;%如果校验失败，丢包
        end

        % downlink
        isUplink=0;%下行链路
        loss1=rain_loss(i,isUplink);%雨衰落
        loss2=cloudfog_loss(i,isUplink);%云雾衰落
        New_y_Gs=New_r_Sat*exp(1j*2*pi*downlink_doppler(ii+(i-1)*times/8)/300e3);
        New_r_sigPower=sum(abs(New_y_Gs).^2)/length(New_y_Gs);
        Gs_reqSNR=10^culSNR(i,isUplink,loss1,loss2);%;10^(((rand(1, 1) * 20) - 10));
        New_r_noisePower=New_r_sigPower/Gs_reqSNR;
        New_r_noise=sqrt(New_r_noisePower/2)*(randn(1,length(New_y))+1j*randn(1,length(New_y)));
        New_r_Gs=New_y_Gs+New_r_noise;
        New_r_Gs_frame=pskdemod(New_r_Gs,M,pi/M);
        New_r_Gs_scode=New_r_Gs_frame(33:128);
        if New_Sat_Flag==0
            New_dataerror=culerror(data,New_r_Gs_frame(129:1488));%计算每次错误的符号个数。
            New_error=New_error+New_dataerror;
            if culerror([New_sqecode New_scode],New_r_Gs_scode)<=24
                
            else
                New_count(i)=New_count(i)+1;%如果校验失败，丢包
            end
        end
        Old_y_Gs=Old_r_Sat*exp(1j*2*pi*downlink_doppler(ii+(i-1)*times/8)/300e3);
        Old_r_sigPower=sum(abs(Old_y_Gs).^2)/length(Old_y_Gs);
        Old_r_noisePower=Old_r_sigPower/Gs_reqSNR;%New_reqSNR;
        Old_r_noise=sqrt(Old_r_noisePower/2)*(randn(1,length(Old_y))+1j*randn(1,length(Old_y)));
        Old_r_Gs=Old_y_Gs+Old_r_noise;
        Old_r_Gs_frame=pskdemod(Old_r_Gs,M,pi/M);
        Old_r_Gs_scode=Old_r_Gs_frame(161:272);
        if Old_Sat_Flag==0
            Old_dataerror=culerror(data,Old_r_Gs_frame(273:1632));%计算每次错误的符号个数。
            Old_error=Old_error+Old_dataerror;
            if culerror([Old_sqecode Old_scode],Old_r_Gs_scode)<=28
                
            else
                Old_count(i)=Old_count(i)+1;%如果校验失败，丢包
            end
        end
    end
    New_BER(i)=0.5*New_error/(times/8)/1360;%误码率
    New_PER(i)=New_count(i)/(times/8);%丢包率
    Old_BER(i)=0.5*Old_error/(times/8)/1360;%误码率
    Old_PER(i)=Old_count(i)/(times/8);%丢包率
end

% %% 
% % BER
% figure;
% semilogy(1:8,New_BER,'bo');hold on;
% semilogy(1:8,Old_BER,'rx');
% for i=1:8
%     text(i+0.1,New_BER(i),[num2str(New_BER(i))]);
%     text(i+0.1,Old_BER(i),[num2str(Old_BER(i))]);
% end
% xlabel('SNR');ylabel('BER');grid on
% t1=legend('优化调整帧格式','原帧格式','Location','northoutside');
% t1.NumColumns=2;
% xticks(1:8)
% xticklabels({'7:00-9:00','10:00-12:00','13:00-15:00','16:00-18:00','19:00-21:00','22:00-00:00','1:00-3:00','4:00-6:00'})% UTC
% % xticklabels({'15:00-17:00','18:00-20:00','21:00-23:00','00:00-2:00','3:00-5:00','6:00-8:00','9:00-11:00','12:00-14:00'})
% xlabel('time UTC')
% % FER
% figure;
% plot(1:8,New_PER,'bo');hold on;
% plot(1:8,Old_PER,'rx');
% for i=1:8
%     text(i+0.1,New_PER(i),[num2str(New_PER(i))]);
%     text(i+0.1,Old_PER(i),[num2str(Old_PER(i))]);
% end
% xlabel('SNR');ylabel('PER');grid on
% t2=legend('优化调整帧格式','原帧格式','Location','northoutside');
% t2.NumColumns=2;
% xticks(1:8)
% xticklabels({'7:00-9:00','10:00-12:00','13:00-15:00','16:00-18:00','19:00-21:00','22:00-00:00','1:00-3:00','4:00-6:00'})
% xlabel('Time UTC')
% 
% %% 计算吞吐量
New_throughput=(times/8-New_count)*1360*2/(3*60*10.34);
% figure;plot(1:8,New_throughput,'bo');xlabel('SNR');ylabel('Throughput (bit/s)');grid on;hold on;
Old_throughput=(times/8-Old_count)*1360*2/(3*60*13.12);
% plot(1:8,Old_throughput,'rx');xlabel('SNR');ylabel('Throughput (bit/s)');grid on
% for i=1:8
%     text(i+0.1,New_throughput(i),[num2str(New_throughput(i))]);
%     text(i+0.1,Old_throughput(i),[num2str(Old_throughput(i))]);
% end
% t3=legend('优化调整帧格式','原帧格式','Location','northoutside');
% t3.NumColumns=2;
% xticks(1:8)
% xticklabels({'7:00-9:00','10:00-12:00','13:00-15:00','16:00-18:00','19:00-21:00','22:00-00:00','1:00-3:00','4:00-6:00'})
% % xticklabels({'15:00-17:00','18:00-20:00','21:00-23:00','00:00-2:00','3:00-5:00','6:00-8:00','9:00-11:00','12:00-14:00'})
% xlabel('Time UTC')
%% 对比
Com_BER=zeros(length(New_BER),2);
Com_PER=zeros(length(New_PER),2);
Com_Throughput=zeros(length(New_throughput),2);
for i=1:length(New_BER)
    Com_BER(i,:)=[New_BER(i) Old_BER(i)];
    Com_PER(i,:)=[New_PER(i) Old_PER(i)];
    Com_Throughput(i,:)=[New_throughput(i) Old_throughput(i)];
end
figure;bar(1:8,Com_PER);
ylabel('PER');grid on
b1=legend('优化调整帧格式','原帧格式','Location','northoutside');
b1.NumColumns=2;
xticks(1:8)
xticklabels({'7:00-9:00','10:00-12:00','13:00-15:00','16:00-18:00','19:00-21:00','22:00-00:00','1:00-3:00','4:00-6:00'})
xlabel('Time UTC');


figure;bar(1:8,Com_BER);
ylabel('BER');grid on
b2=legend('优化调整帧格式','原帧格式','Location','northoutside');
b2.NumColumns=2;
xticks(1:8)
xticklabels({'7:00-9:00','10:00-12:00','13:00-15:00','16:00-18:00','19:00-21:00','22:00-00:00','1:00-3:00','4:00-6:00'})
xlabel('Time UTC');

figure;bar(1:8,Com_Throughput);
ylabel('Throughput (bit/s)');grid on
b3=legend('优化调整帧格式','原帧格式','Location','northoutside');
b3.NumColumns=2;
xticks(1:8)
xticklabels({'7:00-9:00','10:00-12:00','13:00-15:00','16:00-18:00','19:00-21:00','22:00-00:00','1:00-3:00','4:00-6:00'})
xlabel('Time UTC')


%% 返回错误符号个数
function xerror=culerror(x,xr)
xerror=0;
for i=1:1:length(x)
    if xr(i)~=x(i)
        xerror=xerror+1;
    end
end
end

%% 计算SNR
function SNR = culSNR(time,isUplink,loss1,loss2)
% 输入参数
% 计算SNR
k = 1.38e-23; % 玻尔兹曼常数（单位：J/K）
T = 120; % 系统的噪声温度（单位：K）
G_satellite = 0; % 卫星天线的增益（单位：dBi）
L_satellite = 0; % 卫星链路的传输损耗（单位：dB）
L_downlink = 190; % 下行链路的传输、极化损耗（单位：dB）
L_uplink = 179; % 上行链路的传输损耗（单位：dB）
NF_satellite = 1.5; % 卫星端的噪声系数（单位：dB）
L_receiver = 0; % 接收机链路的传输损耗（单位：dB）
NF_receiver = 1.5; % 接收机端的噪声系数（单位：dB）
G_LNA = 45; % LNA的增益（单位：dB）

if isUplink==1 %上行链路
    EIRP =45;%dBm
    G_T = -17; % G/T（单位：dBi/K）
    G_receiver = 10^(G_T/10) * T; % 接收机天线的增益（单位：dBi）
    
    SNR = EIRP + G_satellite - L_satellite -L_uplink - NF_satellite + G_receiver- L_receiver  - 10 * log10(k*T)-loss1-loss2;
else %下行链路
    EIPR =20;%dBm
    G_T = 18.41; % G/T（单位：dBi/K）
    G_receiver = 10^(G_T/10) * T; % 接收机天线的增益（单位：dBi）
    SNR = EIPR + G_satellite - L_satellite - L_downlink -  G_LNA + G_receiver - L_receiver - NF_receiver - 10 * log10(k*T)-loss1-loss2;
end% 输出结果
end


function loss = rain_loss(time,isUplink)
%% 雨衰落建模
R=[randi([50 100],1,2) randi([25 50],1,10) zeros(1,3) randi([0 10],1,9)];%2024年5月5日15：00-2024年5月6日14：59降雨率
% R = 10; % 降雨率，单位mm/h
Rain = randi([3*time-2 3*time]);
if isUplink==1
    f = 0.4;
else
    f = 1.7; % 信号频率，单位GHz
end
pol = 'H'; % 极化方式，'H'表示水平极化
theta = 15; % 路径仰角，单位度
loss = rain_attenuation_model(R(Rain), f, pol, theta);
    
function rain_attenuation = rain_attenuation_model(R, f, pol, theta)
    % R: 降雨率 (mm/h)
    % f: 信号频率 (GHz)
    % pol: 极化方式 ('H' 表示水平，'V' 表示垂直)
    % theta: 路径仰角 (度)
    % 根据ITU-R P.838-3中的表格查找k和alpha的值
    % 查表：https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.838-3-200503-I!!PDF-C.pdf
    d=2800;%m距离
    if(f==1.7)    
        k = 0.00006; % 查表
        alpha = 1.0185; % 查表
    else
        k = 2e-5;%f=401M
        alpha = 0.95;
    end
    % 计算雨衰落
    rain_attenuation = k * (R^alpha)*d;
    % 这里简化处理，实际中需要根据ITU-R P.838-3的建议进行更复杂的计算
end


end

function loss = cloudfog_loss(time,isUplink)
%% 云雾衰落
%% ITU-R P.804-8
if isUplink==1
    f = 400e6;%上行 400MHz
else
    f = 1.7e9; % 下行频率 1.7 GHz
end
T_cloud = 273; % 云的温度，假设为0°C
M_cloud = 0.5;%randi([5 8])/10;%0.5; % 云水含量，单位为g/m^3
% if time<=4
    d = 2.8; % 路径长度，单位为km
% else
    % d = 3;
% end

loss = Cloud_Loss(f, T_cloud, M_cloud, d);

function cloud_loss = Cloud_Loss(f, T_cloud, M_cloud, d)
    theta = 300 / T_cloud;
    Epsilon_0 = 77.66 + 103.3 * (theta - 1);
    Epsilon_1 = 0.0671 * Epsilon_0;
    Epsilon_2 = 3.52;
    fp = 20.2 - 146 * (theta - 1) + 316 * (theta - 1)^2;
    fs = 39.8 * fp;
    Epsilon_p = (Epsilon_0 - Epsilon_1) / (1 + (f / fp)^2) + ...
                (Epsilon_1 - Epsilon_2) / (1 + (f / fs)^2) + Epsilon_2;
    Epsilon_pp = f * (Epsilon_0 - Epsilon_1) / (fp * (1 + (f / fp)^2)) + ...
                 f * (Epsilon_1 - Epsilon_2) / (fs * (1 + (f / fs)^2));
    eta = (2 + Epsilon_p) / Epsilon_pp;
    KL = 0.819 * f / (Epsilon_pp * (1 + eta^2));
    % 已×d
    gamma_c = KL * M_cloud * d;
    cloud_loss = gamma_c;
end

end