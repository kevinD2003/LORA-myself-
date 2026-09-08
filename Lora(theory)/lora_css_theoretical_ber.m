function ber = lora_css_theoretical_ber(sf, snrDb)
%LORA_CSS_THEORETICAL_BER Exact uncoded CSS BER for noncoherent AWGN.
%   BER = LORA_CSS_THEORETICAL_BER(SF, SNRDB) evaluates the same
%   dechirp-FFT detector used by the simulation. The correct-bin power is
%   noncentral exponential, while each wrong-bin power is exponential.

m = 2^sf;
snrDb = snrDb(:);
ber = zeros(size(snrDb));

for index = 1:numel(snrDb)
    noncentrality = m * 10^(snrDb(index)/10);
    integrationLimit = max(50, noncentrality + ...
        20*sqrt(noncentrality + 1) + 50);

    integrand = @(power) conditional_error(power, m) .* ...
        noncentral_power_pdf(power, noncentrality);
    ser = integral(integrand, 0, integrationLimit, ...
        'RelTol', 1e-8, 'AbsTol', 1e-12);

    % For natural binary labels, a uniformly selected wrong symbol differs
    % in m*SF/(2*(m-1)) bits on average.
    ber(index) = ser * m/(2*(m-1));
end
end

function probability = conditional_error(power, m)
% Stable evaluation of 1-(1-exp(-power))^(m-1).
probability = -expm1((m-1) .* log1p(-exp(-power)));
end

function density = noncentral_power_pdf(power, noncentrality)
% Scaled Bessel form avoids overflow in the noncentral-power density.
argument = 2*sqrt(noncentrality .* power);
density = exp(-(sqrt(power)-sqrt(noncentrality)).^2) .* ...
    besseli(0, argument, 1);
end
