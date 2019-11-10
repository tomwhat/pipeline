#include <iostream>
#include <string>
#include <cmath>
#include <iomanip>
#include <sstream>

#include "peachyMath.h"

namespace peachy {

    // Vec3
    Vec3 Vec3::origin() {
        return Vec3 {0,0,0};
    }

    float Vec3::dot(const Vec3& rhs) {
        return x*rhs.x + y*rhs.y + z*rhs.z;
    }
    float Vec3::mag() {
        return sqrt(x*x+y*y+z*z);
    }

    Vec3 Vec3::cross(const Vec3& rhs) {
        float a = y*rhs.z - z*rhs.y;
        float b = z*rhs.x - x*rhs.z;
        float c = x*rhs.y - y*rhs.x;
        return Vec3 {a, b, c};
    }

    Vec3 Vec3::operator+(const Vec3& rhs) {
        return Vec3{this->x+rhs.x, this->y+rhs.y, this->z+rhs.z};
    }
    Vec3 Vec3::operator-() {
        return Vec3{-x,-y,-z};
    }
    // Quaternion
    // Create identity quaternion
    Quat Quat::identity() {
        return {1, 0, 0, 0};
    }
    // Create quaternion from axis and angle of rotation
    Quat Quat::fromAxis(float i, float j, float k, float theta) {
        float w = cos(theta / 2.);
        float s = sin(theta / 2.);
        Quat r = {w, s*i, s*j, s*k};
        return r;
    }
    // Multiply two quaternions. Associative. Not commutative.
    Quat Quat::operator*(const Quat& rhs) {
        float w1 = rhs.w*this->w - rhs.i*this->i - rhs.j*this->j - rhs.k-this->k;
        float i1 = rhs.w*this->i + this->w*rhs.i + rhs.j*this->k - this->j*rhs.k;
        float j1 = rhs.w*this->j + this->w*rhs.j + rhs.k*this->i - this->k*rhs.i;
        float k1 = rhs.w*this->k + this->w*rhs.k + rhs.i*this->j - this->i*rhs.k;
        return Quat{w1,i1,j1,k1};
    }
    // Makes inverse Quaternion
    Quat Quat::inverse() {
        return Quat {w,-i,-j,-k};
    }

    Mat3 Mat3::identity() {
        return {1,0,0,0,1,0,0,0,1};
    }
    // Turns quaternion into 3x3 matrix
    Mat3 Mat3::fromQuat(const Quat& quat) {       
        float ii = quat.i*quat.i;
        float jj = quat.j*quat.j;
        float kk = quat.k*quat.k;
        float ij = quat.i*quat.j;
        float jk = quat.j*quat.k;
        float ki = quat.k*quat.i;
        
        float wi = quat.w*quat.i;
        float wj = quat.w*quat.j;
        float wk = quat.w*quat.k;

        float xx = 1. - 2.*(jj + kk);
        float xy = 2.*(ij - wk);
        float xz = 2.*(ki + wj);
        float yx = 2.*(ij + wk);
        float yy = 1. - 2.*(kk + ii);
        float yz = 2.*(jk + wi);
        float zx = 2.*(ki - wj);
        float zy = 2.*(jk - wi);
        float zz = 1. - 2.*(ii + jj);
        Mat3 ret = {xx,xy,xz,yx,yy,yz,zx,zy,zz};
        return ret;
    }

    float Mat3::determinant() {
        float a = yy*zz - yz*zy;
        float b = yz*zx - yx*zz;
        float c = yx*zy - yy*zx;
        return xx*a + xy*b + xz*c;
    }

    Mat3 Mat3::transpose() {
        return Mat3 {xx,yx,zx,xy,yy,zy,xz,yz,zz};
    }

    Mat3 Mat3::inverse() {
        float det = determinant();
        // Inverse not defined for singular matrices
        if (fabs(det) < 0.0000000001) {
            std::cout << "oof\n";
            std::cout << det << "\n";
            std::cout << fabs(det) << "\n";
            return Mat3 {0,0,0,0,0,0,0,0,0};
        }
        float a = (yy*zz - yz*zy)/det;
        float b = (xz*zy - xy*zz)/det;
        float c = (xy*yz - xz*yy)/det;
        float d = (yz*zx - yx*zz)/det;
        float e = (xx*zz - xz*zx)/det;
        float f = (xz*yx - xx*yz)/det;
        float g = (yx*zy - yy*zx)/det;
        float h = (xy*zx - xx*zy)/det;
        float i = (xx*yy - xy*yx)/det;

        return Mat3 {a,b,c,d,e,f,g,h,i};
    }

    // This should be implemented on the FPGA
    // Will fixed point work well? Or will floating point be necessary?
    Vec3 Mat3::operator*(const Vec3& rhs) {
        float x = this->xx*rhs.x + this->xy*rhs.y + this->xz*rhs.z;
        float y = this->yx*rhs.x + this->yy*rhs.y + this->yz*rhs.z;
        float z = this->zx*rhs.x + this->zy*rhs.y + this->zz*rhs.z;
        return Vec3{x, y, z};
    }

