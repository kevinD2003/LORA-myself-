clc;
 clear;
 close all;fs = 12e6; %采样频率
 ts = 1/fs; 
 num = 2.5e6;  %数据长度
 SNR = -15;
 real_fc = 3563000; %实信号频率
 data = sin(2*pi*real_fc*(0:num-1)*ts+pi/4)+sqrt(10^(SNR/10))*randn(1,num); %科斯塔斯环的输入信号
 fc = 3562800; %本地频率
  
 n = fs/1000; %累积时间为1ms
 nn = [0:n-1];
 nf = floor(length(data)/n);% 将输入数据分成1ms的多个数据块
 wfc = 2*pi*fc;  %本地信号
 phi_prv = 0;
 temp = 0;
 frame = 0;
 carrier_phase = 0;
 phase = 0;
  
 %环路滤波器的参数
 c1 = 153.7130;
 c2 = 6.1498;for frame=1:nf 
 % 产生本地的sin和cos函数
 expcol = exp(1j*(wfc*ts*nn+phase));
 sine = imag(expcol);   
 cosine = real(expcol);x = data((1:n)+((frame-1)*n));
 %将数据转换到基带
 x_sine = x.*sine;
 x_cosine = x.*cosine;
  
 Q = sum(x_sine);      %经过滤波器
 I = sum(x_cosine);
 phase_discri(frame) = atan(Q/I);   %得到锁相环的输入
  
 %锁相环
 dfrq = c1*phase_discri(frame)+temp; %经过环路滤波器
 temp = temp+c2*phase_discri(frame);
 wfc = wfc-dfrq*2*pi;   %改变本地频率
 dfrq_frame(frame) = wfc; 
 phase = wfc*ts*n+phase;   %得到不同块的相位
 end
 plot(dfrq_frame/(2*pi),'LineWidth',2);
 hold on
 plot([1:length(dfrq_frame)], real_fc,'r','LineWidth',2);
 legend('锁相环跟踪','实际的载波频率');
 grid
 mean_freq=mean(dfrq_frame/2/pi)
 p=abs(real_fc-mean_freq)/real_fc;