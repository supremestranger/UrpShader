Shader "Custom/Lambert" {
    Properties {
        _MainTex ("Diffuse", 2D) = "white" {}
        _Color ("Color", Color) = (1, 1, 1, 1)
    }
    
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline" 
            "IgnoreProjector" = "True" 
            "RenderType" = "Opaque"
        }
        LOD 100

        Pass {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ USE_LEGACY_LIGHTMAPS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float2 staticLightmapUv : TEXCOORD1;
                float2 dynamicLightmapUv : TEXCOORD2;
            }; 

            struct v2f {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float2 staticLightmapUv : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
#ifdef DYNAMICLIGHTMAP_ON
                float2 dynamicLightmapUv : TEXCOORD3;
#endif
            };

            half3 Lambert(half3 normal, half3 lightDir, half3 lightCol) {
                return max(0, dot(normal, lightDir)) * lightCol;
            }
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;
            
            v2f vert (appdata v) {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = v.normal;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.staticLightmapUv.xy = v.staticLightmapUv * unity_LightmapST.xy + unity_LightmapST.zw;
#if defined(DYNAMICLIGHTMAP_ON)
                o.dynamicLightmapUv.xy = v.dynamicLightmapUv * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
                return o;
            }
            
            float4 _Color;

            half4 frag (v2f i) : SV_Target {
                half3 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb;
                half3 diffuse = _Color.rgb * tex;
                half3 normal = normalize(i.normal);

                // lighting.
                half3 dirLightDirection = _MainLightPosition.xyz;
                half3 lighting = Lambert(normal, dirLightDirection, _MainLightColor.rgb);

                Light light = GetAdditionalLight(0, i.worldPos);
                lighting += Lambert(normal, light.direction.xyz, light.color.rgb * (light.distanceAttenuation * light.shadowAttenuation)) * _Color.rgb;
                
#if defined(DYNAMICLIGHTMAP_ON)
                half3 lm = SampleLightmap(i.staticLightmapUv, i.dynamicLightmapUv, i.normal);
#else
                half3 lm = SampleLightmap(i.staticLightmapUv, 0, i.normal);
#endif

                half4 res = half4((lighting + lm) * diffuse, 1);
                res.a = 1;
                return res;
            }
            ENDHLSL
        }
        
        Pass {
	        Name "ShadowCaster"
	        Tags { "LightMode"="ShadowCaster" }
        }
    }
}
