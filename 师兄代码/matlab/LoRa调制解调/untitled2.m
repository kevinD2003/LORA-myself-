%% LoRa的连续时间调制公式
SF=9;
M=2^SF;
B=125e3;
a=384;
T=M/B;
t=0:1/B:T;
x_t_a=exp(1j*2*pi*B*t.*(a/M-1/2+B*t/M-((t-(M-a)/B)>=0)));
x_t_0=exp(-1j*2*pi*B*t.*(-1/2+B*t/M-((t-(M)/B)>=0)));
y=fft(x_t_a.*x_t_0);
figure;
plot(t,real(x_t_a));
xlabel('t/s');ylabel('')