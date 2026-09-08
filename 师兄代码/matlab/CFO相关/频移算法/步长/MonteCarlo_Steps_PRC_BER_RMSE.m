%% Monte Carlo实验，多普勒-高斯信道
%% 目的：寻找最合适的step
SF=7;
M = 2^SF;
% SNR=-25:1:-20;
SNR=-15:0;
% SNR=-22;
BER_step1=zeros(1,length(SNR));
BER_step2=zeros(1,length(SNR));
BER_step3=zeros(1,length(SNR));
BER_step4=zeros(1,length(SNR));
BER_step5=zeros(1,length(SNR));
RMSE_step1=zeros(1,length(SNR));
RMSE_step2=zeros(1,length(SNR));
RMSE_step3=zeros(1,length(SNR));
RMSE_step4=zeros(1,length(SNR));
RMSE_step5=zeros(1,length(SNR));
epsilon=0.8;
N_upchirp=8;
N_payload=1;
% times=[1000000*ones(1,length(SNR)-1) 5000000];
times=10000000;
tic;
h=waitbar(0,['SF=' num2str(SF) ',计算中']);
% close(h);
%% methods
for j=1:length(SNR)
    error_step1=0;
    error_step2=0;
    error_step3=0;
    error_step4=0;
    error_step5=0;
    rmse_step1=0;
    rmse_step2=0;
    rmse_step3=0;
    rmse_step4=0;
    rmse_step5=0;
    for jj = 1 : times
        epsilon=rand();%epsilon在0-1中随机
        [error1,error2,error3,error4,error5,rmse1,rmse2,rmse3,rmse4,rmse5]=step_EC(SF,epsilon,SNR(j),N_payload,N_upchirp);
        error_step1=error_step1+error1;
        error_step2=error_step2+error2;
        error_step3=error_step3+error3;
        error_step4=error_step4+error4;
        error_step5=error_step5+error5;
        rmse_step1=rmse_step1+rmse1;
        rmse_step2=rmse_step2+rmse2;
        rmse_step3=rmse_step3+rmse3;
        rmse_step4=rmse_step4+rmse4;
        rmse_step5=rmse_step5+rmse5;
    end
    BER_step1(j)=error_step1/(times*N_payload)/2;
    BER_step2(j)=error_step2/(times*N_payload)/2;
    BER_step3(j)=error_step3/(times*N_payload)/2;
    BER_step4(j)=error_step4/(times*N_payload)/2;
    BER_step5(j)=error_step5/(times*N_payload)/2;
    RMSE_step1(j)=sqrt(rmse_step1/(times));
    RMSE_step2(j)=sqrt(rmse_step2/(times));
    RMSE_step3(j)=sqrt(rmse_step3/(times));
    RMSE_step4(j)=sqrt(rmse_step4/(times));
    RMSE_step5(j)=sqrt(rmse_step5/(times));
    % if(BER_PRC(j)<1E-6 && BER_EC(j)<1E-6)
    %     break;
    % end
    waitbar(j/length(SNR),h,['methods, SNR= ' num2str(SNR(j))]);
end
close(h);
toc;
% close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
c =['r';'y';'g';'c';'m'];
figure;
semilogy(SNR,BER_step1,'LineStyle','-','Marker','o');hold on
semilogy(SNR,BER_step2,'LineStyle','--','Marker','o');hold on;
semilogy(SNR,BER_step3,'LineStyle',':','Marker','o');hold on;
semilogy(SNR,BER_step4,'LineStyle','-.','Marker','o');hold on;
semilogy(SNR,BER_step5,'LineStyle','-','Marker','o');hold on;
%title(['TQ28 Satellite Channel, SF = ' num2str(SF) ', B = 125kHz']);
legend('step=0.1','step=0.2','step=0.01','step=0.02','step=0.05')
xlabel('SNR (dB)');ylabel('BER')
grid on;

figure;
plot(SNR,10*log10(RMSE_step1),'LineStyle','-','Marker','o');hold on;
plot(SNR,10*log10(RMSE_step2),'LineStyle','-','Marker','+');hold on;
plot(SNR,10*log10(RMSE_step3),'LineStyle','-','Marker','square');hold on;
plot(SNR,10*log10(RMSE_step4),'LineStyle','-','Marker','x');hold on;
plot(SNR,10*log10(RMSE_step5),'LineStyle','-','Marker','*');hold on;
%title(['TQ28 Satellite Channel, SF = ' num2str(SF) ', B = 125kHz']);
legend('step=0.1','step=0.2','step=0.01','step=0.02','step=0.05');
xlabel('SNR (dB)');ylabel('RMSE (dB)')
grid on;


 % save(['RicianFading' num2str(cycle_times) 'time_' 'SF_' num2str(SF) '_' num2str(N_upchirp) '_upchirps_EC_PRC_TQ28_BER.mat'],...
 %    "BER_EC",'BER_PRC', ...
 %    'SNR','SF','B','N_upchirp','N_frame');
%% methods PRC ＆ EC 
function [error1,error2,error3,error4,error5,rmse1,rmse2,rmse3,rmse4,rmse5]=step_EC(SF,epsilon,SNR,N_payload,N_upchirps)
error1=0;
error2=0;
error3=0;
error4=0;
error5=0;
step1=0.1;
step2=0.2;
step3=0.01;
step4=0.02;
step5=0.05;
M=2^SF;
aa=randi([0 M-1], 1, N_payload);
k=0:1:M-1;
%% PRC
%% 调制
xk_payload=zeros(1,M*N_payload);
for i=1:N_payload
    xk_payload((i-1)*M+1:i*M)=exp(1j*2*pi*k.*(aa(i)/M-1/2+k/2/M+epsilon/M));
