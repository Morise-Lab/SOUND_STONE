//
//  ctest_c.h
//  SOUNDSTONE
//
//  Created by 研究室 on 2016/10/05.
//  Copyright © 2016年 YUSUKE_WATANABE. All rights reserved.
//

#ifndef ctest_c_h
#define ctest_c_h

#include <stdio.h>
#include "common.h"
#include "macrodefinitions.h"
//
//  ctest.h
//  PLAYSOUND
//
//  Created by 研究室 on 2016/04/24.
//  Copyright © 2016年 YUSUKE_WATANABE. All rights reserved.
//
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
    double* AddFrames(WorldParameters *world_parameters, int fs, int start , int length , double *y,int buffer_size);
    void Initializer(WorldParameters *world_parameters,int buffer_size);
#ifdef __cplusplus
}
#endif


#endif /* ctest_c_h */


