%QPSK门特卡罗实验计算BER
fc=400e6;
M=4;%QPSK，M=4。
SNR=-10:1:30;
times=4320;
BER=zeros(1,length(SNR));
PER=zeros(1,length(SNR));
syncode=ones(1,32)*3;%载波同步
sqecode=randn([0 M-1],1,32);%序列码
scode=[1 1 1 1 3 2 1 2 1 1 0 1 0 1 2 0 1 3 2 3 3 2 2 3 1 1 0 3 1 2 1 3 1 2 3 2 2 1 0 2 3 0 1 3 0 2 0 1 1 3 0 0 1 2 2 0 0 1 0 2 3 3 0 2];%独特码
fecode=randn([0 M-1],1,64);%帧尾
for i=1:1:length(SNR)
    error=0;
    count_db=0;
    for j=1:1:times
        data=randi([0,M-1],1,1360);
        frame=[syncode sqecode scode data fecode];
        y=pskmod(frame,M,pi/M);%M=4，QPSK调制。
        r=awgn(y,SNR(i));
        datar=pskdemod(r,M,pi/M);%QPSK解调。
        scode_r=frame(65:128);%独特码校验
        if tellerror(scode,scode_r)==0
           dataerror=tellerror(data,frame(129:1488));%计算每次错误的符号个数。
           error=error+dataerror; 
        else
            count_db=count_db+1;%如果校验失败，丢包
            
        end
        
    end
    BER(i)=0.5*error/(times-count_db)/1360;
    PER(i)=count_db/times;
end
figure;
semilogy(SNR,BER,'b-o');
figure;
semilogy(PER,BER,'r-o');
function xerror=tellerror(x,xr)
xerror=0;
for i=1:1:length(x)
    if xr(i)~=x(i)
        xerror=xerror+1;
    end
end
end