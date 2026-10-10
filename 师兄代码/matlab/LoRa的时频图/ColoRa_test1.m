B=125e3;
SF=7;
M=2^SF;
k = 0 : M - 1;
xk0=exp(-1j*2*pi*k.*(-1/2+k/2/M));%LoRa基信号的共轭
aA1=0;aA2=64;aA3=0;
xkA1=exp(1j*2*pi*k.*(aA1/M-1/2+k/2/M));
xkA2=exp(1j*2*pi*k.*(aA2/M-1/2+k/2/M));
xkA3=exp(1j*2*pi*k.*(aA3/M-1/2+k/2/M));
xkA=[xkA1 xkA2 xkA3];

% packetB
aB1=64;aB2=0;aB3=64;
xkB1=exp(1j*2*pi*k.*(aB1/M-1/2+k/2/M));
xkB2=exp(1j*2*pi*k.*(aB2/M-1/2+k/2/M));
xkB3=exp(1j*2*pi*k.*(aB3/M-1/2+k/2/M));
xkB=[xkB1 xkB2 xkB3];

rkB=[zeros(1,40) xkB zeros(1,88)];
rkA=[zeros(1,20) xkA zeros(1,108)];
rk=rkA+rkB;
rk1=rk(1:M);
rk2=rk(M+1:2*M);
rk3=rk(2*M+1:3*M);
rk4=rk(3*M+1:4*M);

rkA1=rkA(1:M);
rkA2=rkA(M+1:2*M);
rkA3=rkA(2*M+1:3*M);
rkA4=rkA(3*M+1:4*M);

rkB1=rkB(1:M);
rkB2=rkB(M+1:2*M);
rkB3=rkB(2*M+1:3*M);
rkB4=rkB(3*M+1:4*M);


Yq1_DNC=abs(fft(rk1.*xk0)/M);%非相干解调
figure;stem(0:M-1,Yq1_DNC,"Marker","none");xlabel('q');ylabel('|Yq1|/M');xlim([0 M - 1]);ylim([0 1]);

Yq2_DNC=abs(fft(rk2.*xk0)/M);%非相干解调
figure;stem(0:M-1,Yq2_DNC,"Marker","none");xlabel('q');ylabel('|Yq2|/M');xlim([0 M - 1]);ylim([0 1]);

Yq3_DNC=abs(fft(rk3.*xk0)/M);%非相干解调
figure;stem(0:M-1,Yq3_DNC,"Marker","none");xlabel('q');ylabel('|Yq3|/M');xlim([0 M - 1]);ylim([0 1]);

Yq4_DNC=abs(fft(rk4.*xk0)/M);%非相干解调
figure;stem(0:M-1,Yq4_DNC,"Marker","none");xlabel('q');ylabel('|Yq4|/M');xlim([0 M - 1]);ylim([0 1]);



%
YqA1_DNC=abs(fft(rkA1.*xk0)/M);%非相干解调
figure;subplot(1,4,1);
stem(0:M-1,YqA1_DNC,"Marker","none","Color",[1 0.5 0],"LineWidth",1.5);hold on;
xlabel('q');ylabel('|Yq|/M');xlim([0 M - 1]);ylim([0 1]);
YqB1_DNC=abs(fft(rkB1.*xk0)/M);%非相干解调
stem(0:M-1,YqB1_DNC,"Marker","none","Color","b","LineWidth",1.5);

YqA2_DNC=abs(fft(rkA2.*xk0)/M);%非相干解调
% figure;
subplot(1,4,2);
stem(0:M-1,YqA2_DNC,"Marker","none","Color",[1 0.5 0],"LineWidth",1.5);hold on;
xlabel('q');ylabel('|Yq|/M');xlim([0 M - 1]);ylim([0 1]);
YqB2_DNC=abs(fft(rkB2.*xk0)/M);%非相干解调
stem(0:M-1,YqB2_DNC,"Marker","none","Color","b","LineWidth",1.5);

YqA3_DNC=abs(fft(rkA3.*xk0)/M);%非相干解调
% figure;
subplot(1,4,3);
stem(0:M-1,YqA3_DNC,"Marker","none","Color",[1 0.5 0],"LineWidth",1.5);hold on;
xlabel('q');ylabel('|Yq|/M');xlim([0 M - 1]);ylim([0 1]);
YqB3_DNC=abs(fft(rkB3.*xk0)/M);%非相干解调
stem(0:M-1,YqB3_DNC,"Marker","none","Color","b","LineWidth",1.5);

YqA4_DNC=abs(fft(rkA4.*xk0)/M);%非相干解调
% figure;
subplot(1,4,4);
stem(0:M-1,YqA4_DNC,"Marker","none","Color",[1 0.5 0],"LineWidth",1.5);hold on;
xlabel('q');ylabel('|Yq|/M');xlim([0 M - 1]);ylim([0 1]);
YqB4_DNC=abs(fft(rkB4.*xk0)/M);%非相干解调
stem(0:M-1,YqB4_DNC,"Marker","none","Color","b","LineWidth",1.5);