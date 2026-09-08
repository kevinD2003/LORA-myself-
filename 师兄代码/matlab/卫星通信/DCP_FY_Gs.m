%% DCP->FY->GS
% 上行链路400MHz，下行链路1.7GHz,接收机灵敏度-80dBm
%QPSK门特卡罗实验计算BER
load('DopplerShift.mat');
Receiver_Sensitivity=-80;%dBm
signal_power=53;%dBm，发送信号功率
G1=8.5;%dBi,天线增益
G2=44;%dBi，天线增益
Gs=142;%dB,卫星增益
T1=464;%k,噪声温度
T2=186;%k,噪声温度
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
        New_y=pskmod(New_frame,M,pi/M)*exp(-1j*2*pi*uplink(ii+(i-1)*times/8)/300e3);%M=4，QPSK调制。
        New_sigPower=sum(abs(New_y).^2)/length(New_y);
        Sat_reqSNR=10^randi([0 40]);%10^(((rand(1, 1) * 20) - 10));
        New_noisePower=New_sigPower/Sat_reqSNR;
        New_noise=sqrt(New_noisePower/2)*(randn(1,length(New_y))+1j*randn(1,length(New_y)));
        New_r_Sat=New_y+New_noise;
        New_r_Sat_scode=pskdemod(New_r_Sat(33:128),M,pi/M);
        if culerror([New_sqecode New_scode],New_r_Sat_scode)>0
            New_count(i)=New_count(i)+1;%如果校验失败，丢包
            New_Sat_Flag=1;
            % continue;
            New_r_Sat=zeros(1,length(New_frame));
        end
  
        Old_frame=[Old_syncode Old_sqecode Old_scode data Old_fecode];
        Old_y=pskmod(Old_frame,M,pi/M)*exp(-1j*2*pi*uplink(ii+(i-1)*times/8)/300e3);%M=4，QPSK调制.
        Old_sigPower=sum(abs(Old_y).^2)/length(Old_y);
        Old_noisePower=Old_sigPower/Sat_reqSNR;%New_reqSNR;
        Old_noise=sqrt(Old_noisePower/2)*(randn(1,length(Old_y))+1j*randn(1,length(Old_y)));
        Old_r_Sat=Old_y+Old_noise;
        Old_r_Sat_scode=pskdemod(Old_r_Sat(161:272),M,pi/M);
        if culerror([Old_sqecode Old_scode],Old_r_Sat_scode)>0
            Old_count(i)=Old_count(i)+1;%如果校验失败，丢包
            Old_Sat_Flag=1;
            % continue;
            Old_r_Sat=zeros(1,length(Old_frame));
        end

        % downlink
        New_y_Gs=New_r_Sat*exp(1j*2*pi*downlink(ii+(i-1)*times/8)/300e3);
        New_r_sigPower=sum(abs(New_y_Gs).^2)/length(New_y_Gs);
        Gs_reqSNR=10^randi([50 200]);%;10^(((rand(1, 1) * 20) - 10));
        New_r_noisePower=New_r_sigPower/Gs_reqSNR;
        New_r_noise=sqrt(New_r_noisePower/2)*(randn(1,length(New_y))+1j*randn(1,length(New_y)));
        New_r_Gs=New_y_Gs+New_r_noise;
        New_r_Gs_frame=pskdemod(New_r_Gs,M,pi/M);
        New_r_Gs_scode=New_r_Gs_frame(33:128);
        if New_Sat_Flag==0
            if culerror([New_sqecode New_scode],New_r_Gs_scode)<=48
                New_dataerror=culerror(data,New_r_Gs_frame(129:1488));%计算每次错误的符号个数。
                New_error=New_error+New_dataerror;
            else
                New_count(i)=New_count(i)+1;%如果校验失败，丢包
            end
        end
        % if culerror([New_sqecode New_scode],New_r_Gs_scode)<=48
        %    % New_dataerror=culerror(data,New_r_Gs_frame(129:1488));%计算每次错误的符号个数。
        %    % New_error=New_error+New_dataerror; 
        % else
        %     New_count(i)=New_count(i)+1;%如果校验失败，丢包
        % end
        % New_dataerror=culerror(data,New_r_Gs_frame(129:1488));%计算每次错误的符号个数。
        % New_error=New_error+New_dataerror;
        Old_y_Gs=Old_r_Sat*exp(1j*2*pi*downlink(ii+(i-1)*times/8)/300e3);
        Old_r_sigPower=sum(abs(Old_y_Gs).^2)/length(Old_y_Gs);
        Old_r_noisePower=Old_r_sigPower/Gs_reqSNR;%New_reqSNR;
        Old_r_noise=sqrt(Old_r_noisePower/2)*(randn(1,length(Old_y))+1j*randn(1,length(Old_y)));
        Old_r_Gs=Old_y_Gs+Old_r_noise;
        Old_r_Gs_frame=pskdemod(Old_r_Gs,M,pi/M);
        Old_r_Gs_scode=Old_r_Gs_frame(161:272);
        if Old_Sat_Flag==0
            if culerror([Old_sqecode Old_scode],Old_r_Gs_scode)<=56
                Old_dataerror=culerror(data,Old_r_Gs_frame(273:1632));%计算每次错误的符号个数。
                Old_error=Old_error+Old_dataerror;
            else
                Old_count(i)=Old_count(i)+1;%如果校验失败，丢包
            end
        end
        % if culerror([Old_sqecode Old_scode],Old_r_Gs_scode)<=56
        %    % Old_dataerror=culerror(data,Old_r_Gs_frame(273:1632));%计算每次错误的符号个数。
        %    % Old_error=Old_error+Old_dataerror; 
        % else
        %     Old_count(i)=Old_count(i)+1;%如果校验失败，丢包
        % end
        % Old_dataerror=culerror(data,Old_r_Gs_frame(273:1632));%计算每次错误的符号个数。
        % Old_error=Old_error+Old_dataerror;
    end
    New_BER(i)=0.5*New_error/(times/8-New_count(i))/1360;%误码率
    New_PER(i)=New_count(i)/(times/8);%丢包率
    Old_BER(i)=0.5*Old_error/(times/8-Old_count(i))/1360;%误码率
    Old_PER(i)=Old_count(i)/(times/8);%丢包率
