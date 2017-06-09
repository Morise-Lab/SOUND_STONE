#ifndef WORLD_AUDIOIO_H_
#define WORLD_AUDIOIO_H_

#ifdef __cplusplus
extern "C" {
#endif
    
        //-----------------------------------------------------------------------------
    // wavread() read a .wav file.
    // The memory of output x must be allocated in advance.
    // Input:
    //   filename     : Filename of the input file.
    // Output:
    //   fs           : Sampling frequency [Hz]
    //   nbit         : Quantization bit [bit]
    //   x            : The output waveform.
    //-----------------------------------------------------------------------------
    void PlayWorld(const char* filename, int *fs, int *nbit, double *x);
    
#ifdef __cplusplus
}
#endif

#endif
