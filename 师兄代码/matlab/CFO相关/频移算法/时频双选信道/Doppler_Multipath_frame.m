%% 帧结构的LoRa信号数据块部分的干扰计算（对于数据块来说干扰覆盖整个符号周期，即前半部分来自多径的前导码后半部分来自多径的数据块）
SF=7;
M=2^SF;
a=60;
k=0:1:M-1;
epsilon=[0.8 0.6 0.2 0.5];
ui=[0 10 50 100];%时延
hi=[1 1 1 1];%信道增益
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(1)/M));%直达径信号
xk_pr=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(1)/M));%LoRa基信号
N_preamble = 8;
xk_preamble = zeros(1, N_preamble * M);
for o = 1 : N_preamble
    xk_preamble((N_preamble-1)*M+1 : N_preamble*M)=xk_pr;
end
%% 组帧
xk_frame = [xk_preamble xk];
%% 多径
rk_mul = zeros(1, length(xk_frame));
rk_mul_preamble = zeros(1, N_preamble * M);
In_pre = zeros(1, M);%%
for i=2:length(ui)
    xkm=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+epsilon(i)/M));
    xk_mul_pr = exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(i)/M));
    for o = 1 : N_preamble
        rk_mul_preamble((N_preamble-1)*M+1 : N_preamble*M)=xk_mul_pr;
    end
    %% 组帧
    rk_mul_tmp = [rk_mul_preamble xkm];
    rk_mul_tmp=[zeros(1,ui(i)) rk_mul_tmp(1:end-ui(i))];%%
    rk_mul = rk_mul + hi(i) * rk_mul_tmp;
end
rk = hi(1) * xk_frame + rk_mul;
payload = rk(N_preamble*M+1 : end);
Yq=abs(fft(payload.*xk0)/M);
figure;
stem(0:M-1,Yq,'Marker','none','Linewidth',1.5);hold on;
ylim([0 1]);xlim([0 M-1])

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
    Yq_t_tmp =Yq_t_tmp .* exp(-1j*pi*(q*(1+ui(i)/M-1/M)+(a+epsilon(i))*(-1+ui(i)/M+1/M)-ui(i)/M));
    Yq_suc = Yq_suc + hi(i) * Yq_t_tmp;
end
for i=1:length(ui)
    if mod(epsilon(i),1)==0
       Yq_suc(a+epsilon(i)-ui(i)+1)=0;
    end
end
for i=1:length(ui)
    if mod(epsilon(i),1)==0
       Yq_suc(a+epsilon(i)-ui(i)+1)=Yq_suc(a+epsilon(i)-ui(i)+1)+hi(i)*M-ui(i);
    end
end
%% 前半段干扰
q = 0 : M - 1;
Yq_pre = zeros(1,M);
for i =2 : length(ui)
    Yq_pre_tmp = sin(pi*ui(i).*(q-epsilon(i)-M+ui(i))/M)./sin(pi.*(q-epsilon(i)-M+ui(i))/M);
    Yq_pre_tmp = Yq_pre_tmp.*exp(-1j*pi*(q.*(ui(i)-1)+epsilon(i)*(ui(i)+1-2*M)+M-ui(i))/M);
    Yq_pre = Yq_pre +hi(i) * Yq_pre_tmp;
end

%%
Yq_Theo=abs(Yq_dp + Yq_suc + Yq_pre)*Es/M;
stem(0:M-1,Yq_Theo,'Marker','none','LineStyle','--','LineWidth',1.5);
xlabel('Frequency bin, q');ylabel('|Y_q|/M');
legend(['Yq,ui=' num2str(ui) ',ε=' num2str(epsilon) ',simu'],['Yq,ui=' num2str(ui) ',ε=' num2str(epsilon) ',theo']);
grid on;

