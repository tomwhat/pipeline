#include "peachyMath.h"
#include "peachyTypes.h"


namespace peachy {
    Vec3 transformAndDivide(Vec3 v, Transform<Quat> t, Camera c) {
        // ct will be the 3x3 matrix and vector stored on the fpga
        Transform<Mat3> ct = c.getFOVCam() * toM(t);
        // a and b will also be stored on the fpga
        float a = c.getA();
        float b = c.getB();

        // Intermediate level between transform and projection
        Vec3 stretched_cam_space = ct.t*v + ct.pos;
        // perspective divide
        // (-z) is used because we have x:right,y:up,z:out of
        // screen, but we want to see what's on the other side
        // of the screen, which would be negative valued z, so 
        // dividing by z would invert x and y. 
        float x = stretched_cam_space.x / -stretched_cam_space.z;
        float y = stretched_cam_space.y / -stretched_cam_space.z;
        // Linearly interpolate over inverse of z...the math checks out
        float z = 1.0 / -stretched_cam_space.z;
        // Was going to use this but must reconsider
        // depth from remapping z from 0 to 1
        //float d = z*a + b;
        return Vec3 {x, y, z};
    }
}