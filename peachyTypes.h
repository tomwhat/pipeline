#pragma once

#include <queue>
#include "peachyMath.h"

#define PI 3.14159265358979

#define NUM_PIXELS 1024

#define M 4 // Intensity bits for line renderer
#define T 10 // Location bits for fragments
#define N 14 // Slope bits

namespace peachy {
    template <unsigned int Nbits> struct INT_N {
        unsigned int val;
        INT_N() {
            val = 0;
        }
        INT_N(int v) {
            val = ((unsigned int)v) % (1 << Nbits);
        }
        unsigned int incr_f(int x) {
            val = (val+(int)x*(1 <<Nbits)) % (1 << Nbits);
            return val;
        }
        unsigned int set(int x) {
            val = x % (1 << Nbits);
            return val;
        }
        unsigned int byte() {
            if (Nbits < 8) {
                return val << (8-Nbits);
            } else {
                return val >> (Nbits-8);
            }
        }
        static unsigned int max() {
            return (1 << Nbits) - 1;
        }
    };

    typedef INT_N<N> Offset;
    typedef INT_N<M> Intensity;
    typedef INT_N<T> PixCoord;

    struct FragPos {
        PixCoord x, y, z;
    };

    struct Frag {
        FragPos pos;
        Intensity intensity;
    };

    struct XiaoLinWu {
        public:
        std::queue<Frag> * outFIFO;
        XiaoLinWu();
        ~XiaoLinWu();
        bool busy;
        bool startLine(Vec3 a, Vec3 b);
        void tick();

        private:
        bool xflip;
        bool yflip;
        bool swaps;
        PixCoord x0;
        PixCoord x1;
        PixCoord y0;
        PixCoord y1;
        float z0;
        float z1;
        std::pair<FragPos,FragPos> descramble(FragPos a, FragPos b);

        Offset ky;
        float kz;

        Offset D;
    };

    Vec3 transformAndDivide(Vec3 v, Transform<Quat> t, Camera c);
}