    Mat3 Mat3::operator*(const Mat3& rhs) {
        Mat3 res;
        res.xx = xx*rhs.xx + xy*rhs.yx + xz*rhs.zx;
        res.xy = xx*rhs.xy + xy*rhs.yy + xz*rhs.zy;
        res.xz = xx*rhs.xz + xy*rhs.yz + xz*rhs.zz;
        res.yx = yx*rhs.xx + yy*rhs.yx + yz*rhs.zx;
        res.yy = yx*rhs.xy + yy*rhs.yy + yz*rhs.zy;
        res.yz = yx*rhs.xz + yy*rhs.yz + yz*rhs.zz;
        res.zx = zx*rhs.xx + zy*rhs.yx + zz*rhs.zx;
        res.zy = zx*rhs.xy + zy*rhs.yy + zz*rhs.zy;
        res.zz = zx*rhs.xz + zy*rhs.yz + zz*rhs.zz;
        return res;
    }
    // Transform<Mat3>
    template<>
    Transform<Mat3>::Transform() {
        t = Mat3::identity();
        pos = Vec3{0,0,0};
    }
    template<>
    Transform<Mat3>::Transform(Mat3 mn, Vec3 posn) {
        t = mn;
        pos = posn;
    }
    template<>
    Transform<Mat3> Transform<Mat3>::pivot(Mat3 mn) {
        Mat3 mp = mn*t;
        Vec3 p = pos;
        return Transform<Mat3>(mp, p);
    }
    template<>
    Transform<Mat3> Transform<Mat3>::rotate(Mat3 mn) {
        Mat3 mp = mn*t;
        Vec3 p = mn*pos;
        return Transform<Mat3>(mp, p);
    }
    template<>
    Transform<Mat3> Transform<Mat3>::inverse() {
        Mat3 mp = t.inverse();
        Vec3 p = -pos;
        return Transform<Mat3>(mp, p);
    }
    template<>
    Transform<Mat3> Transform<Mat3>::operator*(const Transform<Mat3>& rhs) {
        Transform<Mat3> t = rotate(rhs.t);
        return Transform<Mat3>(t.t, t.pos + rhs.pos);
    }

    // Transform<Quat>
    template<>
    Transform<Quat>::Transform() {
        t = Quat::identity();
        pos = Vec3 {0,0,0};
    }
    template<>
    Transform<Quat>::Transform(Quat qn, Vec3 posn) {
        t = qn;
        pos = posn;
    }
    // Rotates in place
    template<>
    Transform<Quat> Transform<Quat>::pivot(Quat qn) {
        Transform<Quat> ot = Transform<Quat>();
        ot.t = qn*t;
        ot.pos = pos;
        return ot;
    }
    // Rotates, including translation
    template<>
    Transform<Quat> Transform<Quat>::rotate(Quat qn) {
        Transform<Quat> ot = Transform<Quat>();
        ot.t = qn*t;
        ot.pos = Mat3::fromQuat(qn)*pos;
        return ot;
    }
    // Inverse. Useful for Camera
    template<>
    Transform<Quat> Transform<Quat>::inverse() {
        Transform<Quat> ot = Transform<Quat>();
        ot.t = t.inverse();
        ot.pos = -pos;
        return ot;
    }

    Transform<Mat3> toM(Transform<Quat> q) {
        Mat3 m = Mat3::fromQuat(q.t);
        return Transform<Mat3>(m, q.pos);
    }
    template<>
    Transform<Quat> Transform<Quat>::operator*(const Transform<Quat>& rhs) {
        Transform<Quat> t = rotate(rhs.t);
        return Transform<Quat>(t.t, t.pos+rhs.pos);
    }

    // Camera represented by a position and a rotation.
    // Define the identity quaternion as pointing in the -z direction,
    // so if q = Quat::identity() and pos = {0,0,0}, then the camera
    // has no effect
    Camera::Camera(float n, float f, float fv):Transform<Quat>() {
        near = n;
        far = f;
        fov = fv;
    }
    //TODO
    Camera Camera::pointAt(Vec3 target) {
        return Camera(near, far, fov);
    }
    float Camera::getS() {
        return 1/tan(fov/2.);
    }
    float Camera::getA() {
        return -far/(far-near);
    }
    float Camera::getB() {
        return -(far*near)/(far-near);
    }
    // This one is a bit wonky. We are doing the inverse camera
    // transformation as well as the horizontal and vertical scaling
    // for FOV. This step does not remap z or do perspective divide.
    Transform<Mat3> Camera::getFOVCam() {
        Transform<Quat> c_in = inverse();
        float s = getS();
        Mat3 p = Mat3{s,0,0,0,s,0,0,0,1};
        return Transform<Mat3>(p, Vec3::origin()) * toM(c_in);
    }
}

std::ostream& operator<<(std::ostream& os, const peachy::Vec3 v) {
    std::stringstream stream;
    stream << std::fixed << std::setprecision(3);
    stream << v.x << ", " << v.y << ", " << v.z << "\n";
    std::string s = stream.str();
    os << s;
    return os;
}

// cout << Mat3
std::ostream& operator<<(std::ostream& os, const peachy::Mat3 m) {
    std::stringstream stream;
    stream << std::fixed << std::setprecision(3);
    stream << m.xx << ",\t" << m.xy << ",\t" << m.xz << "\n";
    stream << m.yx << ",\t" << m.yy << ",\t" << m.yz << "\n";
    stream << m.zx << ",\t" << m.zy << ",\t" << m.zz << "\n";
    std::string s = stream.str();
    os << s;
    return os;
}
