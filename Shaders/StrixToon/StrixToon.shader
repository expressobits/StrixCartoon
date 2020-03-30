Shader "ExpressoBits/StrixToon"
{
    Properties
    {

        // Specular vs Metallic workflow
        [HideInInspector] _WorkflowMode("WorkflowMode", Float) = 1.0

        [MainColor] _BaseColor("Color", Color) = (0.5,0.5,0.5,1)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _ToonRamp("Toon Ramp",2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        _SmoothnessTextureChannel("Smoothness texture channel", Float) = 0

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        _SpecColor("Specular", Color) = (0.2, 0.2, 0.2)
        _SpecGlossMap("Specular", 2D) = "white" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        // Blending state
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0

        _ReceiveShadows("Receive Shadows", Float) = 1.0

        // Editmode props
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0

    }

    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline" "IgnoreProjector" = "True"}
        LOD 300

        Pass
        {
            // "Lightmode" tag must be "UniversalForward" or not be defined in order for
            // to render objects.
            Name "StandardLit"
            Tags{"LightMode" = "UniversalForward"}

            Blend[_SrcBlend][_DstBlend]
            ZWrite[_ZWrite]
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard SRP library
            // All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            // unused shader_feature variants are stripped from build automatically
            #pragma shader_feature _NORMALMAP
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature _METALLICSPECGLOSSMAP
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature _OCCLUSIONMAP

            #pragma shader_feature _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature _GLOSSYREFLECTIONS_OFF
            #pragma shader_feature _SPECULAR_SETUP
            #pragma shader_feature _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Universal Render Pipeline keywords
            // When doing custom shaders you most often want to copy and past these #pragmas
            // These multi_compile variants are stripped from the build depending on:
            // 1) Settings in the LWRP Asset assigned in the GraphicsSettings at build time
            // e.g If you disable AdditionalLights in the asset then all _ADDITIONA_LIGHTS variants
            // will be stripped from build
            // 2) Invalid combinations are stripped. e.g variants with _MAIN_LIGHT_SHADOWS_CASCADE
            // but not _MAIN_LIGHT_SHADOWS are invalid and therefore stripped.
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            //#include "../../ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 uv           : TEXCOORD0;
                float2 uvLM         : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv                       : TEXCOORD0;
                float2 uvLM                     : TEXCOORD1;
                float4 positionWSAndFogFactor   : TEXCOORD2; // xyz: positionWS, w: vertex fog factor
                half3  normalWS                 : TEXCOORD3;

#if _NORMALMAP
                half3 tangentWS                 : TEXCOORD4;
                half3 bitangentWS               : TEXCOORD5;
#endif

#ifdef _MAIN_LIGHT_SHADOWS
                float4 shadowCoord              : TEXCOORD6; // compute shadow coord per-vertex for the main light
#endif
                float4 positionCS               : SV_POSITION;
            };

            sampler _ToonRamp;

            
half Ramped(half value)
{
    value = min(1,value);
    value = tex2D(_ToonRamp,float2(value,0));
    return value;
}

half3 MixFogColorD(real3 fragColor, real3 fogColor, real fogFactor)
{
#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    real fogIntensity = ComputeFogIntensity(fogFactor);
    fogIntensity = Ramped(fogIntensity);
    fragColor = lerp(fogColor, fragColor, fogIntensity);
#endif
    return fragColor;
}

half3 MixFogD(real3 fragColor, real fogFactor)
{
    return MixFogColorD(fragColor, unity_FogColor.rgb, fogFactor);
}

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output;
                // VertexPositionInputs contém posição em vários espaços (mundo, visualização, espaço de clipe homogêneo) 
                // Nosso compilador removerá todas as referências não utilizadas (digamos que você não use o espaço de visualização).
                // Portanto, há mais flexibilidade sem nenhum custo adicional com essa estrutura.
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

                // Semelhante a VertexPositionInputs, VertexNormalInputs conterá normal, tangente e bitangente 
                // no espaço do mundo. Se não for utilizado, será removido.
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                // Calcula o fator de neblina por vértice.
                float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

                // TRANSFORM_TEX é o mesmo que a antiga biblioteca de sombreadores.
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.uvLM = input.uvLM.xy * unity_LightmapST.xy + unity_LightmapST.zw;

                output.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);
                output.normalWS = vertexNormalInput.normalWS;

                // Aqui está a flexibilidade das estruturas de entrada. Nas variantes que não 
                // possuem um mapa normal definido tangentWS e bitangentWS não serão referenciadas e 
                // GetVertexNormalInputs está apenas convertendo normal de objeto para espaço no mundo
#ifdef _NORMALMAP
                output.tangentWS = vertexNormalInput.tangentWS;
                output.bitangentWS = vertexNormalInput.bitangentWS;
#endif

#ifdef _MAIN_LIGHT_SHADOWS
                // A sombra coord para a luz principal é calculada no vértice. Se as cascatas estiverem 
                // ativadas, o LWRP resolverá as sombras no espaço da tela e esta coord será a coordenação 
                // uv da textura da sombra do espaço da tela. Caso contrário, o LWRP resolverá as sombras no espaço claro (sem pré-profundidade e sem coleta de sombras). Nesse caso, shadowCoord será a posição no espaço claro.
                output.shadowCoord = GetShadowCoord(vertexInput);
#endif
                // Nós apenas usamos a posição homogênea do clipe da entrada do vértice
                output.positionCS = vertexInput.positionCS;

                return output;
            }

            half4 LitPassFragment(Varyings input) : SV_Target
            {
                // Os dados de superfície contêm albedo, metálico, especular, suavidade, oclusão, emissão e alfa 
                // InitializeStandarLitSurfaceData inicializa com base nas regras do shader padrão. 
                // Você pode escrever sua própria função para inicializar os dados da superfície do shader.

                SurfaceData surfaceData;
                InitializeStandardLitSurfaceData(input.uv, surfaceData);

#if _NORMALMAP
                half3 normalWS = TransformTangentToWorld(surfaceData.normalTS,
                half3x3(input.tangentWS, input.bitangentWS, input.normalWS));
#else
                half3 normalWS = input.normalWS;
#endif
                normalWS = normalize(normalWS);

#ifdef LIGHTMAP_ON
                // Normal é necessário no caso de mapas de luz direcionais
                half3 bakedGI = SampleLightmap(input.uvLM, normalWS);
#else
                // Amostras SH totalmente por pixel. Funções SampleSHVertex e SampleSHPixel
                // também são definidos caso você queira provar alguns termos por vértice.
                half3 bakedGI = SampleSH(normalWS);
#endif

                float3 positionWS = input.positionWSAndFogFactor.xyz;
                half3 viewDirectionWS = SafeNormalize(GetCameraPositionWS() - positionWS);

                // O BRDFData mantém reflexos difusos e especulares de conservação de energia e sua rugosidade. 
                // É fácil conectar seu próprio sombreamento. Você só precisa substituir a função LightingPhysicallyBased abaixo pela sua.
                BRDFData brdfData;
                InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

                // A estrutura de luz é fornecida pelo LWRP para abstrair variáveis do sombreador de luz. 
                // Ele contém a direção da luz, cor, distanceAttenuation e shadowAttenuation. 
                // O LWRP adota diferentes abordagens de sombreamento, dependendo da luz e da plataforma. 
                // Você nunca deve consultar variáveis de sombreador de luz no seu sombreador, use as funções 
                // GetLight para preencher essa estrutura de luz.

#ifdef _MAIN_LIGHT_SHADOWS
                // A luz principal é a luz direcional mais brilhante.
                // Está sombreada fora do loop de luz e possui um conjunto específico de variáveis 
                // e caminho de sombreamento, para que possamos ser o mais rápido possível no caso 
                // em que houver apenas uma única luz direcional. 
                //  Você pode passar opcionalmente um shadowCoord (calculado por vértice). 
                // Nesse caso, shadowAttenuation será calculado.
                Light mainLight = GetMainLight(input.shadowCoord);
#else
                Light mainLight = GetMainLight();
#endif
                // Misture GI difuso com reflexões do ambiente.
                half3 color = GlobalIllumination(brdfData, bakedGI, surfaceData.occlusion, normalWS, viewDirectionWS);

                // LightingPhysicallyBased calcula a contribuição direta da luz.
                color += LightingPhysicallyBased(brdfData, mainLight, normalWS, viewDirectionWS);


                // Loop de luzes adicionais
#ifdef _ADDITIONAL_LIGHTS
                // Retorna a quantidade de luzes que afetam o objeto que está sendo renderizado. 
                // Essas luzes são descartadas por objeto no renderizador avançado
                int additionalLightsCount = GetAdditionalLightsCount();
                for (int i = 0; i < additionalLightsCount; ++i)
                {
                    // Semelhante ao GetMainLight, mas é necessário um índice de loop for. 
                    // Isso calcula o índice de luz por objeto e mostra o buffer de luz de acordo 
                    // com a inicialização da estrutura Light. Se _ADDITIONAL_LIGHT_SHADOWS for definido, ele também calculará sombras.
                    Light light = GetAdditionalLight(i, positionWS);

                    // Mesmas funções usadas para proteger a luz principal.
                    light.distanceAttenuation = Ramped(light.distanceAttenuation);
                    color  += LightingPhysicallyBased(brdfData, light, normalWS, viewDirectionWS);
                }
#endif

                color += surfaceData.emission;

                float fogFactor = input.positionWSAndFogFactor.w;

                // Misture a cor do pixel com fogColor. Você pode opcionalmente usar o MixFogColor 
                // para substituir o fogColor por um personalizado.
                //fogFactor = Ramped(fogFactor);
                color = MixFogD(color, fogFactor);
                return half4(color, surfaceData.alpha);
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"

        UsePass "Universal Render Pipeline/Lit/DepthOnly"

        UsePass "Universal Render Pipeline/Lit/Meta"
    }

    //CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.LitShader"
}