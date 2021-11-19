//
//  Common.h
//  Simulation
//
//  Created by Jaap Wijnen on 25/05/2021.
//

#ifndef Common_h
#define Common_h


#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef struct {
    int count;
    float moveSpeed;
    float turnSpeed; //0...1
    float sensorDistance;
    float sensorAngle;
    float trailWeight;
    int sensorSize;
} AntVariables;

typedef struct {
    float diffuseRate;
    float decayRate;
} TrailVariables;

typedef NS_ENUM(NSInteger, BufferIndex)
{
    BufferIndexAntVariables     = 0,
    BufferIndexTrailVariables   = 1,
    BufferIndexParticleBuffer   = 2,
    BufferIndexCurrentTime      = 3,
    BufferIndexAntsUniforms     = 5
};

typedef NS_ENUM(NSInteger, TextureIndex)
{
    TextureIndexDrawable        = 0,
    TextureIndexAnts            = 1,
    TextureIndexCurrentTrails   = 2,
    TextureIndexPreviousTrails  = 3
};

struct ParticleUniforms {
    float width;
    float height;
};

#endif /* Common_h */
