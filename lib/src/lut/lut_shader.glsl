#ifdef VERT
#version 300 es
layout(location=0) in vec2 aPosition;
out vec2 vTexCoord;

void main() {
    vTexCoord = (aPosition + 1.0) * 0.5;
    gl_Position = vec4(aPosition, 0.0, 1.0);
}
#endif

#ifdef FRAG
#version 300 es
precision highp float;
precision highp sampler2D;
precision highp sampler3D;

in vec2 vTexCoord;
out vec4 fragColor;

uniform sampler2D uY;
uniform sampler2D uU;
uniform sampler2D uV;
uniform sampler3D uLut;
uniform float uMix;

vec3 yuv2rgb(float y, float u, float v) {
    float Y = y;
    float U = u - 0.5;
    float V = v - 0.5;
    
    return mat3(
        1.0,      0.0,      1.402,
        1.0, -0.344136, -0.714136,
        1.0,    1.772,      0.0
    ) * vec3(Y, U, V);
}

vec3 linearize(vec3 color) {
    return pow(color, vec3(2.2));
}

vec3 toSRGB(vec3 color) {
    return pow(color, vec3(1.0 / 2.2));
}

void main() {
    float y = texture(uY, vTexCoord).r;
    vec2 uvCoord = vTexCoord * 0.5;
    float u = texture(uU, uvCoord).r;
    float v = texture(uV, uvCoord).r;
    
    vec3 rgb = clamp(yuv2rgb(y, u, v), 0.0, 1.0);
    vec3 lutResult = texture(uLut, clamp(linearize(rgb), 0.0, 1.0)).rgb;
    vec3 finalColor = mix(rgb, toSRGB(lutResult), uMix);
    
    fragColor = vec4(finalColor, 1.0);
}
#endif
