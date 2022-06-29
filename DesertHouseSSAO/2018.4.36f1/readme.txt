注：此文件夹下的c#脚本和shader文件的实现过程环境：
①  Unity版本：Unity 2018.4.36f1；
②  场景中的项目为透视模式；
③  相机渲染路径为：Forward，如果设置为Deferred渲染路径，则由对应的g-buffer生成，在shader中作为全局变量访问；
④  使用OnRenderImage（）来处理后期，进而实现SSAO；
⑤  在Unity2018版本及以下的素材中，将脚本拖拽到camera上即可使用。
⑦  如果仅显示AO时画面全白，调小camera的远平面值即可（默认为1000）
