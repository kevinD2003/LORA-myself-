% input=[1 0 1 1 0 1 0 1 0 1 0 0 0 1 1 ];%输入为二进制
input=[1 0 0];
n=2;k=1;L=7;% 表明是（2，1，7）编码
gen=[171,133];%编码多项式，217的编码多项式为（171，133）；
%生成卷积码
trellis = poly2trellis(L,gen);
code_data = convenc(input,trellis);
