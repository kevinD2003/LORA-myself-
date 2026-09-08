%% 非相干解调理论误码率曲线
%% 固定SNR
%%
B=500e3;
SF=11;%扩展因子
SNR=-15;
% BER=zeros(1,length(SNR));
% nsi=zeros(1,length(fd));%%%%%%%%%%%%%%%%%%%计算干扰集内元素个数；
%% 理论误码率公式
M=2^SF;
delta_f=B/M;
fd=[0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]*B/M;
BER=zeros(1,length(fd));
% fd=97.6;
for i=1:1:length(fd)
epsilon=fd(i)/delta_f;
if mod(epsilon,1)==0
    if abs(epsilon)<1
        Aq=M;
    else
        Aq=0;
    end
else
    Aq=abs(sin(pi*epsilon)/sin(pi*epsilon/M));
end
Aq_ncoh=getAq(SF,epsilon);
A=Aq_ncoh;
Aq_ncoh=sort(Aq_ncoh,'descend');
% H=harmonic(M-2);%调和数
SNR_dB=10^(SNR/10);
N_SI=getN(SF,Aq_ncoh,SNR_dB);
nsi(1,i)=N_SI;%%%%%%%%%%%%%%%%%%%%%%%
H=harmonic(M-N_SI-1);%调和数
%噪声引起的误码率
Pe_N=qfunc(Aq*sqrt(2*SNR_dB/M)-sqrt(2*H));
%多径引起的误码率
Pe_I=1;
for k=1:N_SI
    Pe_I=Pe_I*(1-qfunc((Aq-Aq_ncoh(k))*sqrt(SNR_dB/M)));
end
%总误码率
BER(1,i)=0.5*(1- (1-Pe_N)*Pe_I);
end 
% figure; 
semilogy(0:0.1:1,BER(1,:),'k--*');hold on;
% semilogy(SNR,BER(1,:),'-*','Color',[0.58 0 0.82]);hold on;
xlabel('ε','FontName','Times New Roman','FontSize',12);
ylabel('$BER$','FontName','Times New Roman','Interpreter','latex','FontSize',12);grid on;
ylim([10^-6 1]);xlim([0 1]);
% legend(['$L=' num2str(L) ',ncoh,Approx$'],'FontName','Times New Roman','Interpreter','latex','FontSize',8);

% % figure;
% plot(SNR,nsi,'y-v');hold on
%%
function [Aq_ncoh]=getAq(SF,epsilon)
%获得理论叠加的多径在解调域上形成的幅值
M=2^SF;
aa=M/2;
Aq_ncoh=zeros(1,M);
% q=0:1:M-1;
for q=1:1:M
   Dq_ncoh_tem=sin(pi*(q-aa-epsilon))/sin(pi*(q-aa-epsilon)/M);
   Aq_ncoh(q)=abs(Dq_ncoh_tem);
end

if mod(epsilon,1)==0
    if abs(epsilon)<1
        Aq_ncoh(aa)=0;
    else
        Aq_ncoh(aa+epsilon)=M;
    end
else
    Aq_ncoh(aa)=0;
end

end

%% 获取干扰集的个数
function N=getN(SF,Aq_ncoh,SNR_dB)
M=2^SF;
N=0;
for i=1:M
    Aq_ncoh_tem=SNR_dB*(Aq_ncoh(i))^2/(M);
    if 10*log10(Aq_ncoh_tem)>=1.3
        N=N+1;
    end
end

end
