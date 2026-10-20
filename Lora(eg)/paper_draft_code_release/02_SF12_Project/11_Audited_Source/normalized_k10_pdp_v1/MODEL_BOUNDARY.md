# Model boundary

The public elevation-angle implementation is used for the normalized Rician
small-scale convention:

`mu = sqrt(K/(2(K+1)))`, `sigma = sqrt(1/(2(K+1)))`, and
`g = N(mu,sigma) + j N(mu,sigma)`.

For K=10 this gives LOS power 10/11, diffuse power 1/11, and unit ensemble
power. The deterministic LOS phase is pi/4, matching the public code. The
public model's 30-GHz carrier, 600-km orbit, 25-MHz bandwidth, beamforming,
antenna gain, transmit power, FSPL, and atmospheric attenuation are not
copied because the user's waveform experiment fixes received SNR and uses
868 MHz, 550 km, and 125 kHz. Applying those macro-link terms again would
double-count the link budget.

The public code contains one flat coefficient per network snapshot and no
LoRa tapped-delay model. This experiment therefore registers one explicit
project adaptation: the fixed 1/11 diffuse power is divided between an
unresolved zero-delay cluster and four causal delayed clusters on the user's
8-us sample grid. This PDP is shared by SF7/SF12 and every condition. It is a
calibrated LoRa sensitivity model, not a parameter claimed to have been
measured or specified by the cited elevation paper.

There is no link margin. Total ensemble channel power remains one, noise is
set only by the nominal SNR, and realized packets are never normalized.

