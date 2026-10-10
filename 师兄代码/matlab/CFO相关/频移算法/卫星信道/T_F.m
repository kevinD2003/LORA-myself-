%% LoRa的时频图
B=125e3;
SF=12;
M=2^SF;
Ts=M/B;
% a=4*M/7;
a =0;% M / 2;
ta=Ts*(1-a/M);
t=0:1/B:Ts;
% f=a*B/M-B/2+B*t/Ts-B*stepfun(t,ta);
f=a*B/M-B/2+B*t/Ts-B*(t>ta);
figure;
plot(t,f,'LineWidth',1);hold on
ylim([-62500 62500]);
xlim([0 Ts-1/B])
set(gca,'XAxisLocation','origin')
xlabel('t');ylabel('f')
xticks([0 Ts/2 Ts])
xticklabels({'0','Ts/2','Ts'})
yticks([-1/2*B 0 1/2*B])
yticklabels({'-B/2','0','B/2'})
% f1=f;
% for i = 1:M
%     f1(i)=f(i)+DopplerShift(ceil(i/128));
% end
% plot(t,f1,'LineWidth',1,'LineStyle','-.');hold on
% legend
% %% LoRa调制解调
% k = 0 : M - 1;
% xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
% xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M));%直达径信号
% % rk=awgn(xk,-6,"measured");
% rk = xk;
% Yq_DNC=abs(fft(rk.*xk0)/M);%非相干解调
% Yq_NC=real(fft(rk.*xk0)/M);%相干解调
% figure;
% plot(0:M-1,Yq_DNC);xlabel('q');ylabel('|Yq|/M');xlim([0 M - 1]);ylim([0 1]);
% xk1 = [zeros(1,20) xk(1:108)];
% Yq1_DNC=abs(fft(xk1.*xk0)/M);%非相干解调
% figure;plot(0:M-1,Yq1_DNC);xlabel('q');ylabel('|Yq1|/M');xlim([0 M - 1]);ylim([0 1]);
% 
% xk11 = [xk(109:end) zeros(1,108)];
% Yq11_DNC=abs(fft(xk11.*xk0)/M);%非相干解调
% figure;plot(0:M-1,Yq11_DNC);xlabel('q');ylabel('|Yq11|/M');xlim([0 M - 1]);ylim([0 1]);
% 
% xk2 = [zeros(1,38) xk(1:90)];
% Yq2_DNC=abs(fft(xk2.*xk0)/M);%非相干解调
% figure;plot(0:M-1,Yq2_DNC);xlabel('q');ylabel('|Yq2|/M');xlim([0 M - 1]);ylim([0 1]);
% xk3 = [zeros(1,50) xk(1:78)];
% Yq3_DNC=abs(fft(xk3.*xk0)/M);%非相干解调
% figure;plot(0:M-1,Yq3_DNC);xlabel('q');ylabel('|Yq3|/M');xlim([0 M - 1]);ylim([0 1]);
% % subplot(2,1,1);
% % plot(0:M-1,Yq_DNC);
% % title("非相干解调");
% % xlabel('q');ylabel('|Yq|/M');xlim([0 M - 1]);
% % subplot(2,1,2);
% % plot(0:M-1,Yq_NC);
% % title("相干解调");
% % xlabel('q');ylabel('real(Yq)/M');xlim([0 M - 1]);