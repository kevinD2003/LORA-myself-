%% DCP->FY->GS　ａｓｄｓｄｄｆ
% 上行链路401.1MHz，下行链路1.6875GHz
%QPSK门特卡罗实验计算BER
fs=77.5e6;
load('doppler_delay_fivedays.mat');
uplink_delay_fivedays=round(uplink_delay_fivedays/5.23*1752);
downlink_delay_fivedays=round(downlink_delay_fivedays/5.23*1752);
[R] = xlsread('C:\Users\49538\Desktop\r20240511分钟降水量.csv');%降雨量

B=300e3;%系统带宽
times=4320*3;%每20s发送一次，一天4320次
% times=1;
% 新结构

%% RS编码 卷积码 QPSK调制 
data=[87 88 48 53 48 32 48 48 48 46 48 48 32 50 52 48 53 49 53 48 51 51 57 32 48 50 51 49 48 32 50 57 49 54 78 32 49 49 51 50 54 32 55 49 48 53 69 32 48 48 57 55];
data=[data zeros(1,223-length(data))];
%% RS编码
[data_RS,c]=RS_CODE(data);
%% 卷积码
[data_CONV,trellis]=CONV_CODE(data_RS);

%% 将两位二进制数转换为十进制
data_frame=zeros(1,length(data_CONV)/2);
for i=1:length(data_frame)
    data_frame(i)=data_CONV(2*i)*2^(0)+data_CONV(2*i-1)*2;
end
%% QPSK调制
M=4;%QPSK
data_QPSK=pskmod(data_frame,M,pi/M);
tic;
for i=1:1:1%每天统计一次
    for ii=1:1:times     
        New_Sat_Flag=0;
        Old_Sat_Flag=0;
        % uplink
        isUplink=1;%上行链路
        loss1=rain_loss(R(ceil(((i-1)*times+ii)/3)),isUplink);
        loss2=cloudfog_loss(i,isUplink);
        loss3=at_loss(i,isUplink);
        New_y=data_QPSK*exp(-1j*2*pi*uplink_doppler_fivedays(ii+(i-1)*times)/300e3);%M=4，QPSK调制。
        New_sigPower=sum(abs(New_y).^2)/length(New_y);
        Sat_reqSNR=culSNR(i,isUplink,loss1,loss2,loss3);
        New_r_Sat=awgn(New_y,Sat_reqSNR,'measured');
       
        % downlink
        isUplink=0;%下行链路
        loss1=rain_loss(R(ceil(((i-1)*times+ii)/3)),isUplink);%雨衰落
        loss2=cloudfog_loss(i,isUplink);%云雾衰落
        loss3=at_loss(i,isUplink);
        New_y_Gs=New_r_Sat*exp(1j*2*pi*downlink_doppler_fivedays(ii+(i-1)*times)/300e3);
        New_r_sigPower=sum(abs(New_y_Gs).^2)/length(New_y_Gs);
        Gs_reqSNR=10^culSNR(i,isUplink,loss1,loss2,loss3);%;10^(((rand(1, 1) * 20) - 10));
        New_r_noisePower=New_r_sigPower/Gs_reqSNR;
        New_r_noise=sqrt(New_r_noisePower/2)*(randn(1,length(New_y))+1j*randn(1,length(New_y)));
        New_r_Gs=New_y_Gs+New_r_noise;
        data_1_tmp=[zeros(1,uplink_delay_fivedays(ii+(i-1)*times)) zeros(1,downlink_delay_fivedays(ii+(i-1)*times)) New_r_Gs];
        % data_1(ii,1:length(data_1_tmp))=data_1_tmp;
        % load("data_send.mat");
        mat2txt('数据.txt',data_1_tmp);
    end
end
toc;

%% 计算SNR
function SNR = culSNR(time,isUplink,loss1,loss2,loss3)
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
    
    SNR = EIRP + G_satellite - L_satellite -L_uplink - NF_satellite + G_receiver- L_receiver  - 10 * log10(k*T)-loss1-loss2-loss3;
else %下行链路
    EIPR =20;%dBm
    G_T = 18.41; % G/T（单位：dBi/K）
    G_receiver = 10^(G_T/10) * T; % 接收机天线的增益（单位：dBi）
    SNR = EIPR + G_satellite - L_satellite - L_downlink -  G_LNA + G_receiver - L_receiver - NF_receiver - 10 * log10(k*T)-loss1-loss2-loss3;
end% 输出结果
end


function loss = rain_loss(R,isUplink)
%% 雨衰落建模
% R=[randi([50 100],1,2) randi([25 50],1,10) zeros(1,3) randi([0 10],1,9)];%2024年5月5日15：00-2024年5月6日14：59降雨率
% R = 10; % 降雨率，单位mm/h
% Rain = randi([3*time-2 3*time]);
if isUplink==1
    f = 0.4;
else
    f = 1.7; % 信号频率，单位GHz
end
pol = 'H'; % 极化方式，'H'表示水平极化
theta = 15; % 路径仰角，单位度
loss = rain_attenuation_model(R, f, pol, theta);
    
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

