function distance = dreCircularSymbolDistance(a,b,alphabetSize)
%DRECIRCULARSYMBOLDISTANCE Minimum absolute distance on a cyclic alphabet.

delta = mod(double(a)-double(b)+alphabetSize/2,alphabetSize)-alphabetSize/2;
distance = abs(delta);
end

