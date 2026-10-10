%% DCP->FY->GS　ａｓｄｓｄｄｆ
% 上行链路401.1MHz，下行链路1.6875GHz
%QPSK门特卡罗实验计算PER
fs=77.5e6;
load('doppler_delay_fivedays.mat');
uplink_delay_fivedays=round(uplink_delay_fivedays/5.23*1752);
downlink_delay_fivedays=round(downlink_delay_fivedays/5.23*1752);
[R] = xlsread('C:\Users\49538\Desktop\r20240511分钟降水量.csv');%降雨量

B=300e3;
times=4320;%每20s发送一次，一天4320次

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
% 新结构
New_syncode=ones(1,32)*3;%载波同步
New_sqecode=randi([0 M-1],1,32);%序列码
New_unicode=[1 1 1 1 3 2 1 2 1 1 0 1 0 1 2 0 1 3 2 3 3 2 2 3 1 1 0 3 1 2 1 3 1 2 3 2 2 1 0 2 3 0 1 3 0 2 0 1 1 3 0 0 1 2 2 0 0 1 0 2 3 3 0 2];%独特码
New_fecode=randi([0 M-1],1,64);%帧尾
New_data_frame=[New_syncode New_sqecode New_unicode data_frame New_fecode];%组帧
New_preamble=[New_syncode New_sqecode New_unicode zeros(1,length(data_frame)) New_fecode];
% 旧结构 
Old_syncode=ones(1,32*5)*3;%载波同步
Old_sqecode=randi([0 M-1],1,80);%序列码
% Old_unicode=[1 1 1 1 3 2 1 2 1 1 0 1 0 1 2 0 1 3 2 3 3 2 2 3 1 1 0 3 1 2 1 3 1 2 3 2 2 1 0 2 3 0 1 3 0 2 0 1 1 3 0 0 1 2 2 0 0 1 0 2 3 3 0 2];%独特码
Old_unicode=New_unicode(1:length(New_unicode)/2);
Old_fecode=randi([0 M-1],1,32);%帧尾
Old_data_frame=[Old_syncode Old_sqecode Old_unicode data_frame Old_fecode];%组帧
Old_preamble=[Old_syncode Old_sqecode Old_unicode zeros(1,length(data_frame)) Old_fecode];
New_data_QPSK=pskmod(New_data_frame,M,pi/M);
Old_data_QPSK=pskmod(Old_data_frame,M,pi/M);
tic;
New_per=zeros(1,5);
Old_per=zeros(1,5);
New_ber=zeros(1,5);
Old_ber=zeros(1,5);
for i=1:1:5%每天统计一次
    New_per_num=0;
    Old_per_num=0;
    New_ber_num=0;
    Old_ber_num=0;
    New_times=0;
    Old_times=0;
    for ii=1:1:times     
        New_Sat_Flag=0;
        Old_Sat_Flag=0;
        % uplink
        isUplink=1;%上行链路
        loss1=rain_loss(R(ceil(((i-1)*times+ii)/3)),isUplink);%雨衰落
        loss2=cloudfog_loss(i,isUplink);%云雾衰落
        loss3=at_loss(i,isUplink);%大气损耗
        New_y=New_data_QPSK*exp(-1j*2*pi*uplink_doppler_fivedays(ii+(i-1)*times)/B);
        New_sigPower=sum(abs(New_y).^2)/length(New_y);
        Sat_reqSNR=culSNR(i,isUplink,loss1,loss2,loss3);
        New_r_Sat=awgn(New_y,Sat_reqSNR,'measured');
        Old_y=Old_data_QPSK*exp(-1j*2*pi*uplink_doppler_fivedays(ii+(i-1)*times)/B);%
        Old_r_Sat=awgn(Old_y,Sat_reqSNR,'measured');

        % downlink
        isUplink=0;%下行链路
        loss1=rain_loss(R(ceil(((i-1)*times+ii)/3)),isUplink);%雨衰落
        loss2=cloudfog_loss(i,isUplink);%云雾衰落
        loss3=at_loss(i,isUplink);
        New_y_Gs=New_r_Sat*exp(1j*2*pi*downlink_doppler_fivedays(ii+(i-1)*times)/B);
        Gs_reqSNR=culSNR(i,isUplink,loss1,loss2,loss3);
        New_r_Gs=awgn(New_y_Gs,Gs_reqSNR,'measured');


        % New_r_sigPower=sum(abs(New_y_Gs).^2)/length(New_y_Gs);
        % Gs_reqSNR=10^(culSNR(i,isUplink,loss1,loss2,loss3)/10);
        % New_r_noisePower=New_r_sigPower/Gs_reqSNR;
        % New_r_noise=sqrt(New_r_noisePower/2)*(randn(1,length(New_y))+1j*randn(1,length(New_y)));
        % New_r_Gs=New_y_Gs+New_r_noise;
        % data_1_tmp=[zeros(1,uplink_delay_fivedays(ii+(i-1)*times)) zeros(1,downlink_delay_fivedays(ii+(i-1)*times)) New_r_Gs];
        
        Old_y_Gs=Old_r_Sat*exp(1j*2*pi*downlink_doppler_fivedays(ii+(i-1)*times)/B);
        Old_r_sigPower=sum(abs(Old_y_Gs).^2)/length(Old_y_Gs);
        Old_r_noisePower=Old_r_sigPower/Gs_reqSNR;
        Old_r_noise=sqrt(Old_r_noisePower/2)*(randn(1,length(Old_y))+1j*randn(1,length(Old_y)));
        Old_r_Gs=Old_y_Gs+Old_r_noise;
        data_2_tmp=[zeros(1,uplink_delay_fivedays(ii+(i-1)*times)) zeros(1,downlink_delay_fivedays(ii+(i-1)*times)) Old_r_Gs];
        
        % data_demod=pskdemod(data_1_tmp,M,pi/M);
        %% 新帧
        for d=1:length(data_1_tmp)
            if(d+length(New_preamble)>length(data_1_tmp))
                break;
            end
            data_tmp=data_1_tmp(d+1:d+length(New_preamble));
            data_tmp_pre=data_tmp(1:128);%
            data_tmp_end=data_tmp(2169:end);%
            data_tmp=[data_tmp_pre zeros(1,2040) data_tmp_end];%
            data_tmp=pskdemod(data_tmp,M,pi/M);
            if(culerror(New_preamble,data_tmp))
                delay=d;
            else
                delay=-1;
            end
        end
        if(delay~=-1)
            New_times=New_times+1;
            data_re=[data_1_tmp(delay+1:end)];%% 
            data_re_deQPSK=pskdemod(data_re,M,pi/M);
            data_deQPSK=data_re_deQPSK(129:2168);%数据部分(卷积码)
            %% 将一位十进制转换为两位二进制数
            data_deQPSK_bin=0;
            for k=1:length(data_deQPSK)
                if(data_deQPSK(k)==0)
                    data_deQPSK_bin=[data_deQPSK_bin 0 0];
                end
                if(data_deQPSK(k)==1)
                    data_deQPSK_bin=[data_deQPSK_bin 0 1];
                end
                if(data_deQPSK(k)==2)
                    data_deQPSK_bin=[data_deQPSK_bin 1 0];
                end
                if(data_deQPSK(k)==3)
                    data_deQPSK_bin=[data_deQPSK_bin 1 1];
                end
            end
            data_deQPSK_bin=data_deQPSK_bin(2:end);
            %% 卷积码解码
            tb = 2;
            decoded_CONV = vitdec(data_deQPSK_bin,trellis,tb,'trunc','hard');%二进制
            %% RS解码
            decoded_CONV_dec=zeros(1,length(decoded_CONV)/8);
            % 八位二进制转成十进制
            for k=1:length(decoded_CONV_dec)
                nums_bin=[128 64 32 16 8 4 2 1];
                decoded_CONV_dec(k)=sum(decoded_CONV(8*k-7:8*k).*nums_bin);
                % decoded_CONV_dec(i)=decoded_CONV(8*i)*2^0+decoded_CONV(8*i-1)*2+decoded_CONV(8*i-2)*2^2+...
                %                     decoded_CONV(8*i-3)*2^3+decoded_CONV(8*i-4)*2^4+decoded_CONV(8*i-5)*2^5+...
                %                     decoded_CONV(8*i-6)*2^6+decoded_CONV(8*i-7)*2^7;
            end
            mes=gf(decoded_CONV_dec,8);
            n=255;%码字长度
            k=223;%每组符号数
            [dc,nerrs,corrcode]= rsdec(mes,n,k);
            decoded_RS=double(dc.x);
            %% 计算误符号个数
            for k=1:length(decoded_RS)
                if(data(k)~=decoded_RS(k))
                    New_ber_num=New_ber_num+1;
                end
            end

        else
            New_per_num=New_per_num+1;
        end
        






        %% 旧帧
        for d=1:length(data_2_tmp)
            if(d+length(Old_preamble)>length(data_2_tmp))
                break;
            end
            data_tmp=data_2_tmp(d+1:d+length(Old_preamble));
            data_tmp_pre=data_tmp(1:272);%
            data_tmp_end=data_tmp(2313:end);%
            data_tmp=[data_tmp_pre zeros(1,2040) data_tmp_end];%
            data_tmp=pskdemod(data_tmp,M,pi/M);
            if(culerror(Old_preamble,data_tmp))
                delay=d;
            else
                delay=-1;
            end
        end
        if(delay~=-1)
            Old_times=Old_times+1;
            data_re=[data_2_tmp(delay+1:end)];%%
            data_re_deQPSK=pskdemod(data_re,M,pi/M);
            data_deQPSK=data_re_deQPSK(273:2312);%数据部分(卷积码)
            %% 将一位十进制转换为两位二进制数
            data_deQPSK_bin=0;
            for k=1:length(data_deQPSK)
                if(data_deQPSK(k)==0)
                    data_deQPSK_bin=[data_deQPSK_bin 0 0];
                end
                if(data_deQPSK(k)==1)
                    data_deQPSK_bin=[data_deQPSK_bin 0 1];
                end
                if(data_deQPSK(k)==2)
                    data_deQPSK_bin=[data_deQPSK_bin 1 0];
                end
                if(data_deQPSK(k)==3)
                    data_deQPSK_bin=[data_deQPSK_bin 1 1];
                end
            end
            data_deQPSK_bin=data_deQPSK_bin(2:end);
            %% 卷积码解码
            tb = 2;
            decoded_CONV = vitdec(data_deQPSK_bin,trellis,tb,'trunc','hard');%二进制
            %% RS解码
            decoded_CONV_dec=zeros(1,length(decoded_CONV)/8);
            % 八位二进制转成十进制
            for k=1:length(decoded_CONV_dec)
                nums_bin=[128 64 32 16 8 4 2 1];
                decoded_CONV_dec(k)=sum(decoded_CONV(8*k-7:8*k).*nums_bin);
                % decoded_CONV_dec(i)=decoded_CONV(8*i)*2^0+decoded_CONV(8*i-1)*2+decoded_CONV(8*i-2)*2^2+...
                %                     decoded_CONV(8*i-3)*2^3+decoded_CONV(8*i-4)*2^4+decoded_CONV(8*i-5)*2^5+...
                %                     decoded_CONV(8*i-6)*2^6+decoded_CONV(8*i-7)*2^7;
            end
            mes=gf(decoded_CONV_dec,8);
            n=255;%码字长度
            k=223;%每组符号数
            [dc,nerrs,corrcode]= rsdec(mes,n,k);
            decoded_RS=double(dc.x);
            %% 计算误符号个数
            for k=1:length(decoded_RS)
                if(data(k)~=decoded_RS(k))
                    Old_ber_num=Old_ber_num+1;
                end
            end
        else
            Old_per_num=Old_per_num+1;
        end

    end
    New_per(i)=New_per_num/4320;
    Old_per(i)=Old_per_num/4320;
    New_ber(i)=New_ber_num/(223*New_times)*(2^(M-1)/(2^(M)-1));%M进制误符号率与误比特率的关系
    Old_ber(i)=Old_ber_num/(223*Old_times)*(2^(M-1)/(2^(M)-1));
