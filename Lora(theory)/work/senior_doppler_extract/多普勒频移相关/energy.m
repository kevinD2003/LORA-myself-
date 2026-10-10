B=125e3;
SF=7;
M=2^SF;
k=0:1:M-1;
aa=M/2;
f=-488:1:488;
r=zeros(1,length(f));
for i=1:1:length(f)
%调制
xk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M+f(i)/B));%带频偏
yk=exp(1j*2*pi*k.*(aa/M-1/2+k/2/M));%常规调制
%比较未频偏与频偏后的能量
% xk=abs(xk);
% yk=abs(yk);
% E1=0;E2=0;
% for i=1:M
%     E1=E1+xk(i)*xk(i);
%     E2=E2+yk(i)*yk(i);
% end
xk0=exp(-1j*2*pi*k.^2/(2*M)+1j*pi*k);
Yq1=max(abs(fft(xk.*xk0))/M);
Yq2=max(abs(fft(yk.*xk0))/M);
r(i)=Yq1/Yq2;
end
figure;
plot(f,r,'r*');hold on;
p1=-1.551e-6;p2=7.335e-18;p3=0.9959;
g=p1*f.*f+p2*f+p3;
plot(f,g,'b-');hold on;
legend('r f','拟合');