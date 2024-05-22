CG course project. Based on Unity Shader and GPU calculation, the program uses screen-space information to determine the amount of occlusion by darkening surfaces that are close to each other. 
Uses a scene's depth buffer in screen-space to reconstruct the coordinates of each fragment in camera space. 
Obtains the occlusion factor by taking multiple depth samples in a normal-oriented hemisphere sample kernel surrounding the fragment position and compare each of the samples with the current fragment's depth value. 
Blurs the AO texture through a bilateral filter to reduce noises and preserve edges. 
Analyzes the costs and compares the results.
For more information, you can refer to https://zhuanlan.zhihu.com/p/533587132
