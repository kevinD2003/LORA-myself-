%% 非相干解调理论误码率曲线 采用闭式解的噪声驱动的SER与自己的干扰驱动的SER
%%
B=250e3;
SF=10;%扩展因子
SNR=-25:10;
SNR_PLOT=SNR;
BER=zeros(1,length(SNR));
nsi=zeros(1,length(SNR));%%%%%%%%%%%%%%%%%%%计算干扰集内元素个数；
%% 理论误码率公式
M=2^SF;
a=M/2;
epsilon=[0.3 0.3 ];
ui=[0 10];
hi=[sqrt(0.8) sqrt(0.2)]/sqrt(0.8);%先衰减再加噪
% hi=[sqrt(0.8) sqrt(0.2)];%先加噪在衰减
Aq_ncoh=getAq(a,SF,epsilon,ui,hi);
Aq=Aq_ncoh(a+1)/M;
Aq_ncoh(a+1)=0;
Aq_ncoh=sort(Aq_ncoh,'descend')/M;
% H=harmonic(M-2);%调和数
for i=1:1:length(SNR)
    SNR_dB=10^(SNR(i)/10);
    N_SI=getN(SF,Aq_ncoh,SNR_dB);
    nsi(1,i)=N_SI;%%%%%%%%%%%%%%%%%%%%%%%
    H=harmonic(M-N_SI-1);%调和数
    %噪声引起的误码率
    Pe_N=qfunc((sqrt(SNR_dB*M*Aq)-(H^2-pi^2/12)^(1/4))/sqrt(H-(H^2-pi^2/12)^(1/2)+0.5));
    %多径引起的误码率
    Pe_I=1;
    for k=1:N_SI
        Pe_I=Pe_I*(1-qfunc((Aq-Aq_ncoh(k))*sqrt(SNR_dB*M)));
    end
    %总误码率
    BER(1,i)=0.5*(1- (1-Pe_N)*Pe_I);
end 
figure; 
% semilogy(SNR,BER(1,:),'r--*');hold on;%
semilogy(SNR_PLOT,BER(1,:),'r--*');hold on;%
% semilogy(SNR,BER(1,:),'-*','Color',[0.58 0 0.82]);hold on;
xlabel('SNR(dB)','FontName','Times New Roman','FontSize',12);
ylabel('$BER$','FontName','Times New Roman','Interpreter','latex','FontSize',12);grid on;
ylim([10^-6 1]);xlim([-25 35]);
% legend(['$L=' num2str(L) ',ncoh,Approx$'],'FontName','Times New Roman','Interpreter','latex','FontSize',8);
legend(['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',ε=' num2str(epsilon(2))]);
% figure;
% plot(SNR,nsi,'y-v');hold on
%%
function [Aq_ncoh]=getAq(a,SF,epsilon,ui,hi)
%获得理论叠加的多径在解调域上形成的幅值
M=2^SF;
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
       Yq_t(a+epsilon(i)-ui(i)+1)=Yq_t(a+epsilon(i)-ui(i)+1)+hi(i)*(M-ui(i));
    end
end
Aq_ncoh=abs(Yq_t);
% figure;
% plot(0:M-1,Aq_ncoh/M);
end

%% 获取干扰集的个数
function N=getN(SF,Aq_ncoh,SNR_dB)
M=2^SF;
N=0;
for i=1:M
    Aq_ncoh_tem=SNR_dB*(Aq_ncoh(i))^2*M;
    if 10*log10(Aq_ncoh_tem)>=1.3
        N=N+1;
    end
end

end



%% 

% Yq_t=zeros(1,M);
% for q=0:1:M-1
%     for i=1:length(ui)
%         Yq_tem1=sin(pi*(1-ui(i)/M)*(q-a-epsilon(i)+ui(i)));
%         Yq_tem2=sin(pi*(1/M)*(q-a-epsilon(i)+ui(i)));
%         Yq_t_tem=(Yq_tem1/Yq_tem2)*exp(-1j*pi*(q*(1+ui(i)/M-1/M)+(a+epsilon(i))*(-1+ui(i)/M+1/M)-ui(i)/M));
%         Yq_t(q+1)=Yq_t(q+1)+Yq_t_tem;
%     end
% end
% for i=1:length(ui)
%     if mod(epsilon(i),1)==0
%        Yq_t(a+epsilon(i)-ui(i)+1)=0;
%     end
% end
% for i=1:length(ui)
%     if mod(epsilon(i),1)==0
%        Yq_t(a+epsilon(i)-ui(i)+1)=Yq_t(a+epsilon(i)-ui(i)+1)+M-ui(i);
%     end
% end