end
New_per_ave=sum(New_per)/5;
Old_per_ave=sum(Old_per)/5;
New_ber_ave=sum(New_ber)/5;
Old_ber_ave=sum(Old_ber)/5;
toc;
%% 画图
Com_PER=zeros(length(New_per),2);
Com_BER=zeros(length(New_ber),2);
for i=1:length(New_per)
    Com_PER(i,:)=[New_per(i) Old_per(i)];
    Com_BER(i,:)=[New_ber(i) Old_ber(i)];
end
figure;bar(1:5,Com_PER);
ylabel('PER');grid on
b1=legend(['优化调整帧格式,平均丢包率：' num2str(New_per_ave)],['原帧格式,平均丢包率：' num2str(Old_per_ave)],'Location','northoutside');
b1.NumColumns=2;
xticks(1:5)
xticklabels({'day1','day2','day3','day4','day5'})
xlabel('Time ');

figure;bar(1:5,Com_BER);
ylabel('BER');grid on
b1=legend(['优化调整帧格式,平均误比特率：' num2str(New_ber_ave)],['原帧格式,平均误比特率：' num2str(Old_ber_ave)],'Location','northoutside');
b1.NumColumns=2;
xticks(1:5)
xticklabels({'day1','day2','day3','day4','day5'})
xlabel('Time ');

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
    EIRP =44;%dBm
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
    
    function rain_attenuation = rain_attenuation_model(R, f, pool, theta)
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

function loss = eloss(f,sigma,loe)
    c = 3e8;
    loss = 2*pi*f*sigma/(c*loe);
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


function flag = culerror(preamble,data)
    flag=1;
    for i=1:length(preamble)
        if(preamble(i)~=data(i))
            flag=0;
        end
    end


end