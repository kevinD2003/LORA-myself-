%% LoRa的时频图
B=125e3;
SF=7;
M=2^SF;
Ts=M/B;
% a=4*M/7;
a =M/4;% M / 2;
ta=Ts*(1-a/M);
t=0:1/B:Ts;
% f=a*B/M-B/2+B*t/Ts-B*stepfun(t,ta);
f=a*B/M-B/2+B*t/Ts-B*(t>ta);
figure;
plot(t,f,'LineWidth',2);hold on
ylim([-62501 62501]);
xlim([0 Ts+1/10*Ts])
set(gca,'XAxisLocation','origin')
xlabel('t');
ylabel('f')
xticks([0 Ts/2 Ts])
xticklabels({'0','Ts/2','Ts'})
yticks([-1/2*B 0 1/2*B])
yticklabels({'-B/2','0','B/2'})


%% LoRa调制解调
k = 0 : M - 1;
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M));%直达径信号
% rk=awgn(xk,-6,"measured");
rk = xk;
Yq_DNC=abs(fft(rk.*xk0)/M);%非相干解调
Yq_NC=real(fft(rk.*xk0)/M);%相干解调
figure;
plot(0:M-1,Yq_DNC);xlabel('q');ylabel('|Yq|/M');
% xlim([0 M - 1]);ylim([0 1]);
