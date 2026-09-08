%% 补偿法，采用频移的方式（将小数倍的频移补全至整数倍）。
%% 小数部分CFO的估计与补偿。
%% Monte Carlo实验 CFO。
SF=12;
SNR=-25:-20;
% SNR=-20;
epsilon=[0.8];
BER_PREC=zeros(length(epsilon),length(SNR));
RMSE_PRC=zeros(length(epsilon),length(SNR));
times=[10000*ones(1,length(SNR))];
tic;
h=waitbar(0,['SF=' num2str(SF) ',\eta=' num2str(epsilon)]);
for j=1:length(epsilon)
    for jj=1:length(SNR)
        error=0;
        rmse=0;
        for jjj=1:times(jj)
            [error1,rmse1]=PREC(SF,epsilon(j),SNR(jj));
            error=error+error1;
            rmse=rmse+rmse1;
        end
        BER_PREC(j,jj)=error/times(jj)/2;
        RMSE_PRC(j,jj)=sqrt(rmse/(times(jj)));
        waitbar(jj/length(SNR),h,['\eta=' num2str(epsilon) ';SNR=' num2str(SNR(jj))]);
        if(BER_PREC(j,jj)<1E-6)
            break;
        end
    end
%     waitbar(j/length(lambda),h,['\lambda=' num2str(lambda(j))]);
end
toc;
close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
c =['r';'y';'g';'c';'m'];
figure;
for f=1:length(epsilon)
% semilogy(SNR,BER_LoRa(f,:),'LineWidth',1,'Color','b','LineStyle','-','Marker',m(f));hold on
semilogy(SNR,BER_PREC(f,:),'Color',c(f),'LineStyle','-','Marker',m(f));hold on
end
xlabel('SNR');ylabel('BER');
% legend("FSEC one preamble");%采用一个前导码
grid on;
RMSE_dB = 10*log10(RMSE_PRC);
figure;
% semilogy(SNR,RMSE_PRC,'r-o');
plot(SNR,RMSE_dB,'r-o');
xlabel('SNR');ylabel('RMSE');
grid on;
%% 
function [error1,rmse]=PREC(SF,epsilon,SNR)
M=2^SF;
aa=randi([0 M-1]);
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon/M));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
rk1=awgn(Sd,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);

r_preamble_ave=zeros(1,M);

num=8;
for o=1:num
    r_preamble=rk1((o-1)*M+1:o*M);
    r_preamble_ave=r_preamble_ave+r_preamble;

end
r_preamble_ave=r_preamble_ave/num;

eta_fraction=(0:0.1:0.9);
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
o=8;%只用一个前导码
y_payload=abs(fft(rk1(o*M+1:end).*xk0.*exp(1j*2*pi*k*(-epsilon_integer_estimation+eta_fraction_estimation+1)/M)))/M;
[~,d]=max(abs(y_payload));
if d-1==aa
    error1=0;
else
    error1=1;

end


% rmse=(mod(epsilon,M)-mod((epsilon_integer_estimation-eta_fraction_estimation-1),M))^2;
rmse=(mod(epsilon,M)-mod((epsilon_integer_estimation-eta_fraction_estimation-1),M))^2;

end
