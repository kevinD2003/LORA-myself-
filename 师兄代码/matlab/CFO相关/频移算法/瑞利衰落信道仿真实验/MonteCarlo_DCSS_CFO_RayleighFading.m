%% 多普勒频偏+多径，采用差分编码
%% 两径信道+不同多普勒
% 信道（1）：epsilon：0.8（60km/h） 0.53（40km/h）ui=20；
% 信道（2）：epsilon：0.53（40km/h） 0.8（60km/h）ui=20；
B=250e3;
SF=12;
M=2^SF;
SNR=-25:20;
epsilon=[0.8];
N_symbol=2;
BER_DCSS=zeros(1,length(SNR));
% times=1000000;
times=[1000*ones(1,6) 10000*ones(1,11) 100000*ones(1,9) 1000000*ones(1,11) 2000000*ones(1,11)];
tic;
h=waitbar(0,'差分编码');
for j=1:length(SNR)
    error_dcss=0;
    for jj=1:times(j)
        Sp=randi([1 M-1],1,N_symbol);
        Dp=zeros(1,length(Sp));
        Dp(1)=Sp(1);
        for i=2:N_symbol
            Dp(i)=mod((Sp(i)+Dp(i-1)),M);
        end
        k=0:1:M-1;
        Sk=zeros(1,N_symbol*M);
        for ii=1:N_symbol
            Sk((ii-1)*M+1:ii*M)=exp(1j*2*pi*k.*(Dp(ii)/M-1/2+k/2/M+epsilon(1)/M));%调制
        end
        xk_preamble=exp(1j*2*pi*k.*(-1/2+k/2/M+epsilon(1)/M));%前导码
        Sk_preamble=[xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble xk_preamble];
        Sk_frame=[Sk_preamble Sk];%组帧

        
        %% 手动添加高斯噪声
        sigPower=sum(abs(Sk_frame.*Sk_frame))/length(Sk_frame);
        reqSNR=10^(SNR(j)/10);
        noisePower=sigPower/reqSNR;
        noise=sqrt(noisePower/2)*(randn(1,length(Sk_frame))+1j*randn(1,length(Sk_frame)));
        %% 瑞利信道
        omega = 1;
        h_rayleigh = sqrt(omega/2) *(randn(1,1) + 1i*randn(1,1));
        Rk_frame=h_rayleigh*Sk_frame+noise;

        Rk=Rk_frame(8*M+1:end);
        xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
        Dp_ncoh=zeros(1,N_symbol);
        for o=1:N_symbol
            Yq=abs(fft(Rk((o-1)*M+1:o*M).*xk0)/M);
            %     figure;plot(0:M-1,Yq);
            [~,decision]=max(Yq);
            Dp_ncoh(o)=decision-1;
        end
        Sp_ncoh=zeros(1,N_symbol);

        for iii=2:N_symbol
            Sp_ncoh(iii)=mod(Dp_ncoh(iii)-Dp_ncoh(iii-1),M);
            if Sp_ncoh(iii)~=Sp(iii)
                error_dcss=error_dcss+1;
            end
        end
    end
    BER_DCSS(j)=error_dcss/times(j)/2/(N_symbol-1);
    if(BER_DCSS(j)<1E-6)
        break;
    end
    waitbar(j/length(SNR),h,['fd=' num2str(SNR(j))]);
end
toc;
close(h);
%%
c=['k';'m';'c';'b';'g';'r';'y'];
% c=[0 0 0;
%     0 0 1;
%     1 0 0;
%     1 0.5 0;
%     1 0 1;
%     0.41961 0.55686 0.13725;];
m=['x';'d';'s';'*';'+';'o';'v'];
figure;
% for f=1:length(fd)
%     semilogy(SNR,BER_DCSS(f,:),'LineStyle','-','Color',c(f,:),'Marker',m(f));hold on;
% end
semilogy(SNR,BER_DCSS,'LineStyle','-','Color','g','Marker','*');hold on;
legend(['SF=' num2str(SF) ',DCSS'])
grid on;