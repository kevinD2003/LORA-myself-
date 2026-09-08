%带频偏的LoRa计算误码率；
B=125e3;
SF=7;
M=2^SF;
% SNR=-20:1:5;
% times=1000000;
SNR=-6;
times=100;
fd=0.6*B/M;%多普勒频偏Hz
BER_Doppler=zeros(1,length(SNR));
BER_LoRa=zeros(1,length(SNR));
BER_MF=zeros(1,length(SNR));
BER_MF_IBD=zeros(1,length(SNR));



%% MF 匹配滤波法
tic;
h2=waitbar(0,'MF,SF=7,fd=0.8*\Deltaf');
for i=1:1:length(SNR)
    error_mf=0;
   for j=1:1:times
       error_mf=error_mf+MF(M,B,fd,SNR(i));
   end
   BER_MF(i)=error_mf/times/2;
   waitbar(i/length(SNR));
end
toc;
close(h2);



%%
figure;
semilogy(SNR,BER_MF,'m-s');hold on;
xlabel('SNR(dB)');ylabel('BER');
grid on;
legend('MF,f_d=0.7*\Deltaf');
%xlim([-20 -4])
% title('B=125KHz,SF=7,\Deltaf=B/M=976.5625Hz');


%% 匹配滤波法
function error=MF(M,B,fd,SNR)
aa=randi([0 M-1]);
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
rk1=awgn(Sd,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:8
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
    y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=y_preamble/8;
% y_preamble(y_preamble<threshold)=0;%滤波
y_preamble=y_preamble.^2;
y_preamble=y_preamble/max(y_preamble);
y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;
y_payload=y_payload.^2;
y_payload=y_payload/max(y_payload);
%圆周相关运算
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble.*y_tem);
end
%解调,传统
[~,decision]=max(R);
if ((decision-1) ~= aa)
    error = 1;
    aa
    figure;plot(0:M-1,y_preamble);title('preamble');
    figure;plot(0:M-1,y_payload);title('payload');
    figure;plot(0:M-1,R);title('R');
else
    error = 0;
end
end

%% 匹配滤波+块内分集
function error=MFIBDD(M,B,fd,SNR)
aa=randi([0 M-1]);
alpha=0.25;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));
xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+fd/B));%前导符号
Sd=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk];
rk1=awgn(Sd,SNR,'measured');
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
y_preamble=zeros(1,M);
for o=1:8
    r_preamble=rk1((o-1)*M+1:o*M);
    y_preamble_tem=abs(fft(r_preamble.*xk0))/M;
    threshold=alpha*max(y_preamble_tem);
%     y_preamble_tem(y_preamble_tem<threshold)=0;%滤波
    y_preamble=y_preamble+y_preamble_tem;
end
y_preamble=y_preamble/8;
y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;
% ypa=y_payload;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%加入判断语句，判断是否为0.5的位置%%%%%%
% y_preamble_sort=sort(y_preamble,'descend');
% y_payload_sort=sort(y_payload,'descend');
% beta=0.85;
% if (y_preamble_sort(2)>=beta*y_preamble_sort(1))%||(y_payload_sort(2)>=beta*y_payload_sort(1))%0.5的情况
    y_preamble=IBD(y_preamble,M,5);
    y_payload=IBD(y_payload,M,5);
% else
%     [y_preamble,y_payload]=IBDD(y_preamble,y_payload,M,5);
%     [y_preamble,y_payload]=IBDDM(y_preamble,y_payload,M,3);
% end
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% y_preamble=y_preamble/4;
y_preamble(y_preamble<threshold)=0;%滤波
%圆周相关运算
R=zeros(1,M);
for d=1:M
    y_tem=[y_payload(d:end) y_payload(1:d-1)];
    R(d)=sum(y_preamble.*y_tem);
end
%解调
[~,decision]=max(R);
if ((decision-1) ~= aa)
    error = 1;
%     aa
%     figure;plot(0:M-1,y_preamble);title('preamble,未分集');
%     figure;plot(0:M-1,ypa);title('payload,未分集');
%     figure;plot(0:M-1,y_preamble);title('preamble,分集');
%     figure;plot(0:M-1,y_payload);title('payload,分集');
%     figure;plot(0:M-1,R);title('R');
else
    error = 0;
end
end


