#include <metal_stdlib>
using namespace metal;
#import "Common.h"

struct Ant {
    float2 position;
    float angle;
};

float rand(int x, int y, int z)
{
    int seed = x + y * 57 + z * 241;
    seed= (seed<< 13) ^ seed;
    return (( 1.0 - ( (seed * (seed * seed * 15731 + 789221) + 1376312589) & 2147483647) / 1073741824.0f) + 1.0f) / 2.0f;
}

kernel void generateAnts(uint id [[ thread_position_in_grid ]],
                             device Ant *ants [[ buffer(BufferIndexParticleBuffer) ]],
                             constant ParticleUniforms &uniforms [[ buffer(BufferIndexAntsUniforms) ]])
{
    device Ant &ant = ants[id];
    
    float distance = uniforms.height / 4;
    float angle = rand(id, id + id % 13, id + id % 5) * 2 * M_PI_F;
    float x = cos(angle) * distance + uniforms.width / 2;
    float y = sin(angle) * distance + uniforms.height / 2;
    
    ant.angle = angle;
    ant.position = float2(x, y);
}

//constant float moveSpeed = 2;
//constant float turnSpeed = 0.1; //0...1
//constant int sensorSize = 3;
//constant float sensorDistance = 7.0;
//constant float sensorAngle = 0.7;
//constant float trailWeight = 0.3;
//constant float diffuseRate = 0.2;
//constant float decayRate = 0.003;

uint hash(uint state) {
    state ^= 2747636419u;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    return state;
}

float scaleToRange01(uint state) {
    return state / 4294967295.0;
}

void write3x3(texture2d<half, access::write> texture,
              half4 color,
              uint2 position) {
    texture.write(color, position);
    texture.write(color, position + uint2( 1, 0));
    texture.write(color, position + uint2( 0, 1));
    texture.write(color, position - uint2( 1, 0));
    texture.write(color, position - uint2( 0, 1));
    texture.write(color, position + uint2(-1, 1));
    texture.write(color, position - uint2(-1, 1));
    texture.write(color, position + uint2( 1,-1));
    texture.write(color, position - uint2( 1,-1));
}

float sense(Ant ant, float sensorAngleOffset, texture2d<half, access::read> trail, AntVariables antVariables) {
    float sensorAngle = ant.angle + sensorAngleOffset;
    float2 sensorPosition = ant.position + float2(cos(sensorAngle), sin(sensorAngle)) * antVariables.sensorDistance;
    
    int sensorIndexX = (int) sensorPosition.x;
    int sensorIndexY = (int) sensorPosition.y;
    
    float sum = 0;
    
    int sensorSize = antVariables.sensorSize;
    
    for (int offsetX = -sensorSize; offsetX <= sensorSize; offsetX++) {
        for (int offsetY = -sensorSize; offsetY <= sensorSize; offsetY++) {
            int sampleX = min(trail.get_width() - 1, uint(max(0, sensorIndexX + offsetX)));
            int sampleY = min(trail.get_height() - 1, uint(max(0, sensorIndexY + offsetY)));
            sum += trail.read(uint2(sampleX, sampleY)).r;
        }
    }
    
    return sum;
}

kernel void resetAnts(texture2d<half, access::write> output [[ texture(TextureIndexAnts) ]],
                      uint2 id [[ thread_position_in_grid ]]) {
    output.write(half4(0.0), id);
}

kernel void decay(texture2d<half, access::read> inputTrail [[ texture(TextureIndexPreviousTrails) ]],
                  texture2d<half, access::write> outputTrail [[ texture(TextureIndexCurrentTrails) ]],
                  constant TrailVariables &trailVariables [[ buffer(BufferIndexTrailVariables) ]],
                  uint2 id [[ thread_position_in_grid ]]) {
    // 3x3 blur
    float sum = 0;
    half4 color = inputTrail.read(id);
    float originalColor = color.r;
    for (int offsetX = -1; offsetX <= 1; offsetX++) {
        for (int offsetY = -1; offsetY <= 1; offsetY++) {
            int xLoc = id.x + offsetX;
            int yLoc = id.y + offsetY;
            int sampleX = min(int(inputTrail.get_width()) - 1, max(0, xLoc));
            int sampleY = min(int(inputTrail.get_height()) - 1, max(0, yLoc));
            sum += inputTrail.read(uint2(sampleX, sampleY)).r;
        }
    }
    
    float blurredColor = sum / 9;
    blurredColor = originalColor * (1 - trailVariables.diffuseRate) + blurredColor * trailVariables.diffuseRate;
    color.r = max(0.0, blurredColor - trailVariables.decayRate);
    outputTrail.write(color, id);
}

