void MainLight_half(float3 WorldPos, out half3 Direction, out half3 Color, out half DistanceAtten, out half ShadowAtten)
{
    #if SHADERGRAPH_PREVIEW
        Direction = half3(0.5, 0.5, 0);
        Color = 1;
        DistanceAtten = 1;
        ShadowAtten = 1;
    #else
        Light light = GetMainLight();
        Direction = light.direction;
        Color = light.color;
        DistanceAtten = light.distanceAttenuation;
        ShadowAtten = light.shadowAttenuation;
    #endif
}




void AdditionalLights_half(half3 WorldPosition, half3 WorlNormal, out half3 Color)
{
    #if SHADERGRAPH_PREVIEW
        Color = 1;
    #else

        Color = 0;

        int additionalLightsCount = GetAdditionalLightsCount();
        for (int i = 0; i < additionalLightsCount; ++i)
        {
            Light light = GetAdditionalLight(i, WorldPosition);

            half3 lightcolor = light.color;
            half attenuation = light.distanceAttenuation;

            attenuation = min(1,attenuation);
            
            Color += lightcolor * attenuation;

        }
        
    #endif
}