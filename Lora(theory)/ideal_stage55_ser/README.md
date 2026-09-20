# Ideal Stage55-condition LoRa SER

This directory generates one independent ideal Doppler-compensation SER
curve for SF12 LoRa.  It uses the Stage55 physical configuration and source
functions, but never reads frozen performance data.

Run in MATLAB R2022a or newer:

```matlab
cd('D:/codex/Lora(theory)/ideal_stage55_ser');
report = run_ideal_ser_experiment();
```

The formal curve is evaluated directly from the exact noncoherent
dechirp-FFT AWGN probability integral.  Fresh Case A and Case B full-frame
Monte Carlo runs validate perfect samplewise Doppler cancellation; they do
not fit or alter the curve.
