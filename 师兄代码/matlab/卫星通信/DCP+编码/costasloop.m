clc;clear all;close all;
fs = 50e6; %采样频率
ts = 1/fs; 
num = 2e6;  %数据长度
SNR = -15;
real_fc = 10000500; %实信号频率
data = sin(2*pi*real_fc*(0:num-1)*ts+pi/4)+sqrt(10^(SNR/10))*randn(1,num); %科斯塔斯环的输入信号
fc = 10000000; %本地频率
K=1e4;
n = fs/K; %累积时间为0.1ms
nn = [0:n-1];
nf = floor(length(data)/n);% 将输入数据分成0.1ms的多个数据块
wfc = 2*pi*fc;  %本地信号
phi_prv = 0;
temp = 0;
frame = 0;
carrier_phase = 0;
phase = 0;

%环路滤波器的参数
K=1e4;
k1=32e3;
bl=0.0001*K;
w=bl/0.53;
T=1/K;
k0=2*pi*T*fs/2^32;
% k0=1;
% c1=2*0.707*w*T/k0;
% c2=(w*T)^2/k0;
c1=1203.9;
c2=16.22; 
% c1=18237;
% c2=2433.48;  
%  c1=10;
%  c2=5;
%数据率为4kbps,1bit数据采样点数为12.5K，每5K个点累加一次，相当于4个数据累加清零一次，
%w=0.01*4K,T=1/4K,k0=2*pi*T*fs/2^32,c1=2*0.707*w*T/k0,c2=(wT)^2/k0,

for frame=1:nf 
% 产生本地的sin和cos函数
expcol = exp(j*(wfc*ts*nn+phase));
sine = imag(expcol);   
cosine = real(expcol);

x = data((1:n)+((frame-1)*n));
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
dphase_frame(frame) = phase; 
end

plot(dfrq_frame/(2*pi));
hold on
figure;
plot([1:length(dfrq_frame)], real_fc,'r');
% legend('锁相环跟踪','实际的载波频率');
grid
mean_freq=mean(dfrq_frame/2/pi)
p=abs(real_fc-mean_freq)/real_fc;