end

%% 
% BER
figure;
semilogy(1:8,New_BER,'bo');hold on;
semilogy(1:8,Old_BER,'rx');
for i=1:8
    text(i+0.1,New_BER(i),[num2str(New_BER(i))]);
    text(i+0.1,Old_BER(i),[num2str(Old_BER(i))]);
end
xlabel('SNR');ylabel('BER');grid on
t1=legend('优化调整帧格式','原帧格式','Location','northoutside');
t1.NumColumns=2;
xticks(1:8)
xticklabels({'7:00-9:00','10:00-12:00','13:00-15:00','16:00-18:00','19:00-21:00','22:00-00:00','1:00-3:00','4:00-6:00'})% UTC
% xticklabels({'15:00-17:00','18:00-20:00','21:00-23:00','00:00-2:00','3:00-5:00','6:00-8:00','9:00-11:00','12:00-14:00'})
xlabel('time UTC')
% FER
figure;
plot(1:8,New_PER,'bo');hold on;
plot(1:8,Old_PER,'rx');
for i=1:8
    text(i+0.1,New_PER(i),[num2str(New_PER(i))]);
    text(i+0.1,Old_PER(i),[num2str(Old_PER(i))]);
end
xlabel('SNR');ylabel('PER');grid on
t2=legend('优化调整帧格式','原帧格式','Location','northoutside');
t2.NumColumns=2;
xticks(1:8)
xticklabels({'7:00-9:00','10:00-12:00','13:00-15:00','16:00-18:00','19:00-21:00','22:00-00:00','1:00-3:00','4:00-6:00'})
xlabel('time UTC')

%% 计算吞吐量
New_throughput=(times/8-New_count)*1360*2/(3*60*7.24);
figure;plot(1:8,New_throughput,'bo');xlabel('SNR');ylabel('Throughput (bit/s)');grid on;hold on;
Old_throughput=(times/8-Old_count)*1360*2/(3*60*9.184);
plot(1:8,Old_throughput,'rx');xlabel('SNR');ylabel('Throughput (bit/s)');grid on
for i=1:8
    text(i+0.1,New_throughput(i),[num2str(New_throughput(i))]);
    text(i+0.1,Old_throughput(i),[num2str(Old_throughput(i))]);
end
t3=legend('优化调整帧格式','原帧格式','Location','northoutside');
t3.NumColumns=2;
xticks(1:8)
xticklabels({'7:00-9:00','10:00-12:00','13:00-15:00','16:00-18:00','19:00-21:00','22:00-00:00','1:00-3:00','4:00-6:00'})
% xticklabels({'15:00-17:00','18:00-20:00','21:00-23:00','00:00-2:00','3:00-5:00','6:00-8:00','9:00-11:00','12:00-14:00'})
xlabel('time UTC')

%% 返回错误符号个数
function xerror=culerror(x,xr)
xerror=0;
for i=1:1:length(x)
    if xr(i)~=x(i)
        xerror=xerror+1;
    end
end
end