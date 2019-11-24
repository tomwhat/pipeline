#ifndef PEACHY_MATH
#define PEACHY_MATH

#include <iostream>

namespace peachy {
    struct Vec3 {
        float x;
        float y;
        float z;

        static Vec3 origin();
        float dot(const Vec3& rhs);
        float mag();
        Vec3 cross(const Vec3& rhs);
        Vec3 operator+(const Vec3& rhs);
        Vec3 operator*(const float& rhs);
        Vec3 operator-();
    };

    struct fpVec3 {
        uint16_t x;
        uint16_t y;
        uint16_t z;

        fpVec3(Vec3 v);
    };

    struct Quat {
        float w;
        float i;
        float j;
        float k;
        float scale = 1;

        static Quat identity();
        static Quat fromAxis(float i, float j, float k, float theta);
        Quat operator*(const Quat& rhs);
        Quat operator*(const float& rhs);
        Quat inverse();
    };

    struct Mat3 {
        float xx, xy, xz;
        float yx, yy, yz;
        float zx, zy, zz;
        static Mat3 identity();
        static Mat3 fromQuat(const Quat& quat);
        float determinant();
        Mat3 transpose();
        Mat3 inverse();
        Vec3 operator*(const Vec3& rhs);
        Mat3 operator*(const Mat3& rhs);
        Mat3 operator*(const float& rhs);
    };

    template <class T>
    struct Transform {
        T t;
        Vec3 pos;
        Transform();
        Transform(T tn, Vec3 posn);
        Transform pivot(T tn);
        Transform rotate(T tn);
        Transform inverse();
        Transform scale(float f);
        Transform operator*(const Transform& rhs);
    };

    Transform<Mat3> toM(Transform<Quat> q);

    struct Camera : Transform<Quat> {
        float near, far, fov;
        Camera(float n, float f, float fv);
        Camera pointAt(Vec3 target);
        float getS();
        float getA();
        float getB();
        Transform<Mat3> getFOVCam();
    };
}
std::ostream& operator<<(std::ostream& os, const peachy::Vec3 v);
std::ostream& operator<<(std::ostream& os, const peachy::Mat3 m);

#endif