kernel void combine(texture2d<half, access::write> output [[ texture(TextureIndexDrawable) ]],
                    texture2d<half, access::read> ants [[ texture(TextureIndexAnts) ]],
                    texture2d<half, access::read> trail [[ texture(TextureIndexCurrentTrails) ]],
                    uint2 id [[ thread_position_in_grid ]]) {
    half4 antColor = ants.read(id);
    half4 trailColor = trail.read(id);
    
    half4 color = half4(max(antColor.r, trailColor.r), antColor.g, antColor.b, antColor.a);
    output.write(color, id);
}

kernel void updateAntsAndTrail(
    texture2d<half, access::write> antsOutput [[ texture(TextureIndexAnts) ]],
    texture2d<half, access::write> trail [[ texture(TextureIndexCurrentTrails) ]],
    texture2d<half, access::read> previousTrail [[ texture(TextureIndexPreviousTrails) ]],
    constant AntVariables &antVariables [[ buffer(BufferIndexAntVariables) ]],
    device Ant *ants [[ buffer(BufferIndexParticleBuffer) ]],
    constant uint& time [[ buffer(BufferIndexCurrentTime) ]],
    uint id [[ thread_position_in_grid ]]
) {
    Ant ant;
    ant = ants[id];
    
    uint random = hash(ant.position.y * (uint)trail.get_width() + ant.position.x + hash(id + time * 100000));
    
    float weightForward = sense(ant, 0, previousTrail, antVariables);
    float weightLeft = sense(ant, antVariables.sensorAngle, previousTrail, antVariables);
    float weightRight = sense(ant, -antVariables.sensorAngle, previousTrail, antVariables);
    
    float randomSteerStrength = scaleToRange01(random);
    float actualTurnSpeed = antVariables.turnSpeed * 2 * 3.1415;
    
    if (weightForward > weightLeft && weightForward > weightRight) {
        
    } else if (weightForward < weightLeft && weightForward < weightRight) {
        ant.angle += actualTurnSpeed * (randomSteerStrength - 0.5) * 2;
    } else if (weightRight > weightLeft) {
        ant.angle -= randomSteerStrength * actualTurnSpeed;
    } else if (weightLeft > weightRight) {
        ant.angle += randomSteerStrength * actualTurnSpeed;
    }
    
    // check new position
    float2 direction = float2(cos(ant.angle), sin(ant.angle));
    float2 newPosition = ant.position + direction * antVariables.moveSpeed;
  
    // keep position within bounds
    if (newPosition.x < 0 || newPosition.x >= antsOutput.get_width()) {
        ant.angle = -ant.angle + 3.1415;
        newPosition.x = min(float(antsOutput.get_width()) - 1, max(0.0, newPosition.x));
        newPosition.y = min(float(antsOutput.get_height()) - 1, max(0.0, newPosition.y));
    }
    if (newPosition.y < 0 || newPosition.y >= antsOutput.get_height()) {
        ant.angle = -ant.angle;
        newPosition.x = min(float(antsOutput.get_width()) - 1, max(0.0, newPosition.x));
        newPosition.y = min(float(antsOutput.get_height()) - 1, max(0.0, newPosition.y));
    }

    uint2 previousPosition = uint2(ant.position);
    half4 previousColor = previousTrail.read(previousPosition);
    previousColor.r = min(1.0, previousColor.r + antVariables.trailWeight);
    //trail.write(previousColor, previousPosition);
    write3x3(trail, previousColor, previousPosition);
  
    ant.position = newPosition;
    ants[id] = ant;

    uint2 location = uint2(ant.position);
    half4 color = half4(1.0);
    
    //antsOutput.write(color, location);
    write3x3(antsOutput, color, location);
}
