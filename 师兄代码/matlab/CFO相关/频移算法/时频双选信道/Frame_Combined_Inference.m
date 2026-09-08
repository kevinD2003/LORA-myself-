%% 以帧结构传输的LoRa信号的解调域信号表达式推导
%% 帧结构的LoRa信号数据块部分的干扰计算（对于数据块来说干扰覆盖整个符号周期，即前半部分来自多径的前导码后半部分来自多径的数据块）
SF=7;
M=2^SF;
a=60;
k=0:1:M-1;
% epsilon=[0.8 0.6 0.4 0.5];
% ui=[0 10 50 100];%时延
% hi=[1 1 1 1];%信道增益
% epsilon=0.8;
% ui=0;
% hi=1;
epsilon=[0 0 0 0];
ui=[0 10 50 100];%时延
hi=[1 1 1 1];%信道增益
b=0;%表示前导码
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(1)/M));%直达径信号
xk_pr=exp(1j*2*pi*k.*(b/M-1/2+k/2/M+epsilon(1)/M));%LoRa基信号
N_preamble = 8;
xk_preamble = zeros(1, N_preamble * M);
for o = 1 : N_preamble
    xk_preamble((N_preamble-1)*M+1 : N_preamble*M)=xk_pr;
end
%% 组帧
xk_frame = [xk_preamble xk];

% xk=awgn(xk,-5);

%% 多径
rk_mul = zeros(1, length(xk_frame));
rk_mul_preamble = zeros(1, N_preamble * M);
In_pre = zeros(1, M);%%
for i=2:length(ui)
%     xkm=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(i)/M));
%     xk_mul_pr = exp(1j*2*pi*k.*(b/M-1/2+k/2/M+epsilon(i)/M));
    xkm=exp(1j*2*pi*k.*(a/M-1/2+k/2/M));
    xk_mul_pr = exp(1j*2*pi*k.*(b/M-1/2+k/2/M));
    for o = 1 : N_preamble
        rk_mul_preamble((N_preamble-1)*M+1 : N_preamble*M)=xk_mul_pr;
    end
    %% 组帧
    rk_mul_tmp = [rk_mul_preamble xkm];
    rk_mul_tmp=[zeros(1,ui(i)) rk_mul_tmp(1:end-ui(i))];%%
    for o = 1 : N_preamble+1
        rk_mul_tmp((o-1)*M+1:o*M)=rk_mul_tmp((o-1)*M+1:o*M).*exp(1j*2*pi*k.*epsilon(i)/M);
    end
    rk_mul = rk_mul + hi(i) * rk_mul_tmp;
end
% rk=hi(1)*xk+hi(2)*rkm;
rk = hi(1) * xk_frame + rk_mul;
payload = rk(N_preamble*M+1 : end);
Yq=abs(fft(payload.*xk0)/M);
% figure;
subplot(4,1,2)
stem(0:M-1,Yq,'Marker','none','Linewidth',1.5);hold on;
ylim([0 1]);xlim([0 M-1])
% Yq_2=fft(xk_tem.*xk0);

%% 公式推导
Es=1;
%% 后半段的干扰
q = 0 : M-1;
%% 主径信号 
Yq_dp = sin(pi*(1-ui(1)/M)*(q-a-epsilon(1)+ui(1)))./sin(pi*(1/M)*(q-a-epsilon(1)+ui(1)));
Yq_dp = hi(1) * Yq_dp .* exp(-1j*pi*(q*(1+ui(1)/M-1/M)+(a+epsilon(1))*(-1+ui(1)/M+1/M)-ui(1)/M));
Yq_t = zeros(1,M);
%% 后半部分
for i = 2 : length(ui)
    Yq_t_tmp = sin(pi*(1-ui(i)/M)*(q-a-epsilon(i)+ui(i)))./sin(pi*(1/M)*(q-a-epsilon(i)+ui(i)));
%     Yq_t_tmp =Yq_t_tmp .* exp(-1j*pi*(q*(1+ui(i)/M-1/M)+(a+epsilon(i))*(-1+ui(i)/M+1/M)-ui(i)/M));
    Yq_t_tmp =Yq_t_tmp .* exp(-1j*pi*((q-epsilon(i))*(1+ui(i)/M-1/M)+(a)*(-1+ui(i)/M+1/M)-ui(i)/M));
    Yq_t = Yq_t + hi(i) * Yq_t_tmp;
end
%% 前半段干扰
q = 0 : M - 1;
Yq_pre = zeros(1,M);
for i =2 : length(ui)
    Yq_pre_tmp = sin(pi*ui(i).*(q-b-epsilon(i)-M+ui(i))/M)./sin(pi.*(q-b-epsilon(i)-M+ui(i))/M);
%     Yq_pre_tmp = Yq_pre_tmp.*exp(-1j*pi*(q.*(ui(i)-1)+(epsilon(i)+b)*(ui(i)+1-2*M)+M-ui(i))/M);
    Yq_pre_tmp = Yq_pre_tmp.*exp(-1j*pi*((q-epsilon(i))*(ui(i)-1)+(b)*(ui(i)+1-2*M)+M-ui(i))/M);
    Yq_pre = Yq_pre +hi(i) * Yq_pre_tmp;
end
%%
Yq_t=abs(Yq_dp + Yq_t + Yq_pre)*Es/M;
stem(0:M-1,Yq,'Marker','none','LineStyle','--','LineWidth',1.5);
xlabel('Frequency bin, q');ylabel('|Y_q|/M');hold on
% title('a=M/2, b=100')
title("With CFO interference and without multipath interference")
% title("Without CFO interference and with multipath interference");
% title(" With both CFO interference and multipath interference (a=60, b=0)")
% legend(['Yq,ui=' num2str(ui) ',ε=' num2str(epsilon) ',simu'],['Yq,ui=' num2str(ui) ',ε=' num2str(epsilon) ',theo']);
legend('simu','Theo')
grid on;


