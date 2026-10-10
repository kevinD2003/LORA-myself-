%% QPSKCostas环算法验证
% Costas环算法验证
% 加入FIR低通滤波
% 加入同步判决

%%
% 参数设置

sinPointNum = 512;   % 一个正弦波内的采样点数
sinNum = 100;  % 仿真的正弦波数量

samSinPoint = 10; % 一个周期内的采样点
samPoint = 1000;%350;%%500;  % 总采样点数 

% phi = 511 * rand(1,1) * 2 * pi / 512;
phi = -30 * 2 * pi / 512;%0;%100 * 2 * pi / 512;

%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%生成随机信号
ran=randi([0,1],1,2*sinNum+1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%QPSK调制
%sigWave = zeros(1, sinPointNum * sinNum);%%生成空序列
sigWave_i = zeros(1, sinPointNum * sinNum);%%I路信号
sigWave_q = zeros(1, sinPointNum * sinNum);%%Q路信号

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%串并转换
j = 1:sinNum;
    ran_a(j) = ran (2*j-1);
    ran_b(j) = ran (2*j);

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%调制
for j = 1:sinNum
    i = (j-1) * sinPointNum : j * sinPointNum - 1;
    if (ran_a(j) == 1) 
       sigWave_i(i + 1) = cos(i * 2 * pi / sinPointNum);
    else
       sigWave_i(i + 1) = -cos(i * 2 * pi / sinPointNum);
             
    end
    if (ran_b(j) == 1)
       sigWave_q(i + 1) = sin(i * 2 * pi / sinPointNum);
    else
       sigWave_q(i + 1) = -sin(i * 2 * pi / sinPointNum);
    end
end
sigWave = sigWave_i-sigWave_q;%%相加
plot(sigWave, 'DisplayName', 'sigWave');
%%
% 噪声

EbN0 = 12.6;
snr = EbN0 - 10*log10(0.5*10);
sigWaveN = awgn(sigWave, snr, 'measured','db');
%    sigWaveN = sigWave;

%%
% 采样信号

i = 0 : samPoint - 1;
%samWave = sigWaveN(i * floor(sinPointNum / samSinPoint) + 1); % 与波形1有初始相差
samWave = sigWaveN(i * floor(sinPointNum / samSinPoint)+1);
% hold all;
% plot(sinWave2 - 3);
% subplot(4, 1, 2);
plot(samWave, 'DisplayName', 'samWave');

%%
% 本地载波
% 本地载波应该是根据输入信号由NCO（DDS）产生的
sxcos = zeros(1, samPoint);
sxsin = zeros(1, samPoint);
localCosWave = zeros(1, samPoint);
localSinWave = zeros(1, samPoint);
%dcos = zeros(1, 50);
%dsin = zeros(1, 50);
outcos = zeros(1, 500);
outsin = zeros(1, 500);
outview = zeros(1, 500);
d_f = zeros(1, 50);
d = 0;
outview_d_pre = zeros(1, samPoint);
outview_d = zeros(1, samPoint);

%%
for i = 0 : samPoint - 1
 
    %%本地载波生成，初始相差为phi
    localCosWave(i+1) = cos(i * floor(sinPointNum / samSinPoint) * 2 * pi / sinPointNum - phi + d);
    localSinWave(i+1) = sin(i * floor(sinPointNum / samSinPoint) * 2 * pi / sinPointNum - phi + d);

    %%相乘
    sxcos(i+1) = samWave(i+1) * localCosWave(i+1);
    sxsin(i+1) = samWave(i+1) * localSinWave(i+1);
   
    if (i >= 25) %&& (mod(i, 10) == 9)
       %%Num为滤波器抽头系数 ，进行滤波
        dcos = sxcos(i-24:i+1).*Num;
        dsin = sxsin(i-24:i+1).*Num;
        
        outcos(i) = 26*mean(dcos);
        outsin(i) = 26*mean(dsin);
        
        %%d_pre为相位反馈值，累加后得到D
        d_1  = sign(outsin(i));
        d_2  = sign(outcos(i));
        d_pre = 0.02*(d_1*outcos(i)-d_2*outsin(i));
%       d_3  = sign(outcos(i)+outsin(i));
%       d_4  = sign(outsin(i)-outcos(i));
%       out(i) = d_1*d_2*d_3*d_4; 
%       d_pre = 0.1*d_1*d_2*d_3*d_4;
%       d_pre = 26*26*dcos.*dsin.*(dcos+dsin).*(dsin-dcos);
        outview_d_pre(i) = mean(d_pre);
        %d_pre = 4 * outcos .* outsin;
        %d = d + d_f(50);
        outview_d(i) = d;
       d = d + d_pre;
    end
    %d(i+2) = 2 * mean(w1w2(1:i+1));
end

% subplot(4, 1, 1);
plot(localCosWave, 'DisplayName', 'localCosWave');
hold all;
i = 0 : samPoint - 1;
plot(cos(i * floor(sinPointNum / samSinPoint) * 2 * pi / sinPointNum), 'DisplayName', 'localWaveIdeal');
%%   第一次采用的码判决，只要找到判决点就很不错
% i=1;q=1;
% for j = 25 : 10 : samPoint-2
%     if (mean(outcos(j-9:j))>0)
%        i_out(i)=1;
%        i = i+1;
%     else
%         i_out(i)=0;
%         i = i+1;
%     end
%     if (mean(outsin(j-9:j)>0))
%         q_out(q)=1;
%         q = q+1;
%     else
%         q_out(q)=0;
%         q = q+1;
%     end
%     
% end
%%
%新的码同步判决方式
% PosNum = 0;
% NegNum = 0;
% SumNum = 0;
% i = 1;
% ran_a_out = zeros(1, 100);
%     for j =1 : samPoint-2
%         if (outcos(j)>0)
%             PosNum = PosNum +1;
%             NegNum = 0;
%         elseif (outcos(j)<=0);
%             NegNum = NegNum +1;
%             PosNum = 0;
%    
%         end
%         
%         if(PosNum>=7)
%             if(outcos(j+1)<0)
%                 ran_a_out(i) = 1;
%                 SumNum =0;
%                 PosNum =0;
%                 i=i+1;
%             else (PosNum>=10);
%                 ran_a_out(i) = 1;
%                 PosNum =0;
%                 SumNum =0;
%                 i=i+1;
%            
%             end
%         else(NegNum >= 7);
%             if(outcos(j+1)>1) 
%                 ran_a_out(i) = 0;
%                 NegNum =0;
%                 i=i+1;
%             elseif(NegNum>=10)
%                 ran_a_out(i) = 0;
%                 NegNum =0;
%                 SumNum =0;
%                 i=i+1;            
%             end
%                 SumNum =SumNum + 1;
%         end
%     
% %         
% %         if(NegNum>=7)
% %             if(outcos(j+1)>1)
% %                 ran_a_out(i) = 0;
% %                 NegNum =0;
% %                 i=i+1;
% %             elseif(NegNum>=10)
% %                 ran_a_out(i) = 0;
% %                 NegNum =0;
% %                 SumNum =0;
% %                 i=i+1;            
% %             end
% %         else
% %                 SumNum =SumNum + 1;
% %         end
%         
%         if (SumNum ==10)
%             
%             ran_a_out(i) = mean(outcos(j-SumNum+1:j));
%             SumNum =0;
%             PosNum =0;
%             NegNum =0;
%             i = i+1;
%         end
%     end
     %%
%第三个判决方案
logo = 0;
sum = 0;
t=0;
bs=0;
i_out =zeros (1,floor(samPoint/10));
keys = zeros (1,100);
for j =3 : samPoint-2
        if(((bs==0)||(sum<=1)||(sum==9))&&(logo==0)&&(outcos(j-2))<0&&(outcos(j-1))<0&&(outcos(j))>0&&(outcos(j+1))>0&&(outcos(j+2))>0) || ((outcos(j-2))>0&&(outcos(j-1))>0&&(outcos(j))<0&&(outcos(j))<0&&(outcos(j+1))<0&&(outcos(j+2))<0)
          if(t==0)
            logo=logo+1;
         
             if (sum<=1)
             sum=0;
             elseif(mean(outcos(j-9:j))>0)
                i_out(floor(j/10)) = 1;
                 keys(floor(j/10)) = j;
             elseif(mean(outcos(j-9:j))<0)
                i_out(floor(j/10)) = 0;
                 keys(floor(j/10)) = j;
             
%              i_out(floor(j/10)) = mean(outcos(j-sum:j-1));
            
             sum = 0;
             end
                 keys(floor(j/10)) = j;
          bs=1;
          end
         end
              

        
        
        if(logo>0)
            t =t+1;
            num=0;
            logo =logo+1;
            if(mod(t, 10) == 9)
               if(mean(outcos(j-9:j))>0)
                i_out(floor(j/10)) = 1;
                 keys(floor(j/10)) = j;
               else
                i_out(floor(j/10)) = 0;
                 keys(floor(j/10)) = j;
               end
            end
            if(t==49)
                t=0;
                logo=0;
            end
        end
        
        if(logo==0)%&&(bs==0)
            sum=sum+1;
            if(sum==10)
                if(mean(outcos(j-9:j))>0)
                %i_out(floor(j/10)) = mean(outcos(j-9:j));
                i_out(floor(j/10)) = 1;
                else
                    i_out(floor(j/10)) = 0;
                end
                sum = 0;
            end
        end
        
%         if(logo==0)&&(bs~=0)
%           sum = sum +1;
%           if(sum=10)
                
            
        
end
