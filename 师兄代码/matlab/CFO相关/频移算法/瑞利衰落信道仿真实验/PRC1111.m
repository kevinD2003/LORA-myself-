%% 补偿法，采用频移的方式（将小数倍的频移补全至整数倍）。
%% 小数部分CFO的估计与补偿。
SF=7;
epsilon=[0.5];
M=2^SF;
aa=60;%randi([0 M-1]);
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+epsilon/M));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon/M));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
% rk1=awgn(Sd,SNR,'measured');
rk1 = Sd;
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
r_preamble_ave=zeros(1,M);
%只用N_upchirp个前导码
N_upchirp=8;
for o=1:N_upchirp
    r_preamble=rk1((o-1)*M+1:o*M);
    r_preamble_ave=r_preamble_ave+r_preamble;
end
r_preamble_ave=r_preamble_ave/N_upchirp;
y_upchirp=abs(fft(r_preamble_ave.*xk0))/M;

epsilon_i=0;
eta=0;
Yq_max=0;
eta_o=0:0.1:0.9;
% y_preamble_tem=abs(fft(r_preamble_ave.*exp(1j*2*pi.*k.*eta_o/M).*xk0));

xk0_matrix = repmat(xk0, length(eta_o), 1);

% 使用bsxfun来执行元素级的乘法
y_preamble_tem = abs(fft(r_preamble_ave .* bsxfun(@times, exp(1j*2*pi*k./M), eta_o') .* xk0_matrix)) / M;



o=8;%只用一个前导码
y_payload_withoutEC=abs(fft(rk1(o*M+1:end).*xk0)/M);
y_payload=abs(fft(rk1(o*M+1:end).*xk0.*exp(1j*2*pi*k*(-epsilon_i+eta+1)/M)))/M;
[~,d]=max(abs(y_payload));


figure;
subplot(1,2,2)
stem(0:M-1,y_payload_withoutEC,"Marker","none","LineWidth",0.5);
xlabel("Frequency bin q");ylabel("|Y_q|/M");xlim([0 M-1]);ylim([0 1]);
legend(['ε = ', num2str(epsilon(1))]);
% title("未补偿")

% figure;
subplot(1,2,1)
stem(0:M-1,y_payload,"Marker","none","LineWidth",1.5);
xlabel("Frequency bin q");ylabel("|Y_q|/M");xlim([0 M-1]);ylim([0 1]);
legend(['ε = 0']);
% title("已补偿")
