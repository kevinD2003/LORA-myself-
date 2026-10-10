%% A Low-Complexity LoRa Synchronization Algorithm Robust to Sampling Time Offsets
%% 小数部分CFO的估计与补偿。
%% Monte Carlo实验 CFO+Multipath
SF=7;
SNR=-15:50;
lambda=[0.3];
ui=[0 10];
hi=[sqrt(0.8) sqrt(0.2)];
BER_LoRa=zeros(length(lambda),length(SNR));
BER_IOTJ2022=zeros(length(lambda),length(SNR));
times=[1000000*ones(1,length(SNR))];%[1000000*ones(1,length(SNR))];
tic;
h=waitbar(0,['SF=' num2str(SF) ',\lambda=' num2str(lambda)]);
for j=1:length(lambda)
    for jj=1:length(SNR)
        error_lora=0;
        error_iotj2022=0;
        for jjj=1:times(jj)
            [error1,error2]=IOTJ2022(SF,lambda(j),SNR(jj),ui,hi);
            error_lora=error_lora+error2;
            error_iotj2022=error_iotj2022+error1;
        end
        BER_LoRa(j,jj)=error_lora/times(jj)/2;
        BER_IOTJ2022(j,jj)=error_iotj2022/times(jj)/2;
        waitbar(jj/length(SNR),h,['\lambda=' num2str(lambda) ';SNR=' num2str(SNR(jj))]);
    end
%     waitbar(j/length(lambda),h,['\lambda=' num2str(lambda(j))]);
end
toc;
close(h);
%%
m=['o';'x';'s';'+';'^';'*';'p';'d';];
c =['r';'y';'g';'c';'m'];
figure;
for f=1:length(lambda)
semilogy(SNR,BER_LoRa(f,:),'LineWidth',1,'Color','b','LineStyle','-','Marker',m(f));hold on
semilogy(SNR,BER_IOTJ2022(f,:),'Color',c(f),'LineStyle','-','Marker',m(f));hold on
end
xlabel('SNR');ylabel('BER');
% legend(['\lambda=,DNC'],'\lambda=0.8,IOTJ2022');
legend(['DNC,SF=' num2str(SF) ',ui=' num2str(ui(2)) ',epsilon=' num2str(epsilon)],['SF=' num2str(SF) ',ui=' num2str(ui(2)) ',epsilon=' num2str(epsilon)])
grid on;

%% 
function [error1,error2]=IOTJ2022(SF,lambda,SNR,ui,hi)
M=2^SF;
k=0:M-1;
n=0:8*M-1;
a=randi([0 M-1]);
Nc=7;
xk=exp(1j*2*pi*k.*(a/M-1/2+k/2/M+lambda/M));
xk_preamble=exp(1j*2*pi*n.*(-1/2+n/2/M+lambda/M));
xk0_preamble=exp(-1j*2*pi*n.*(-1/2+n/2/M));
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));
S=[xk_preamble xk];
% 多径
S_matipath=zeros(1,length(S));
for i=2:length(ui)
    S_temp=[zeros(1,ui(i)) S(1:end-ui(i))];
    S_matipath=S_matipath+hi(i)*S_temp;
end
S=hi(1)*S;
rk=awgn(S,SNR,'measured')+S_matipath;
lambda_CFO=0;
for l=2:Nc
    y_l_1=rk((l-2)*M+1:(l-1)*M);
    y_l=rk((l-1)*M+1:l*M);
    Y_l=fft(y_l.*xk0_preamble((l-1)*M+1:l*M));
    Y_l_1=fft(y_l_1.*xk0_preamble((l-2)*M+1:(l-1)*M));
    [~,i]=max(abs(Y_l));
    lambda_cfo=0;
    for p=-2:2
        n=mod(i+p,M);
        if n==0
            n=M;
        end
        lambda_cfo=lambda_cfo+Y_l(n)*conj(Y_l_1(n));
    end
    lambda_CFO=lambda_CFO+lambda_cfo;
end
lambda_CFO=angle(lambda_CFO)/pi/2;
%% 整数部分 循环移位
r_preamble_integer=zeros(1,M);
 for o=1:8
     r_preamble_integer=r_preamble_integer+fft(rk((o-1)*M+1:o*M).*xk0_preamble((o-1)*M+1:o*M).*exp(-1j*2*pi*lambda_CFO*((o-1)*M+1:o*M)/M));
 end
 r_preamble_integer= r_preamble_integer/8;
Yq_preamble_integer=r_preamble_integer;
[~,a_preamble]=max(Yq_preamble_integer);
%% 对payload的处理
r_payload=rk(8*M+1:end);
Y_payload=fft(xk0.*r_payload.*exp(-1j*2*pi*lambda_CFO*k/M));%% dechrip+小数部分补偿+DFT；
Y_payload=[Y_payload(a_preamble:end) Y_payload(1:a_preamble-1)];%% 整数部分循环移位；也可以在dechirp后面做循环移位，再进行DFT。
[~,d]=max(abs(Y_payload/M));
if d-1==a
    error1=0;
else
    error1=1;
end
%% 未补偿DNC
Y_payload_DNC=fft(xk0.*r_payload);
[~,dnc]=max(abs(Y_payload_DNC/M));
if dnc-1==a
    error2=0;
else
    error2=1;
end
% %% 画图
% figure;
% subplot(2,1,2)
% stem(0:M-1,abs(Y_payload/M),'Marker','none');xlabel('q');ylabel('Y_q');xlim([0 M-1]);
% title('2022IOTJ');
% subplot(2,1,1)
% stem(0:M-1,abs(Y_payload_DNC/M),'Marker','none');xlabel('q');ylabel('Y_q');xlim([0 M-1]);ylim([0 1])
% title('DNC')
end
