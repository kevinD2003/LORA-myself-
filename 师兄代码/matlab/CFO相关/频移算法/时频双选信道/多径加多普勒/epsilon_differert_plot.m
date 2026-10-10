B=125e3;
SF=7;
M=2^SF;
k=0:1:M-1;
aa=64;
fd=0.1*B/M;
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/M/2+fd/B));%带频偏的调制公式
xk0=exp(-1j*2*pi*k.*(-1/2+k/M/2));
% xk=awgn(xk,-5);
y=abs(fft(xk.*xk0))/M;
figure;
subplot(5,1,1)
stem(0:M-1,y,'Marker','none','Linewidth',1.5);hold on
xlim([0 M-1]);
xlabel('Frequency bin,q');ylabel('|Y_q|/M');
legend(['epsilon=',num2str(fd/(B/M)),'SF=7']);
%% 
fd=0.3*B/M;
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/M/2+fd/B));%带频偏的调制公式
xk0=exp(-1j*2*pi*k.*(-1/2+k/M/2));
% xk=awgn(xk,-5);
y=abs(fft(xk.*xk0))/M;
subplot(5,1,2)
stem(0:M-1,y,'Marker','none','Linewidth',1.5);hold on
xlim([0 M-1]);
xlabel('Frequency bin,q');ylabel('|Y_q|/M');
legend(['epsilon=',num2str(fd/(B/M)),'SF=7']);

%% 
fd=0.5*B/M;
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/M/2+fd/B));%带频偏的调制公式
xk0=exp(-1j*2*pi*k.*(-1/2+k/M/2));
% xk=awgn(xk,-5);
y=abs(fft(xk.*xk0))/M;
subplot(5,1,3)
stem(0:M-1,y,'Marker','none','Linewidth',1.5);hold on
xlim([0 M-1]);
xlabel('Frequency bin,q');ylabel('|Y_q|/M');
legend(['epsilon=',num2str(fd/(B/M)),'SF=7']);

%%
fd=0.7*B/M;
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/M/2+fd/B));%带频偏的调制公式
xk0=exp(-1j*2*pi*k.*(-1/2+k/M/2));
% xk=awgn(xk,-5);
y=abs(fft(xk.*xk0))/M;
subplot(5,1,4)
stem(0:M-1,y,'Marker','none','Linewidth',1.5);hold on
xlim([0 M-1]);
xlabel('Frequency bin,q');ylabel('|Y_q|/M');
legend(['epsilon=',num2str(fd/(B/M)),'SF=7']);

%% 
fd=0.9*B/M;
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/M/2+fd/B));%带频偏的调制公式
xk0=exp(-1j*2*pi*k.*(-1/2+k/M/2));
% xk=awgn(xk,-5);
y=abs(fft(xk.*xk0))/M;
subplot(5,1,5)
stem(0:M-1,y,'Marker','none','Linewidth',1.5);hold on
xlim([0 M-1]);
xlabel('Frequency bin,q');ylabel('|Y_q|/M');
legend(['epsilon=',num2str(fd/(B/M)),'SF=7']);
