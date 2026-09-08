%% 电力线通信（密集多径信道）
SF=12;
M=2^SF;
SNR=-30:1:10;
times=10000;
N_error_max=20000000;
BER=zeros(1,length(SNR));
BER_PLC=zeros(1,length(SNR));
tic;
h=waitbar(0,'waiting,SF=7');
for ii=1:1:length(SNR)
    error_LoRa=0;
    error_PLC=0;
    for iii=1:1:times
        if error_LoRa<N_error_max
            p = 16;
            [error1, error2]=Nerror(M,SNR(ii),p);
            error_LoRa=error_LoRa+error1;
            error_PLC = error_PLC + error2; 
            N=iii;
        else
            break;
        end
    end
    BER(1,ii)=error_LoRa/N/2;
    BER_PLC(1,ii)=error_PLC/N/2;
    if BER(1,ii)<1E-6
        break;
    end
     waitbar(ii/length(SNR),h,['SNR=',num2str(SNR(ii)),'dB']);
end
toc;
close(h);
%%
figure;
semilogy(SNR,BER,'b--p','Markersize',8);hold on 
semilogy(SNR,BER_PLC,'r--s','Markersize',8);hold on
xlabel('SNR(dB)');ylabel('BER');
legend('SF=12,LoRa','SF=12,PLC');
ylim([10^(-4) 1]);
grid on
%% LoRa
function [aerror, aplcerror]=Nerror(M,SNR,p)
G = M / p;
aa=randi([0 G-1]);
aa = aa * p;
k=0:1:M-1;  
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
%% 瑞利信道
sample = 10;
h_rayleigh = zeros(1,sample+1);
omega = 1;
for hh = 1 : length(h_rayleigh)
    h_rayleigh(hh) = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
end
% h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
% rk2=h_rayleigh(1)*xk;
rk2=h_rayleigh(1) * xk;
xk = rk2;
%% 手动添加高斯噪声
sigPower=sum(abs(xk.*xk))/M;
reqSNR=10^(SNR/10);
noisePower=sigPower/reqSNR;
noise=sqrt(noisePower/2)*(randn(1,M)+1j*randn(1,M));
%% 加多径sample即ui
rk_multipaths = zeros(1, M);
for i = 1 : sample
    rk_tmp  = [zeros(1, i) rk2(1: M - i)];
    rk_multipaths =  h_rayleigh(i + 1) * rk_multipaths + rk_tmp;
end
rk2 = rk2 + rk_multipaths + noise;
% %% 加多径sample即ui, 无瑞利衰落
% rk_multipaths = zeros(1, M);
% for i = 1 : sample
%     rk_tmp  = [zeros(1, i) rk2(1: M - i)];
%     rk_multipaths =  rk_multipaths + rk_tmp;
% end
% rk2 = rk2 + rk_multipaths + noise;
%% 非相干解调
Yq2=fft(rk2.*xk0)/M;
Yq2=abs(Yq2);%非相干解调
Yq2 = Yq2.*Yq2;
% figure;plot(0:M-1,Yq2);
[~,decision2]=max(Yq2);
    if ((decision2-1) ~= aa)
        aerror = 1;
    else
        aerror = 0;
    end
%% 文章中的方法
s_g = zeros(1, M);
s_g(1) = Yq2(1) + sum(Yq2(M - (p - 1):end));
for g = p + 1 : p : M
    % s_g(g) = Yq2(g);
    s_g(g) = sum(Yq2(g - (p - 1):g));
end
% figure;stem(0:M - 1,s_g,"Marker","none");
[~,aaplc]=max(s_g);
    if ((aaplc-1) ~= aa)
        aplcerror = 1;
    else
        aplcerror = 0;
    end
end


