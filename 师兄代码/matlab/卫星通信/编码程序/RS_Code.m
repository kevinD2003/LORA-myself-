%% RS编码
%本例中输入信息分为km比特一组，每组k个符号
%每个符号由m个比特组成
%快速演示，没有具体的编码解码方法
clear all;
% m=4;%每个符号比特数
n=255;%码字长度
k=223;%每组符号数
t=(n-k)/2;%码的纠正能力
nw=1; %处理的码字个数
% x=[0,1,2,3,4,5,6,7]; %输入的字符;字符个数与每组符号数相等。
x=[87 88 48 53 48 32 48 48 48 46 48 48 32 50 52 48 53 49 53 48 51 51 57 32 48 50 51 49 48 32 50 57 49 54 78 32 49 49 51 50 54 32 55 49 48 53 69 32 48 48 57 55];
x=[x zeros(1,223-length(x))];
% k=length(x);
% x=randi([0,255],1,223);
msgw=gf(x,8);
c=rsenc(msgw,n,k);%RS编码
%—————信道部分———————————
cnoisy=c;
%—————信道部分———————————
%% RS译码
[dc,nerrs,corrcode]= rsdec(cnoisy,n,k);
% [dc,nerrs,corrcode]= rsdec(out_data,n,k);
isequal(dc,msgw) & isequal(corrcode,c)
disp(['nerrs=',num2str(nerrs)]);
