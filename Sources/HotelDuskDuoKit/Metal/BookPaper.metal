#include <metal_stdlib>
using namespace metal;

struct PaperUniforms {
    float4 viewport; // Width, height, display scale, material pass.
    float4 material; // Hinge degrees, settling flex, right-hand page, stable seed.
};
struct PaperVertex { float4 position [[position]]; float2 uv; };
vertex PaperVertex bookPaperVertex(uint id [[vertex_id]]) {
    const float2 points[3] = {float2(-1,-1),float2(3,-1),float2(-1,3)};
    float2 p = points[id];
    return {float4(p,0,1),float2((p.x+1)*0.5,1-(p.y+1)*0.5)};
}
static float hashPaper(float2 p) {
    float3 q = fract(float3(p.xyx) * float3(0.1031,0.1030,0.0973));
    q += dot(q,q.yzx+33.33);
    return fract((q.x+q.y)*q.z);
}
static float pulpNoise(float2 p) {
    float2 i=floor(p), f=fract(p); f=f*f*(3-2*f);
    return mix(mix(hashPaper(i),hashPaper(i+float2(1,0)),f.x),
               mix(hashPaper(i+float2(0,1)),hashPaper(i+1),f.x),f.y);
}
static float sheetHeight(float2 uv, float closed, float flex) {
    float bow = closed*0.025*exp(-uv.x*7.0);
    float settle = flex*0.008*sin(uv.x*M_PI_F)*sin(uv.y*2.1+0.5);
    float corner = flex*0.005*pow(uv.x,5.0)*pow(uv.y,6.0);
    return bow+settle+corner;
}
fragment float4 bookPaperFragment(PaperVertex in [[stage_in]],
                                 constant PaperUniforms &u [[buffer(0)]]) {
    float2 uv=clamp(in.uv,0.0,1.0);
    float closed=1-clamp(u.material.x/180.0,0.0,1.0);
    float flex=clamp(u.material.y,-1.0,1.0);
    float seed=u.material.w;
    if (u.viewport.w < 0.5) {
        float2 px=uv*u.viewport.xy/max(u.viewport.z,1.0);
        float tooth=hashPaper(floor(px*1.8)+seed)-0.5;
        float fibres=pulpNoise(px*float2(0.38,3.8)+seed)-0.5;
        float density=pulpNoise(px/75.0+seed)-0.5;
        float edge=min(min(uv.x,1-uv.x),min(uv.y,1-uv.y));
        float oxidation=exp(-edge*38.0)*(0.025+0.035*pulpNoise(px/19.0));
        float3 stock=float3(0.934,0.895,0.793)+tooth*0.038+fibres*0.018+density*0.025;
        stock-=oxidation*float3(0.45,0.65,0.9);
        // Sparse inclusions in cheap wood-pulp stock, fixed to each sheet.
        float2 cell=floor(px/11.0);
        float2 fleck=fract(px/11.0)-float2(hashPaper(cell+seed),hashPaper(cell+seed+37));
        float foxing=(1-smoothstep(0.015,0.085,length(fleck)))
            *step(0.93,hashPaper(cell+seed+91))*(0.035+0.09*exp(-edge*14));
        stock-=foxing*float3(0.45,0.65,0.8);
        return float4(clamp(stock,0.0,1.0),1);
    }
    if (u.viewport.w < 1.5) {
        float2 sheet=float2(u.material.z>0.5 ? uv.x:1-uv.x,uv.y);
        const float step=0.002;
        float h=sheetHeight(sheet,closed,flex);
        float dx=(sheetHeight(sheet+float2(step,0),closed,flex)-h)/step;
        float dy=(sheetHeight(sheet+float2(0,step),closed,flex)-h)/step;
        float3 normal=normalize(float3(-dx,-dy,1));
        float3 light=normalize(float3(-0.35,-0.4,1));
        float lambert=dot(normal,light)/light.z;
        float shadow=(0.025+closed*0.09)*exp(-sheet.x*22.0);
        float illumination=clamp(lambert-shadow,0.82,1.08);
        if (illumination<=1) {
            float alpha=1-illumination;
            return float4(float3(0.12,0.085,0.04)*alpha,alpha);
        }
        float alpha=min(0.08,(illumination-1)*0.6);
        return float4(float3(1,0.99,0.94)*alpha,alpha);
    }
    if (u.viewport.w > 2.5 && u.viewport.w < 3.5) {
        // Uncoated photographic mounting card, slightly brighter than the page.
        float2 px=uv*u.viewport.xy;
        float grain=hashPaper(floor(px)+seed)-0.5;
        float edge=min(min(uv.x,1-uv.x),min(uv.y,1-uv.y));
        float wear=exp(-edge*85)*(0.025+0.025*pulpNoise(px/13+seed));
        float3 card=float3(0.974,0.951,0.879)+grain*0.025-wear*float3(0.5,0.65,0.8);
        return float4(card,1);
    }
    if (u.viewport.w > 3.5) {
        // Serrated ends and adhesive mottling on translucent archival tape.
        float2 px=uv*u.viewport.xy;
        float tearLeft=0.025+0.055*hashPaper(float2(floor(px.y/3),seed));
        float tearRight=0.025+0.055*hashPaper(float2(floor(px.y/3),seed+51));
        float edge=min(uv.x-tearLeft,1-uv.x-tearRight);
        float mask=smoothstep(0.0,0.008,edge)*smoothstep(0.0,0.045,min(uv.y,1-uv.y));
        float fibres=pulpNoise(px*float2(0.12,2.2)+seed);
        float glue=pulpNoise(px/10+seed);
        float alpha=mask*(0.49+glue*0.18+fibres*0.08);
        float3 tape=float3(0.79,0.67,0.42)+fibres*0.08+glue*0.04;
        return float4(tape*alpha,alpha);
    }
    // A narrow curved valley at the physical binding, not a flat black divider.
    float x=abs(uv.x-0.5)*2;
    float valley=exp(-x*x*14.0)*(0.28+closed*0.35);
    float crease=exp(-x*160.0)*0.2;
    float ridge=exp(-pow((x-0.44)/0.14,2.0))*0.10;
    float grain=(hashPaper(floor(uv*u.viewport.xy)+seed)-0.5)*0.012;
    float alpha=clamp(valley+crease+grain-ridge,0.0,0.8)*(1-smoothstep(0.85,1.0,x));
    return float4(float3(0.085,0.065,0.035)*alpha,alpha);
}
