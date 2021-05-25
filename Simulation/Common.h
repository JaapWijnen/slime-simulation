//
//  Common.h
//  Simulation
//
//  Created by Jaap Wijnen on 25/05/2021.
//

#ifndef Common_h
#define Common_h

typedef struct {
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

typedef enum {
  DrawableTexture = 0,
  AntsTexture = 1,
  CurrentTrailsTexture = 2,
  PreviousTrailsTexture = 3,
  BufferIndexAntVariables = 11,
  BufferIndexTrailVariables = 12,
} Textures;

#endif /* Common_h */
