%% 补偿法，采用频移的方式（将小数倍的频移补全至整数倍）。
%% 小数部分CFO的估计与补偿。
%% 瑞利衰落+多普勒
%% Monte Carlo实验 CFO。
SF=12;
M = 2^SF;
SNR=-25:1:20;
% SNR=-20;
epsilon=0.8;
BER_FD_Shift=zeros(1,length(SNR));
times=[1000*ones(1,6) 10000*ones(1,11) 100000*ones(1,9) 1000000*ones(1,11) 10000000*ones(1,11)];
tic;
h=waitbar(0,['SF=' num2str(SF) ',\eta=' num2str(epsilon)]);
for j=1:length(SNR)
    error=0;
    for jjj=1:times(j)
        [error1]=FD_Shift(SF,epsilon,SNR(j));
        error=error+error1;
    end
    BER_FD_Shift(j)=error/times(j)/2;
    if(BER_FD_Shift(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['SNR= ' num2str(SNR(j))]);
end
toc;
close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
c =['r';'y';'g';'c';'m'];
figure;
% for f=1:length(epsilon)
% % semilogy(SNR,BER_LoRa(f,:),'LineWidth',1,'Color','b','LineStyle','-','Marker',m(f));hold on
% semilogy(SNR,BER_FD_Shift(f,:),'Color',c(f),'LineStyle','-','Marker',m(f));hold on
% end
semilogy(SNR,BER_FD_Shift,'Color','r','LineStyle','-','Marker','o');
xlabel('SNR');ylabel('BER');
% legend("FSEC one preamble");%采用一个前导码
grid on;

%% 
function [error1]=FD_Shift(SF,epsilon,SNR)
M=2^SF;
aa=randi([0 M-1]);
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(1)/M));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(1)/M));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];

%% 手动添加高斯噪声
sigPower=sum(abs(Sd.*Sd))/length(Sd);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(Sd))+1j*randn(1,length(Sd)));
%% 瑞利信道（Rayleigh Fading）
omega = 1;
h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
rk1=h_rayleigh*Sd+noise;


xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);

r_preamble_ave=zeros(1,M);
% for o=1:8
%     r_preamble=rk1((o-1)*M+1:o*M);
%     r_preamble_ave=r_preamble_ave+r_preamble;
% 
% end
% r_preamble_ave=r_preamble_ave/8;

%只用num个前导码
num=8;
for o=1:num
    r_preamble=rk1((o-1)*M+1:o*M);
    r_preamble_ave=r_preamble_ave+r_preamble;

end
r_preamble_ave=r_preamble_ave/num;

eta_fraction=(0:0.1:1);
Yq_max=zeros(1,length(eta_fraction));
for i=1:length(eta_fraction)
    y_preamble_tem=abs(fft(r_preamble_ave.*exp(1j*2*pi*k*eta_fraction(i)/M).*xk0));
    Yq_max(i)=max(y_preamble_tem);
end
[~,eta_fraction_estimation]=max(Yq_max);
eta_fraction_estimation=eta_fraction(eta_fraction_estimation);%(eta_fraction_estimation-1)/10;
r_preamble_fc=r_preamble_ave.*exp(1j*2*pi*k*eta_fraction_estimation/M);
y_preamble_fc=abs(fft(r_preamble_fc.*xk0))/M;
% [~,eta_integer_estimation]=max(y_preamble_fc);
[~,epsilon_integer_estimation]=max(y_preamble_fc);
o=8;%
y_payload=abs(fft(rk1(o*M+1:end).*xk0.*exp(1j*2*pi*k*(-epsilon_integer_estimation+eta_fraction_estimation+1)/M)))/M;
[~,d]=max(abs(y_payload));
if d-1==aa
    error1=0;
else
    error1=1;

end

end
