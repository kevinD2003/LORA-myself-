%% 多径+多普勒的帧结构形式的LoRa通信计算理论误码率；
%% 时延应保证在一个符号周期内，即 0<ui<M
%% LoRa通信参数
B=250e3;
SF=10;
M=2^SF;
%% 信道参数
load('6path.mat');
%% num径信道(包含主径)
num = 6;
hi = g(1:num) / g(1);
epsilon = fd(1:num) * M / B;
ui=ceil(tau(1:num) * B);

%% 
SNR=-25:1:30;
BER_LoRa_Frame_Approx=zeros(1,length(SNR));

%% 计算理论误码率
a = M / 2;
Aq_ncoh=getAq(a,SF,epsilon,ui,hi);%计算主径及联合干扰
Aq=Aq_ncoh(a+1)/M;
% Aq=sin(pi*epsilon(1))/sin(pi*epsilon(1)/M)*exp(1j*pi*(1-1/M))/M;
Aq=abs(Aq);
Aq_ncoh(a+1)=0;
Aq_ncoh=sort(Aq_ncoh,'descend')/M;
for i=1:1:length(SNR)
    SNR_dB=10^(SNR(i)/10);
    N_SI=getN(SF,Aq_ncoh,SNR_dB);
    nsi(1,i)=N_SI;%%%%%%%%%%%%%%%%%%%%%%%
    H=harmonic(M-N_SI-1);%调和数
    %噪声引起的误码率
    Pe_N=qfunc(Aq*sqrt(2*SNR_dB*M)-sqrt(2*H));
    %联合干扰引起的误码率
    Pe_I=1;
    for k=1:N_SI
        Pe_I=Pe_I*(1-qfunc((Aq-Aq_ncoh(k))*sqrt(SNR_dB*M)));
    end
    %总误码率
    BER_LoRa_Frame_Approx(1,i)=0.5*(1- (1-Pe_N)*Pe_I);
end 

%% 画图
figure;
semilogy(SNR,BER_LoRa_Frame_Approx(1,:),'r--*');hold on;%
% xlabel('SNR(dB)','FontName','Times New Roman','FontSize',12);
% ylabel('$BER$','FontName','Times New Roman','Interpreter','latex','FontSize',12);grid on;
xlabel('SNR (dB)');ylabel('BER')
ylim([10^-6 1]);
legend( 'LoRa, Approx');
grid on

%%
function [Aq_ncoh]=getAq(a,SF,epsilon,ui,hi)
%获得理论叠加的多径在解调域上形成的幅值
M=2^SF;
%% 公式推导--理论幅值计算
Es=1;
%% 后半段的干扰
q = 0 : M-1;
%% 主径信号 
Yq_dp = sin(pi*(1-ui(1)/M)*(q-a-epsilon(1)+ui(1)))./sin(pi*(1/M)*(q-a-epsilon(1)+ui(1)));
Yq_dp = hi(1) * Yq_dp .* exp(-1j*pi*(q*(1+ui(1)/M-1/M)+(a+epsilon(1))*(-1+ui(1)/M+1/M)-ui(1)/M));

%% 后半部分
Yq_suc = zeros(1,M);
for i = 2 : length(ui)
    Yq_t_tmp = sin(pi*(1-ui(i)/M)*(q-a-epsilon(i)+ui(i)))./sin(pi*(1/M)*(q-a-epsilon(i)+ui(i)));
%     Yq_t_tmp =Yq_t_tmp .* exp(-1j*pi*(q*(1+ui(i)/M-1/M)+(a+epsilon(i))*(-1+ui(i)/M+1/M)-ui(i)/M));
Yq_t_tmp =Yq_t_tmp .* exp(-1j*pi*((q-epsilon(i))*(1+ui(i)/M-1/M)+(a)*(-1+ui(i)/M+1/M)-ui(i)/M));
    Yq_suc = Yq_suc + hi(i) * Yq_t_tmp;
end
% %% 残缺部分（为能处理epsilon为整数的情况）
% for i=1:length(ui)
%     if mod(epsilon(i),1)==0
%        Yq_suc(a+epsilon(i)-ui(i)+1)=0;
%     end
% end
% for i=1:length(ui)
%     if mod(epsilon(i),1)==0
%        Yq_suc(a+epsilon(i)-ui(i)+1)=Yq_suc(a+epsilon(i)-ui(i)+1)+hi(i)*M-ui(i);
%     end
% end
%% 前半段干扰
q = 0 : M - 1;
Yq_pre = zeros(1,M);
for i =2 : length(ui)
    Yq_pre_tmp = sin(pi*ui(i).*(q-epsilon(i)-M+ui(i))/M)./sin(pi.*(q-epsilon(i)-M+ui(i))/M);
%     Yq_pre_tmp = Yq_pre_tmp.*exp(-1j*pi*(q.*(ui(i)-1)+epsilon(i)*(ui(i)+1-2*M)+M-ui(i))/M);
    Yq_pre_tmp = Yq_pre_tmp.*exp(-1j*pi*((q-epsilon(i))*(ui(i)-1)+0*(ui(i)+1-2*M)+M-ui(i))/M);
    Yq_pre = Yq_pre +hi(i) * Yq_pre_tmp;
end

%%
Yq_Theo=abs(Yq_dp + Yq_suc + Yq_pre)*Es;
Aq_ncoh=Yq_Theo;
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