%% 大气损耗
function loss=at_loss(time,isUplink)

pa=[1007.4	1007.8	1008.1	1007.7	1007.1	1007	1006.8	1006.5	1006.1	1006.3	1006.7	1007.6	1008.1	1008.2	1007.9	1007.8	1007.3	1006.3	1005.6	1005.3	1004.6	1004.6	1004.6	1005.3
1006	1006.7	1006.8	1006.5	1005.9	1005.7	1005.5	1005.9	1006.2	1006.4	1006.9	1007.3	1007.6	1007.4	1006.6	1006	1005.1	1004.3	1003.6	1002.7	1002.3	1002.4	1002.7	1003.4
1004	1004.1	1004.3	1004.2	1004	1003.8	1003.6	1003.3	1004	1004.4	1004.5	1005	1005.3	1005.3	1005.5	1005.1	1004.7	1003.8	1003.1	1002.3	1002.3	1002.6	1002.6	1002.7
1003.5	1004	1003.7	1003.5	1003.1	1002.7	1002.8	1002.8	1003.3	1003.6	1004.1	1004.5	1004.8	1005	1004.8	1004.6	1004	1003.3	1002.8	1002.2	1002.3	1002.4	1003.1	1003.7
1004.1	1004.2	1004.6	1004.7	1004.5	1004.3	1004.1	1004.1	1004.2	1004.7	1005.5	1006.2	1006.5	1006.5	1006.2	1005.6	1005	1004.2	1003.6	1003.2	1003	1003.3	1003.6	1004.3
];%气压每日每小时

TP=[24.2	23.9	23.8	23.5	23.2	22.9	22.6	22.7	22	21.8	22.2	23.6	24.2	26	26.9	27.7	28	27.9	28.1	28	28	27.7	26.9	26.4
26.2	25.9	25.5	25.1	24.5	24.5	24.3	24.1	23.4	23.2	23.6	25.3	26.8	26.9	27.9	29.1	29.9	30.1	29.8	29.6	29.7	29	28.3	27.5
27.1	26.6	26.2	25.7	25.1	24.5	24.6	25.4	25.3	25.4	25.7	26.1	25.5	26.3	23.6	24.2	23.7	22.8	24.3	26.6	27.4	26	24.9	24
23.5	23	22.8	22.8	22.7	22.7	22.5	22.6	22.7	22.6	23	23.8	24.8	25.3	26.3	27.3	28.6	29.6	30.2	30	30	29.2	26.4	24.6
23.6	23	22.6	22.4	22.2	22.2	22	21.9	21.5	21.4	22	23.8	25.7	27.5	27.6	28.5	29.4	30.2	31.2	32	31.9	31	27.3	26.6
];%温度每日每小时

LOD=[26 23 21 23 23];%水汽密度每日

if isUplink==1
    f = 0.4; % 载波频率，单位为GHz
else
    f=1.7;
end
p = pa(ceil(time/180)); % 干燥空气压力，单位为hPa
T = TP(ceil(time/180))+273.5; % 温度，单位为开尔文
lo = LOD(ceil(time/4320)); % 水汽密度，单位为g/m3
% lo = 0;

e = lo * T / 216.7; % 水汽压力，单位为hPa

sita = 300 / T;

d = 5.6 * 10^(-4) * (p + e) * sita^(0.8); % 宽度参数

N_D = f * p * sita^2 * (6.14 * 10^(-5) / (d * (1 + (f / d)^2)) + 1.4 * 10^(-12) * p * sita^(1.5) / (1 + 1.9 * 10^(-5) * f^1.5));

R = 0.1820 * f * N_D; % 衰减值，单位为dB/km
loss=R*10;
end

function back = mat2txt( file_Name, matrix ) 
fop = fopen( file_Name, 'a' );
[M,N] = size(matrix);
for m = 1:M
    for n = 1:N
        fprintf( fop, ' %s', mat2str( matrix(m,n) ) );
    end
    fprintf(fop, '\n' );
end
back = fclose( fop ) ;
end




%% %%编码
%% RS编码，输出数据为二进制
function [data_RS_code,c]=RS_CODE(x)
%快速演示，没有具体的编码解码方法
% m=4;%每个符号比特数
n=255;%码字长度
k=223;%每组符号数
msgw=gf(x,8);
c=rsenc(msgw,n,k);%RS编码
%—————信道部分———————————
data_RS=double(c.x);
data_RS_code=0;
for i=1:length(data_RS)
    data_RS_code=[data_RS_code d2b(data_RS(i))];
end
data_RS_code=data_RS_code(2:end);

end

function data_bin=d2b(x)
data_bin=zeros(1,8);
i=1;
while(x)
    data_bin(9-i)=mod(x,2);
    i=i+1;
    x=floor(x/2);
end
end


function [data_CONV_code,trellis]=CONV_CODE(input)
n=2;k=1;L=7;% 表明是（2，1，7）编码
gen=[171,133];%编码多项式，217的编码多项式为（171，133）；
%生成卷积码
trellis = poly2trellis(L,gen);
data_CONV_code = convenc(input,trellis);
end