end
xk_pre=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
xk_preamble=zeros(1,M*N_upchirps);
for ii=1:1:N_upchirps
    xk_preamble((ii-1)*M+1:ii*M)=xk_pre;
end

%% 组帧
xk_frame=[xk_preamble xk_payload];
%% 加噪
%% 手动添加高斯噪声
sigPower=sum(abs(xk_frame.*xk_frame))/length(xk_frame);
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,length(xk_frame))+1j*randn(1,length(xk_frame)));
rk1=xk_frame+noise;
%% 解帧
rk_preamble=rk1(1:N_upchirps*M);
rk_payload=rk1(N_upchirps*M+1:end);
%% 解调
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);%基信号的共轭
% 前导码的处理
r_pre_ave=zeros(1,M);
%只用num个前导码
for o=1:N_upchirps
    rk_pre=rk_preamble((o-1)*M+1:o*M);
    r_pre_ave=r_pre_ave+rk_pre;

end
r_pre_ave=r_pre_ave/N_upchirps;
%% 估计 step=0.1
epsilon_i=0;
eta=0;
eta_o=0;
Yq_max=0;
while eta_o<1
    y_preamble_tem=abs(fft(r_pre_ave.*exp(1j*2*pi*k*eta_o/M).*xk0));
    [Yq_max_tmp,epsilon_integer_tmp]=max(y_preamble_tem);
    if Yq_max_tmp>Yq_max
        Yq_max=Yq_max_tmp;
        eta=eta_o;
        epsilon_i=epsilon_integer_tmp;
    end
    eta_o=eta_o+step1;
end
%% 补偿
for j=1:N_payload
    y_payload=abs(fft(rk_payload((j-1)*M+1:j*M).*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
    [~,d]=max(abs(y_payload));
    if d-1~=aa(j)
        error1=error1+1;
    end
end
rmse1=(epsilon-(epsilon_i-eta-1))^2;


%% 估计 step=0.2
epsilon_i=0;
eta=0;
eta_o=0;
Yq_max=0;
while eta_o<1
    y_preamble_tem=abs(fft(r_pre_ave.*exp(1j*2*pi*k*eta_o/M).*xk0));
    [Yq_max_tmp,epsilon_integer_tmp]=max(y_preamble_tem);
    if Yq_max_tmp>Yq_max
        Yq_max=Yq_max_tmp;
        eta=eta_o;
        epsilon_i=epsilon_integer_tmp;
    end
    eta_o=eta_o+step2;
end
%% 补偿
for j=1:N_payload
    y_payload=abs(fft(rk_payload((j-1)*M+1:j*M).*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
    [~,d]=max(abs(y_payload));
    if d-1~=aa(j)
        error2=error2+1;
    end
end
rmse2=(epsilon-(epsilon_i-eta-1))^2;

%% 估计 step=0.01
epsilon_i=0;
eta=0;
eta_o=0;
Yq_max=0;
while eta_o<1
    y_preamble_tem=abs(fft(r_pre_ave.*exp(1j*2*pi*k*eta_o/M).*xk0));
    [Yq_max_tmp,epsilon_integer_tmp]=max(y_preamble_tem);
    if Yq_max_tmp>Yq_max
        Yq_max=Yq_max_tmp;
        eta=eta_o;
        epsilon_i=epsilon_integer_tmp;
    end
    eta_o=eta_o+step3;
end
%% 补偿
for j=1:N_payload
    y_payload=abs(fft(rk_payload((j-1)*M+1:j*M).*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
    [~,d]=max(abs(y_payload));
    if d-1~=aa(j)
        error3=error3+1;
    end
end
rmse3=(epsilon-(epsilon_i-eta-1))^2;

%% 估计 step=0.02
epsilon_i=0;
eta=0;
eta_o=0;
Yq_max=0;
while eta_o<1
    y_preamble_tem=abs(fft(r_pre_ave.*exp(1j*2*pi*k*eta_o/M).*xk0));
    [Yq_max_tmp,epsilon_integer_tmp]=max(y_preamble_tem);
    if Yq_max_tmp>Yq_max
        Yq_max=Yq_max_tmp;
        eta=eta_o;
        epsilon_i=epsilon_integer_tmp;
    end
    eta_o=eta_o+step4;
end
%% 补偿
for j=1:N_payload
    y_payload=abs(fft(rk_payload((j-1)*M+1:j*M).*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
    [~,d]=max(abs(y_payload));
    if d-1~=aa(j)
        error4=error4+1;
    end
end
rmse4=(epsilon-(epsilon_i-eta-1))^2;

%% 估计 step=0.05
epsilon_i=0;
eta=0;
eta_o=0;
Yq_max=0;
while eta_o<1
    y_preamble_tem=abs(fft(r_pre_ave.*exp(1j*2*pi*k*eta_o/M).*xk0));
    [Yq_max_tmp,epsilon_integer_tmp]=max(y_preamble_tem);
    if Yq_max_tmp>Yq_max
        Yq_max=Yq_max_tmp;
        eta=eta_o;
        epsilon_i=epsilon_integer_tmp;
    end
    eta_o=eta_o+step5;
end
%% 补偿
for j=1:N_payload
    y_payload=abs(fft(rk_payload((j-1)*M+1:j*M).*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
    [~,d]=max(abs(y_payload));
    if d-1~=aa(j)
        error5=error5+1;
    end
end
rmse5=(epsilon-(epsilon_i-eta-1))^2;



end


