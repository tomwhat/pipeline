#ifndef PEACHY_TYPES
#define PEACHY_TYPES

#include <queue>
#include "peachyMath.h"
#include "libbmp.h"

#define PI 3.14159265358979

#define NUM_PIXELS 1024

#define M_BITS 4 // Intensity bits for line renderer
#define T_BITS 10 // Location bits for fragments
#define N_BITS 14 // Slope bits

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

    typedef INT_N<N_BITS> Offset;
    typedef INT_N<M_BITS> Intensity;
    typedef INT_N<T_BITS> PixCoord;

    struct FragPos {
        PixCoord x, y;
        float z;
    };

    struct Frag {
        FragPos pos;
        Intensity intensity;
    };

    struct Triangle {
    Vec3 a, b, c;
    bool valid;
    };

    struct Line {
        FragPos a, b;
        bool valid;
    };

    struct ClipLine {
        Vec3 a, b;
        bool valid;
    };

    struct MaybeVec3 {
        Vec3 a;
        bool valid;
    };

    struct ClippedLines {
        Line ab, bc, ca;
    };

    struct XiaoLinWu {
        public:
        std::queue<Frag> * outFIFO;
        XiaoLinWu();
        ~XiaoLinWu();
        bool busy;
        bool startLine(FragPos a, FragPos b);
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

    class Pipeline {
        public:
        XiaoLinWu xlw;
        std::queue<Triangle> inputTriangles;
        Transform<Mat3> transform;
        float a, b;
        Pipeline();
        void setTransform(Transform<Mat3> t);
        bool tick(bool end);

        private:
        std::queue<Triangle> transformedTriangles;
        std::queue<Line> clippedLines;

        BmpImg *img;

        Vec3 transformAndDivide(Vec3 v, Transform<Mat3> tm);
        ClippedLines cullAndClip(Triangle t);
        ClipLine clipLine(
            Vec3 a, Vec3 b, bool axl, bool axr, bool ayb, bool aya,
            bool bxl, bool bxr, bool byb, bool bya
        );
        MaybeVec3 clip(Vec3 v, float kx, float ky, float kyz, float kxz,
                       bool xl, bool xr, bool yb, bool ya);
        FragPos mapToIntegers(Vec3 v);
    };

    Vec3 transformAndDivide(Vec3 v, Transform<Quat> t, Camera c);
}

#endif