# LoRa_basic AWGN BER report

This self-contained script implements random LoRa CSS symbol sequences and extends them to SF7-SF12 BER simulation.

The model is uncoded LoRa CSS with perfect synchronization and complex AWGN only. BER detection is noncoherent dechirp-FFT peak selection.

Monte Carlo points use adaptive error-count stopping: 200 errors or 300000000 bits per SNR point. Smooth solid lines are the exact BER of the same detector; they are not empirical fits.

Simulation points: 325  
Total symbols: 348929869  
Total bits: 3187099991  
Elapsed time: 15.87 seconds  
