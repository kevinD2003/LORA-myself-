%带频偏的LoRa计算及理论值；不是理论值

B=125e3;
SF=7;
M=2^SF;
f=rand(1,1)*B/(2*M)
f/B
aa=randi([0 M-1]);
k=0:1:M-1;
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+f/B));
%xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));
SNR=0;
%rk=awgn(xk,SNR);
rk=xk;
%解调,传统
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
Yq=fft(rk.*xk0)/M;
Yq=abs(Yq);%非相干解调
figure;
plot(Yq);
ylim([0 1]);
[~,decision]=max(Yq);
aancoh=decision-1;
if ((decision-1) ~= aa)
    aaerror = 1;
else
    aaerror = 0;
end
%%计算理论值
%带频偏下的
q=0:1:M-1;
num=sin(pi*(q-aa-M*f/B));
den=sin(pi*(q-aa-M*f/B)/M);
Yqcof=abs(num./den.*exp(-1j*pi*(q-aa-M*f/B)*(1-1/M)))/M;
figure;
plot(Yqcof);
ylim([0 1]);
%不带频偏的
p=0:1:M-1;
num1=sin(pi*(p-aa));
den1=sin(pi*(p-aa)/M);
Yq=abs(num1./den1.*exp(-1j*pi*(p-aa)*(1-1/M)))/M;
Yq(aa+1)=exp(-1j*(pi*((1-1/M)*(aa)+(aa-M*aa)/M)));
figure;
plot(Yq);
ylim([0 1]);
figure;
plot(abs(Yqcof-Yq));
ylim([0 1]);