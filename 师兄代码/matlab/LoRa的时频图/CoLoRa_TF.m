%% LoRa的时频图
B=125e3;
SF=7;
M=2^SF;
Ts=M/B;
a = 0;
ta=Ts*(1-a/M);
t=0:1/B:Ts;
f1=a*B/M-B/2+B*t/Ts-B*(t>ta);
figure;
plot(t,f1,'LineWidth',2);hold on
ylim([-62500 62500]);
xlim([0 1.1*Ts])
set(gca,'XAxisLocation','origin')
xlabel('t');ylabel('f')
xticks([0 Ts/2 Ts])
xticklabels({'0','Ts/2','Ts'})
yticks([-1/2*B 0 1/2*B])
yticklabels({'-B/2','0','B/2'})

a2 = M / 2;
ta2=Ts*(1-a2/M);
f2=a2*B/M-B/2+B*t/Ts-B*(t>ta2);
figure;
plot(t,f2,'LineWidth',2);hold on
ylim([-62500 62500]);
xlim([0 1.1*Ts])
set(gca,'XAxisLocation','origin')
xlabel('t');ylabel('f')
xticks([0 Ts/2 Ts])
xticklabels({'0','Ts/2','Ts'})
yticks([-1/2*B 0 1/2*B])
yticklabels({'-B/2','0','B/2'})


