%% 补偿法，采用频移的方式（将小数倍的频移补全至整数倍）。
%% 小数部分CFO的估计与补偿。
SF=6;
M=2^SF;
aa=M/2;%randi([0 M-1]);
k=0:1:M-1;  
epsilon=0:0.1:1;
% rk1=awgn(Sd,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
figure;
for i=1:length(epsilon)
    xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon(i)/M));
    Yq=fft(xk.*xk0);
    Yq=abs(Yq/M);
    subplot(11,1,i)
    stem(0:M-1,Yq,"Marker","none","LineWidth",2);hold on;
    % legend(["ε=" num2str(epsilon)]);
    legend(['ε=' num2str(epsilon(i))])
    xlim([0 M-1]);ylim([0 1]);
end