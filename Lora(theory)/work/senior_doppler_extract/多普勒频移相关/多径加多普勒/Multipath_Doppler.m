SF=7;
M=2^SF;
% aa=randi([0 M-1]);
a=M/2;
k=0:1:M-1;
epsilon=[0.8 0.6 0.2 0.5];
ui=[0 10 50 100];%时延
% hi=[sqrt(0.8) sqrt(0.2)];
hi=[1 1 1 1];%信道增益
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
rkm=zeros(1,M);
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(1)/M));%直达径信号
% xk=awgn(xk,-5);

%多径
for i=2:length(ui)
    xkm=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(i)/M));
    xk_tem=[zeros(1,ui(i)) xkm(1:M-ui(i))];
    rkm=rkm+xk_tem;
end
rk=hi(1)*xk+hi(2)*rkm;
Yq=abs(fft(rk.*xk0)/M);
figure;
stem(0:M-1,Yq,'Marker','none','Linewidth',1.5);hold on;
ylim([0 1]);xlim([0 M-1])
Yq_2=fft(xk_tem.*xk0);

%% 公式推导
Es=1;
Yq_t=zeros(1,M);
for q=0:1:M-1
    for i=1:length(ui)
        Yq_tem1=sin(pi*(1-ui(i)/M)*(q-a-epsilon(i)+ui(i)));
        Yq_tem2=sin(pi*(1/M)*(q-a-epsilon(i)+ui(i)));
        Yq_t_tem=(Yq_tem1/Yq_tem2)*exp(-1j*pi*(q*(1+ui(i)/M-1/M)+(a+epsilon(i))*(-1+ui(i)/M+1/M)-ui(i)/M));
        Yq_t(q+1)=Yq_t(q+1)+hi(i)*Yq_t_tem;
    end
end
for i=1:length(ui)
    if mod(epsilon(i),1)==0
       Yq_t(a+epsilon(i)-ui(i)+1)=0;
    end
end
for i=1:length(ui)
    if mod(epsilon(i),1)==0
       Yq_t(a+epsilon(i)-ui(i)+1)=Yq_t(a+epsilon(i)-ui(i)+1)+hi(i)*M-ui(i);
    end
end


Yq_t=abs(Yq_t)*Es/M;
stem(0:M-1,Yq_t,'Marker','none','LineStyle','--','LineWidth',1.5);
xlabel('Frequency bin, q');ylabel('|Y_q|/M');
% legend(['Yq,ui=' num2str(ui(2)) ',ε=' num2str(epsilon(2)) ',simu'],['Yq,ui=' num2str(ui(2)) ',ε=' num2str(epsilon(2)) ',theo']);
% legend(['Yq,ui=' num2str(ui(2)) ',ε0=' num2str(epsilon(1)) ',ε1=' num2str(epsilon(2)) ',simu'],['Yq,ui=' num2str(ui(2)) ',ε0=' num2str(epsilon(1)) ',ε1=' num2str(epsilon(2)) ',theo']);
legend(['Yq,ui=' num2str(ui) ',ε=' num2str(epsilon) ',simu'],['Yq,ui=' num2str(ui) ',ε=' num2str(epsilon) ',theo']);
grid on;
% figure;
% plot(0:M-1,Yq);hold on
% plot(0:M-1,Yq_t,'r--','Linewidth',1);
% xlim([0 M-1]);ylim([0 1]);
% xlabel('Frequency bin, q');ylabel('|Y_q|/M');
% legend(['Yq,ui=' num2str(ui(2)) ',ε=' num2str(epsilon(2)) ',simu'],['Yq,ui=' num2str(ui(2)) ',ε=' num2str(epsilon(2)) ',theo']);


