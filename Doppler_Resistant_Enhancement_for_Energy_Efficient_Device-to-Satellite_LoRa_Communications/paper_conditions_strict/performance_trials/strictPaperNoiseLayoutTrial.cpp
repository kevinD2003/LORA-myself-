#include "mex.h"
#define NOMINMAX
#include <windows.h>
#include <omp.h>
#include <vector>
#include <cmath>
#include <algorithm>

// Direct transmitter IQ -> Hann/dechirp -> 4x FFT -> ten-point centroid.
// MATLAB supplies sample-level AWGN from independent per-packet seeds.
// Uses a separately versioned FFTW3 library, with one FFT plan per worker.
struct Complex { double real,imag; };
using Plan=void*;
using Allocate=void* (__cdecl *)(size_t);
using Release=void (__cdecl *)(void*);
using MakePlan=Plan (__cdecl *)(int,Complex*,Complex*,int,unsigned);
using Execute=void (__cdecl *)(Plan);
using Destroy=void (__cdecl *)(Plan);
struct Engine {
    int m=0,threads=0,length=0;
    HMODULE library=nullptr;
    Allocate allocate=nullptr;Release release=nullptr;MakePlan make=nullptr;
    Execute execute=nullptr;Destroy destroy=nullptr;
    std::vector<Complex*> buffers;
    std::vector<Plan> plans;
    std::vector<Complex> rotation,down,twiddle;
    std::vector<double> window;
    std::vector<int> reversed;
};
static Engine engine;
static void clearPlans(){
    for(auto plan:engine.plans)if(plan)engine.destroy(plan);
    for(auto buffer:engine.buffers)if(buffer)engine.release(buffer);
    engine.plans.clear();engine.buffers.clear();engine.m=0;engine.threads=0;
}

static void initialize(int m,int threads,const mxArray* path){
    if(!engine.library){
        char* name=mxArrayToString(path);
        if(!name)mexErrMsgIdAndTxt("StrictPaper:NativeLibrary","Invalid FFTW path.");
        engine.library=LoadLibraryA(name);mxFree(name);
        if(!engine.library)mexErrMsgIdAndTxt("StrictPaper:NativeLibrary","Cannot load the pinned FFTW library.");
        engine.allocate=reinterpret_cast<Allocate>(GetProcAddress(engine.library,"fftw_malloc"));
        engine.release=reinterpret_cast<Release>(GetProcAddress(engine.library,"fftw_free"));
        engine.make=reinterpret_cast<MakePlan>(GetProcAddress(engine.library,"fftw_plan_dft_1d"));
        engine.execute=reinterpret_cast<Execute>(GetProcAddress(engine.library,"fftw_execute"));
        engine.destroy=reinterpret_cast<Destroy>(GetProcAddress(engine.library,"fftw_destroy_plan"));
        if(!engine.allocate||!engine.release||!engine.make||!engine.execute||!engine.destroy)
            mexErrMsgIdAndTxt("StrictPaper:NativeLibrary","Missing FFTW3 API functions.");
        // Keep the MEX/library pinned until process shutdown. Releasing a
        // foreign FFT DLL from a MATLAB shutdown callback races DLL/thread
        // teardown on R2022a. The bounded plans are reclaimed by the OS.
        mexLock();
    }
    if(engine.m==m && engine.threads==threads)return;
    clearPlans();
    engine.m=m;engine.threads=threads;engine.length=4*m;
    for(int thread=0;thread<threads;++thread){
        auto* buffer=static_cast<Complex*>(engine.allocate(sizeof(Complex)*4*m));
        if(!buffer)mexErrMsgIdAndTxt("StrictPaper:NativeMemory","Cannot allocate FFT buffer.");
        auto plan=engine.make(4*m,buffer,buffer,-1,0U);
        if(!plan){engine.release(buffer);mexErrMsgIdAndTxt("StrictPaper:NativePlan","Cannot create FFTW plan.");}
        engine.buffers.push_back(buffer);engine.plans.push_back(plan);
    }
    engine.rotation.resize(m);engine.down.resize(m);engine.window.resize(m);
    engine.twiddle.resize(2*m);engine.reversed.resize(4*m);
    const double pi=std::acos(-1.0);
    for(int n=0;n<m;++n){
        const double a=2*pi*n/m;
        engine.rotation[n]={std::cos(a),std::sin(a)};
        const double d=-2*pi*(double(n)*n/(2*m)-double(n)/2);
        engine.down[n]={std::cos(d),std::sin(d)};
        engine.window[n]=0.5-0.5*std::cos(a);
    }
    for(int k=0;k<2*m;++k){
        const double a=-2*pi*k/(4*m);
        engine.twiddle[k]={std::cos(a),std::sin(a)};
    }
    int bits=0;for(int n=4*m;n>1;n>>=1)++bits;
    for(int n=0;n<4*m;++n){
        int input=n,target=0;
        for(int bit=0;bit<bits;++bit){target=(target<<1)|(input&1);input>>=1;}
        engine.reversed[n]=target;
    }
}

static void forward(Complex* buffer){
    const int length=engine.length;
    // Input is zero padded from m to 4m. The first two FFT stages repeat
    // each nonzero bit-reversed sample four times; initialize these below.
    for(int width=8;width<=length;width<<=1){
        const int half=width/2,stride=length/width;
        for(int start=0;start<length;start+=width){
            for(int j=0;j<half;++j){
                const auto w=engine.twiddle[j*stride];
                const auto a=buffer[start+j],b=buffer[start+j+half];
                const double re=b.real*w.real-b.imag*w.imag;
                const double im=b.real*w.imag+b.imag*w.real;
                buffer[start+j]={a.real+re,a.imag+im};
                buffer[start+j+half]={a.real-re,a.imag-im};
            }
        }
    }
}

