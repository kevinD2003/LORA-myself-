function [fd t p el] = DopplerModelFunction(fc,h)

Re = earthRadius ;
%h  = 513e3;
%fc = 400.45e6;
a  = Re +h;
mu = 3.986004418e14;
c = physconst('lightspeed');
omega = sqrt(mu/(Re+h)^3);
varphi_max = acosd (Re/a);

varphi_o_vec = [0]; % If you want the zenith case only use varphi_o = 0;

for ctr=1:length(varphi_o_vec)
varphi_o = varphi_o_vec(ctr);
omega_t_max = acos(cosd(varphi_max)/cosd(varphi_o)); % See equation (2) in the paper. 
t=-omega_t_max/omega:omega_t_max/omega; % Devide Omega x t by omega to get the proper t vector
nu = - a*Re*omega/c * cosd(varphi_o).*sin(omega *t)./sqrt(a^2+Re^2-2*a*Re*cosd(varphi_o)*cos(omega*t));
%p = sqrt(a^2 + Re^2 -2*a*Re*cosd(omega_t_max) *cos(omega*t));
p = sqrt(a^2 + Re^2 -2*a*Re*cosd(varphi_o_vec) *cos(omega*t))
end
fd = fc.*nu;

%% el (elevation angle) is from equation (6) of https://ieeexplore.ieee.org/stamp/stamp.jsp?tp=&arnumber=9537682
    for k=1:length(p)
x = (h^2+2*h*Re - p(k)^2); 
y = 2*p(k)*Re;
        el(k) = asind(x/y);
    end

end