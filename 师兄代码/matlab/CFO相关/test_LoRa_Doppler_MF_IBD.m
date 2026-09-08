%带频偏的LoRa计算误码率；
B=125e3;
SF=7;
M=2^SF;
SNR=-20:1:5;
times=10000;
% SNR=-6;
% times=1000;
fd=0.7*B/M;%多普勒频偏Hz
BER_Doppler=zeros(1,length(SNR));
BER_LoRa=zeros(1,length(SNR));
BER_MF=zeros(1,length(SNR));
BER_MF_IBD=zeros(1,length(SNR));

%% LoRa
tic;
h1=waitbar(0,'LoRa,SF=7,fd=0.8*\Deltaf');
for i=1:1:length(SNR)
    error=0;
    errorL=0;
   for j=1:1:times
       [error1,error2]=Nerror(M,B,fd,SNR(i));
       error=error+error1;
       errorL=errorL+error2;
   end
   BER_Doppler(i)=error/times/2;
   BER_LoRa(i)=errorL/times/2;
   waitbar(i/length(SNR));
end
toc;
close(h1);

%% MF 匹配滤波法
h2=waitbar(0,'MF,SF=7,fd=0.8*\Deltaf');
for i=1:1:length(SNR)
    error_mf=0;
    error_d=0;
   for j=1:1:times
       [errormf,errord]=MF(M,B,fd,SNR(i));
       error_mf=error_mf+errormf;
       error_d=error_d+errord;
   end
   BER_MF(i)=error_mf/times/2;
   BER_MF_IBD(i)=error_d/times/2;
   waitbar(i/length(SNR));
end
toc;
close(h2);

%%
figure;
semilogy(SNR,BER_LoRa,'b-o');hold on;
semilogy(SNR,BER_Doppler,'r-*');hold on;
semilogy(SNR,BER_MF,'m-s');hold on;
semilogy(SNR,BER_MF_IBD,'-p','Color',[1 0.5 0]);hold on;

xlabel('SNR(dB)');ylabel('BER');
grid on;
legend('LoRa,f_d=0 ','LoRa,f_d=0.7*\Deltaf','MF,f_d=0.7*\Deltaf','MF-块内分集,f_d=0.7*\Deltaf');
%xlim([-20 -4])
% title('B=125KHz,SF=7,\Deltaf=B/M=976.5625Hz');

%% LoRa调制解调；受到多普勒频偏影响的LoRa调制解调。
function [aaerror,aaerrorL]=Nerror(M,B,fd,SNR)
aa=randi([0 M-1]);
k=0:1:M-1;  
xk_Doppler=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+fd/B));%受到多普勒频偏影响的LoRa信号
xk_LoRa=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));%不受多普勒频移
rk1=awgn(xk_Doppler,SNR,'measured');
rk2=awgn(xk_LoRa,SNR,'measured');
%解调,传统
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
Yq=fft(rk1.*xk0)/M;
Yq=abs(Yq);%非相干解调
[~,decision]=max(Yq);
    if ((decision-1) ~= aa)
        aaerror = 1;
    else
        aaerror = 0;
    end
    YqL=fft(rk2.*xk0)/M;
    YqL=abs(YqL);%非相干解调
    [~,decisionL]=max(YqL);
    if ((decisionL-1) ~= aa)
        aaerrorL = 1;
    else
        aaerrorL = 0;
    end
end


%% MF算法
function [error,errord]=MF(M,B,fd,SNR)
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
    
    y_preamble=y_preamble+y_preamble_tem;
end
% y_preamble=(y_preamble/8);
y_preamble=y_preamble/max(y_preamble);
y_preamble_d=y_preamble;
threshold=alpha*max(y_preamble);
y_preamble(y_preamble<threshold)=0;%滤波
% y_preamble(y_preamble<threshold)=0;%滤波

y_payload=abs(fft(rk1(o*M+1:end).*xk0))/M;
% y_payload=y_payload.^2;
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
else
    error = 0;
end
%% 采用块内分集
[y_preamble_D,y_payload_D]=IBDSP(y_preamble_d,y_payload,M,3);
y_preamble_D(y_preamble_D<alpha*max(y_preamble_D))=0;%滤波
Rd=zeros(1,M);
for d=1:M
    y_payload_tem=[y_payload_D(d:end) y_payload_D(1:d-1)];
    Rd(d)=sum(y_preamble_D.*y_payload_tem);
end
%解调,传统
[~,decisiond]=max(Rd);
if ((decisiond-1) ~= aa)
    errord = 1;
%     aa
%     figure;plot(0:M-1,y_preamble);title('preamble');
%     figure;plot(0:M-1,y_payload);title('payload');
%     figure;plot(0:M-1,Rd);title('Rd');
else
    errord = 0;
end

end

%% 块内分集+形成单径或者多径选择
function [Yq_preamble_D,Yq_payload_D]=IBDSP(Yq_preamble,Yq_payload,M,N)
[~,decision_preamble]=max(Yq_preamble);
[~,decision_payload]=max(Yq_payload);

for j=1:N
    %% 前导符号处理
    %对前导码最大值左边数据处理
    decision_left_preamble=mod(decision_preamble-j,M);
    if decision_left_preamble==0
        decision_left_preamble=M;
    end
    Yq_preamble(decision_preamble)= Yq_preamble(decision_preamble)+Yq_preamble(decision_left_preamble);
%     Yq_preamble(decision_left_preamble)=0;
    %对前导码最大值右边数据处理
    decision_right_preamble=mod(decision_preamble+j,M);
    if decision_right_preamble==0
        decision_right_preamble=M;
    end
    Yq_preamble(decision_preamble)= Yq_preamble(decision_preamble)+Yq_preamble(decision_right_preamble);
%     Yq_preamble(decision_right_preamble)=0;
    %% 对数据块处理
    %对数据块最大值左边数据处理
    decision_left_payload=mod(decision_payload-j,M);
    if decision_left_payload==0
        decision_left_payload=M;
    end
    Yq_payload(decision_payload)= Yq_payload(decision_payload)+Yq_payload(decision_left_payload);
%     Yq_payload(decision_left_payload)=0;
    %对数据块最大值右边数据处理
    decision_right_payload=mod(decision_payload+j,M);
    if decision_right_payload==0
        decision_right_payload=M;
    end
    Yq_payload(decision_payload)= Yq_payload(decision_payload)+Yq_payload(decision_right_payload);
%     Yq_payload(decision_right_payload)=0;
end
Yq_preamble_D=Yq_preamble;
Yq_payload_D=Yq_payload;
end
