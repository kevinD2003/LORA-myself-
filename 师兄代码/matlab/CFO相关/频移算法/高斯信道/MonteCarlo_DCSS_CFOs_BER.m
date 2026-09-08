%% 多普勒频偏采用差分编码
B=500e3;
SF=12;
M=2^SF;
SNR=-25:-15;
epsilon=0.8;
fd=[epsilon]*B/M;
% fd=0;
% SNR=10;
% fd=0.8*B/M;
N_symbol=11;
BER_DCSS=zeros(length(fd),length(SNR));
times=1000000;
tic;
h=waitbar(0,'差分编码');
for jjj=1:length(fd)
% jjj=1;
    for jj=1:length(SNR)
        error_dcss=0;
        for j=1:times
            Sp=randi([0 M-1],1,N_symbol);
            Dp=zeros(1,length(Sp));
            Dp(1)=Sp(1);
            for i=2:N_symbol
                Dp(i)=mod((Sp(i)+Dp(i-1)),M);
            end
            k=0:1:M-1;
            Sk=zeros(1,N_symbol*M);
            for ii=1:N_symbol
                Sk((ii-1)*M+1:ii*M)=exp(1j*2*pi*k.*(Dp(ii)/M-1/2+k/2/M+fd(jjj)/B));%调制
            end
            Rk=awgn(Sk,SNR(jj),'measured');
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
        BER_DCSS(jjj,jj)=error_dcss/times/2/(N_symbol-1);
        waitbar(jj/length(SNR),h,['fd=' num2str(SNR(jj))]);
    end
    waitbar(jjj/length(fd),h,['fd=' num2str(fd(jjj))]);
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
for f=1:length(fd)
    semilogy(SNR,BER_DCSS(f,:),'LineStyle','-','Color',c(f,:),'Marker',m(f));hold on;
end
title('DCSS');
legend('epsilon=0.8,SF=12')
% legend('DCSS,fd=0','DCSS,fd=0.1*\Deltaf','DCSS,fd=0.2*\Deltaf','DCSS,fd=0.3*\Deltaf','DCSS,fd=0.4*\Deltaf','DCSS,fd=0.5*\Deltaf','DCSS,fd=0.6*\Deltaf');
grid on;