void mexFunction(int nlhs,mxArray* plhs[],int nrhs,const mxArray* prhs[]){
    if(nrhs!=5 || nlhs<1 || nlhs>3)
        mexErrMsgIdAndTxt("StrictPaper:NativeArguments","Need symbols, template, noise, threads, FFTW path.");
    if(!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0]) ||
        !mxIsDouble(prhs[1]) || !mxIsComplex(prhs[1]) ||
        !mxIsDouble(prhs[2]) || !mxIsComplex(prhs[2]) ||
        !mxIsDouble(prhs[3]) || mxIsComplex(prhs[3]) || mxGetNumberOfElements(prhs[3])!=1)
        mexErrMsgIdAndTxt("StrictPaper:NativeShape","Expected double symbols and complex double IQ/noise.");
    const size_t symbolCount=mxGetM(prhs[0]),replicates=mxGetN(prhs[0]);
    const int m=static_cast<int>(mxGetM(prhs[1]));
    const size_t rows=symbolCount*replicates;
    const double requestedThreads=mxGetScalar(prhs[3]);
    if(!std::isfinite(requestedThreads) || requestedThreads<1 || requestedThreads>12 || requestedThreads!=std::floor(requestedThreads))
        mexErrMsgIdAndTxt("StrictPaper:NativeShape","Invalid thread count.");
    const int threads=static_cast<int>(requestedThreads);
    if(m<2 || m>16384 || (m&(m-1))!=0 || rows==0 || mxGetN(prhs[1])!=symbolCount ||
        mxGetM(prhs[2])!=symbolCount || mxGetNumberOfElements(prhs[2])!=size_t(m)*rows)
        mexErrMsgIdAndTxt("StrictPaper:NativeShape","Inconsistent symbols, IQ template or noise dimensions.");
    const double* symbols=mxGetDoubles(prhs[0]);
    for(size_t row=0;row<rows;++row)
        if(!std::isfinite(symbols[row]) || symbols[row]<0 || symbols[row]>=m || symbols[row]!=std::floor(symbols[row]))
            mexErrMsgIdAndTxt("StrictPaper:NativeSymbol","Invalid LoRa symbol.");
    initialize(m,threads,prhs[4]);
    const auto* templateIQ=mxGetComplexDoubles(prhs[1]);
    const auto* noise=mxGetComplexDoubles(prhs[2]);
    std::vector<Complex> ordered(rows*static_cast<size_t>(m));
    #pragma omp parallel for schedule(static) num_threads(threads)
    for(long long rep=0;rep<static_cast<long long>(replicates);++rep){
        for(int firstN=0;firstN<m;firstN+=64){
            for(size_t firstRow=0;firstRow<symbolCount;firstRow+=8){
                for(size_t s=firstRow;s<std::min(firstRow+8,symbolCount);++s){
                    for(int n=firstN;n<std::min(firstN+64,m);++n){
                        const auto value=noise[rep*symbolCount*m+s+n*symbolCount];
                        ordered[(rep*symbolCount+s)*m+n]={value.real,value.imag};
                    }
                }
            }
        }
    }
    plhs[0]=mxCreateDoubleMatrix(rows,1,mxREAL);double* raw=mxGetDoubles(plhs[0]);
    double* peakOut=nullptr;mxComplexDouble* iqOut=nullptr;
    if(nlhs>1){plhs[1]=mxCreateDoubleMatrix(rows,1,mxREAL);peakOut=mxGetDoubles(plhs[1]);}
    if(nlhs>2){plhs[2]=mxCreateDoubleMatrix(m,rows,mxCOMPLEX);iqOut=mxGetComplexDoubles(plhs[2]);}
    #pragma omp parallel for schedule(static) num_threads(threads)
    for(long long r=0;r<static_cast<long long>(rows);++r){
        const size_t row=static_cast<size_t>(r);
        const int thread=omp_get_thread_num(),symbol=static_cast<int>(symbols[row]);
        auto* buffer=engine.buffers[thread];
        const auto* tx=templateIQ+(row%symbolCount)*m;
        const auto* noiseRow=ordered.data()+row*m;
        for(int n=0;n<m;++n){
            const auto rot=engine.rotation[(symbol*n)&(m-1)];
            const auto sampleNoise=noiseRow[n];
            const double re=tx[n].real*rot.real-tx[n].imag*rot.imag+sampleNoise.real;
            const double im=tx[n].real*rot.imag+tx[n].imag*rot.real+sampleNoise.imag;
            if(iqOut)iqOut[row*m+n]={re,im};
            const auto d=engine.down[n];const double w=engine.window[n];
            buffer[n]={(re*d.real-im*d.imag)*w,(re*d.imag+im*d.real)*w};
        }
        for(int n=m;n<4*m;++n)buffer[n]={0,0};
        engine.execute(engine.plans[thread]);
        int peak=0;double peakPower=-1;
        for(int k=0;k<4*m;++k){
            const double power=buffer[k].real*buffer[k].real+buffer[k].imag*buffer[k].imag;
            if(power>peakPower){peak=k;peakPower=power;}
        }
        double numerator=0,denominator=0;
        for(int offset=-4;offset<=5;++offset){
            const int unwrapped=peak+offset,k=unwrapped&(4*m-1);
            const double weight=std::hypot(buffer[k].real,buffer[k].imag);
            numerator+=unwrapped*weight;denominator+=weight;
        }
        double centroid=numerator/std::max(denominator,2.220446049250313e-16)/4;
        centroid=std::fmod(centroid,m);if(centroid<0)centroid+=m;
        raw[row]=centroid;if(peakOut)peakOut[row]=double(peak)/4;
    }
}
