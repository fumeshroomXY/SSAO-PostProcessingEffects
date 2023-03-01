
Shader "AO/ScreenSpaceAOEffect"
{
	Properties
	{
		_MainTex("Texture", 2D) = "black" {}
	}
		CGINCLUDE
#include "UnityCG.cginc"

		struct appdata
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};

	struct v2f
	{
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
		//viewRay表示相机空间下着色点的位置
		float3 viewRay : TEXCOORD1;
	};

#define MAX_SAMPLE_KERNEL_COUNT 32
	sampler2D _MainTex;
	sampler2D _CameraDepthNormalsTexture;
	float4x4 _InverseProjectionMatrix;
	float _DepthBiasValue;
	float4 _SampleKernelArray[MAX_SAMPLE_KERNEL_COUNT];
	float _SampleKernelCount;
	float _AOStrength;
	float _SampleKeneralRadius;

	float4 _MainTex_TexelSize;
	float4 _BlurRadius;
	float _BilaterFilterFactor;

	sampler2D _AOTex;

	float3 GetNormal(float2 uv)
	{
		float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);  //使用当前像素的纹理坐标对深度和法线进行采样
		//返回视角空间下的法线信息
		return DecodeViewNormalStereo(cdn);  //注意这个函数得到的法线信息直接是视角空间下的
	}

	half CompareNormal(float3 normal1, float3 normal2)
	{
		////_BilaterFilterFactor = [1.0, 0.8]
		return smoothstep(_BilaterFilterFactor, 1.0, dot(normal1, normal2));   
	}

	v2f vert_ao(appdata v)
	{
		v2f o;
		o.vertex = UnityObjectToClipPos(v.vertex);  //从模型空间转换到齐次裁剪空间，也就是透视除法之前的坐标
		o.uv = v.uv;    //深度纹理的uv坐标
		float4 clipPos = float4(v.uv * 2 - 1.0, 1.0, 1.0);   //这句的作用是？
		float4 viewRay = mul(_InverseProjectionMatrix, clipPos);  //将屏幕像素对应在摄像机远平面（Far plane）的点转换到剪裁空间（Clip space）。
		o.viewRay = viewRay.xyz / viewRay.w;
		return o;
	}

	fixed4 frag_ao(v2f i) : SV_Target
	{
		fixed4 col = tex2D(_MainTex, i.uv);

		float linear01Depth;
		float3 viewNormal;

		float4 cdn = tex2D(_CameraDepthNormalsTexture, i.uv);
		DecodeDepthNormal(cdn, linear01Depth, viewNormal); //视角空间下[0,1]范围内的线性深度值和视角空间下的法线信息
		float3 viewPos = linear01Depth * i.viewRay;	  //得到着色点在视角空间的位置
		viewNormal = normalize(viewNormal) * float3(1, 1, -1);   //？

		int sampleCount = _SampleKernelCount;

		float oc = 0.0;
		for (int i = 0; i < sampleCount; i++)
		{
			float3 randomVec = _SampleKernelArray[i].xyz;   //x = [-1,1], y = [-1,1], z = [0,1]
			//如果随机点的位置与法线反向，那么将随机方向取反，使之保证在法线半球
			randomVec = dot(randomVec, viewNormal) < 0 ? -randomVec : randomVec;

			float3 randomPos = viewPos + randomVec * _SampleKeneralRadius;   //半球上采样
			float3 rclipPos = mul((float3x3)unity_CameraProjection, randomPos);   //从视角空间转换到齐次裁剪空间
			float2 rscreenPos = (rclipPos.xy / rclipPos.z) * 0.5 + 0.5;    //[0,1]

			float randomDepth;
			float3 randomNormal;
			float4 rcdn = tex2D(_CameraDepthNormalsTexture, rscreenPos);
			DecodeDepthNormal(rcdn, randomDepth, randomNormal);                            //采样点的深度和着色点的深度比较
			float range = abs(randomDepth - linear01Depth) * _ProjectionParams.z < _SampleKeneralRadius ? 1.0 : 0.0; //_ProjectionParams.z 为 zFar，避免错误遮蔽
			float ao = randomDepth + _DepthBiasValue < linear01Depth ? 1.0 : 0.0;   //_DepthBiasValue = [0,0.002f]
			oc += ao * range;
		}
		oc /= sampleCount;
		oc = max(0.0, 1 - oc * _AOStrength);  //0代表全黑，1代表全白，oc取全黑或ao两者中较亮的值

		col.rgb = oc;
		return col;
	}

		fixed4 frag_blur(v2f i) : SV_Target
	{
		float2 delta = _MainTex_TexelSize.xy * _BlurRadius.xy;

		float2 uv = i.uv;
		float2 uv0a = i.uv - delta;
		float2 uv0b = i.uv + delta;
		float2 uv1a = i.uv - 2.0 * delta;
		float2 uv1b = i.uv + 2.0 * delta;
		float2 uv2a = i.uv - 3.0 * delta;
		float2 uv2b = i.uv + 3.0 * delta;

		float3 normal = GetNormal(uv);  //这里得到的法线信息都是视角空间下的
		float3 normal0a = GetNormal(uv0a);
		float3 normal0b = GetNormal(uv0b);
		float3 normal1a = GetNormal(uv1a);
		float3 normal1b = GetNormal(uv1b);
		float3 normal2a = GetNormal(uv2a);
		float3 normal2b = GetNormal(uv2b);

		fixed4 col = tex2D(_MainTex, uv);
		fixed4 col0a = tex2D(_MainTex, uv0a);
		fixed4 col0b = tex2D(_MainTex, uv0b);
		fixed4 col1a = tex2D(_MainTex, uv1a);
		fixed4 col1b = tex2D(_MainTex, uv1b);
		fixed4 col2a = tex2D(_MainTex, uv2a);
		fixed4 col2b = tex2D(_MainTex, uv2b);

		half w = 0.37004405286;   //7*7的高斯卷积核
		half w0a = CompareNormal(normal, normal0a) * 0.31718061674;  //输入的两个normal，越垂直结果就越接近于0，越平行就越接近于1
		half w0b = CompareNormal(normal, normal0b) * 0.31718061674;
		half w1a = CompareNormal(normal, normal1a) * 0.19823788546;
		half w1b = CompareNormal(normal, normal1b) * 0.19823788546;
		half w2a = CompareNormal(normal, normal2a) * 0.11453744493;
		half w2b = CompareNormal(normal, normal2b) * 0.11453744493;

		half3 result;
		result = w * col.rgb;   //越平行就越不是边缘，就可以模糊；越不平行就越是边缘，就不需要模糊
		result += w0a * col0a.rgb;
		result += w0b * col0b.rgb;
		result += w1a * col1a.rgb;
		result += w1b * col1b.rgb;
		result += w2a * col2a.rgb;
		result += w2b * col2b.rgb;

		result /= w + w0a + w0b + w1a + w1b + w2a + w2b;
		return fixed4(result, 1.0);
	}

		fixed4 frag_composite(v2f i) : SV_Target
	{
		fixed4 ori = tex2D(_MainTex, i.uv);
		fixed4 ao = tex2D(_AOTex, i.uv);
		ori.rgb *= ao.r;
		return ori;
	}

		ENDCG

		SubShader
	{

		Cull Off ZWrite Off ZTest Always

			//Pass 0 : Generate AO 
			Pass
		{
			CGPROGRAM
			#pragma vertex vert_ao
			#pragma fragment frag_ao
			ENDCG
		}

			//Pass 1 : Bilateral Filter Blur
			Pass
		{
			CGPROGRAM
			#pragma vertex vert_ao
			#pragma fragment frag_blur
			ENDCG
		}

			//Pass 2 : Composite AO
			Pass
		{
			CGPROGRAM
			#pragma vertex vert_ao
			#pragma fragment frag_composite
			ENDCG
		}
	}
}
