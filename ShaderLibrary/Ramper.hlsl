half Ramped(half value,sampler _rampTex)
{
    value = min(1,value);
    value = tex2D(_rampTex,float2(value,0));
    return value;
}

half RampedHard(half value)
{
    value = min(1,value);
    if(value > 0.5){
        value = 1;
    }else if(value > 0.25){
        value = 0.5;
    }else if(value > 0.125){
        value = 0.25;
    }else{
        value = 0;
    }
    return value;
}

void RampedColor_half(half3 Color,out half3 FinalColor)
{
    Color.r = RampedHard(Color.r);
    Color.g = RampedHard(Color.g);
    Color.b = RampedHard(Color.b);

    FinalColor = Color;
}