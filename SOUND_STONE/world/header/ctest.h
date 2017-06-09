//
//  ctest.h
//  PLAYSOUND
//
//  Created by 研究室 on 2016/04/24.
//  Copyright © 2016年 YUSUKE_WATANABE. All rights reserved.
//

#ifndef ctest_h
#define ctest_h
#ifdef __cplusplus
extern "C" {
#endif    
    typedef struct {
    double frame_period;
    int fs;
    
    double *f0;
    double *time_axis;
    int f0_length;
    
    double **spectrogram;
    double **aperiodicity;
    int fft_size;
} WorldParameters;
   WorldParameters execute_world(const char* inputFile , const char* outputFile,double pitch);
    void execute_Synthesis(WorldParameters world_parameters,const char* outputFile);
#ifdef __cplusplus
}
#endif
#endif /* ctest_h */
