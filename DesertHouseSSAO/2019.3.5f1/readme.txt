注：此文件夹下的c#脚本和shader文件的实现过程环境：
①  Unity版本：Unity 2019.3.5f1；
②  场景中的项目为透视模式；
③  相机渲染路径为：Forward，如果设置为Deferred渲染路径，则由对应的g-buffer生成，在shader中作为全局变量访问；
④  使用OnRenderImage（）来处理后期，进而实现SSAO；
⑤  在Unity2018版本及以下的素材中，将脚本拖拽到camera上即可使用；
⑥  此版本相较于2018.4.36f1文件夹下的版本优化了随机向量生成TBN空间问题，错误遮蔽问题，AO权重问题，详细说明参考https://zhuanlan.zhihu.com/p/533587132?