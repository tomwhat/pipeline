#include "peachyMath.h"
#include "peachyTypes.h"
#include <queue>
#include <optional>
#include <utility>
#include <iostream>

// Goal: this is to be a module, like a BlueSpec module
// Line rasterizer
namespace peachy {
        
    XiaoLinWu::XiaoLinWu() {
        outFIFO = new std::queue<Frag>;
        busy = false;
    }
    XiaoLinWu::~XiaoLinWu() {
        delete outFIFO;
    }

    std::pair<FragPos, FragPos> XiaoLinWu::descramble(FragPos a, FragPos b) {
        PixCoord tx0 = swaps ? a.y : a.x;
        PixCoord ty0 = swaps ? a.x : a.y;
        PixCoord tx1 = swaps ? b.y : b.x;
        PixCoord ty1 = swaps ? b.x : b.y;
        PixCoord oy1 = yflip ? ty0 : ty1;
        PixCoord oy0 = yflip ? ty1 : ty0;
        PixCoord ox1 = xflip ? tx0 : tx1;
        PixCoord ox0 = xflip ? tx1 : tx0;
        return std::pair<FragPos,FragPos>(FragPos{ox0, oy0, a.z}, FragPos{ox1, oy1, b.z});
    }

    bool XiaoLinWu::startLine(FragPos a, FragPos b) {
        if (busy) {
            return false;
        }
        // else
        busy = true; // finishing the line should be accomplished in update rule

        auto ix0 = a.x.val;
        auto ix1 = b.x.val;
        auto iy0 = a.y.val;
        auto iy1 = b.y.val;

        xflip = ix0 > ix1;
        yflip = iy0 > iy1;
        auto tx0 = xflip ? ix1 : ix0;
        auto tx1 = xflip ? ix0 : ix1;
        auto ty0 = yflip ? iy1 : iy0;
        auto ty1 = yflip ? iy0 : iy1;
        float k;
        if(tx0 == tx1) {
            k = 1000000000;
        } else {
            k = (float)(ty1-ty0) / (float)(tx1-tx0);
        }
        swaps = k > 1.0;
        x0 = swaps ? ty0 : tx0;
        x1 = swaps ? ty1 : tx1;
        y0 = swaps ? tx0 : ty0;
        y1 = swaps ? tx1 : ty1;
        k  = swaps ? 1.0/k : k;
        ky.set(k * (float)Offset::max() + 0.5);
        z0 = a.z; // z is already inverted
        z1 = b.z;
        kz = (z1-z0) / (x1.val-x0.val);
        D = Offset(0);
        auto l = FragPos{x0.val, y0.val, z0};
        auto r = FragPos{x1.val, y1.val, z1};
        auto outs = descramble(l, r);
        // TODO: based on flipx, flipy, and swaps, do appropriate swaps
        outFIFO->push(Frag{outs.first, Intensity::max()});
        outFIFO->push(Frag{outs.second, Intensity::max()});
    }

    void XiaoLinWu::tick() {
        if(!busy) {
            return;
        }
        x0.set(x0.val + 1);
        x1.set(x1.val - 1);
        z0 += kz;
        z1 -= kz;
        if(x0.val >= x1.val) {
            busy = false;
            return;
        }
        unsigned int prev = D.val;
        D.set(D.val + ky.val);
        // Overflow
        if (D.val < prev ||(D.val == prev && ky.val != 0)) {
            y0.set(y0.val + 1);
            y1.set(y1.val - 1);
        }
        unsigned int intensity = D.val >> (N_BITS - M_BITS);
        unsigned int invertedI = ~intensity;
        // push to outFIFO
        auto l = FragPos{x0.val, y0.val, z0};
        auto r = FragPos{x1.val, y1.val, z1};
        auto u = FragPos{x0.val, y0.val+1, z0};
        auto d = FragPos{x1.val, y1.val-1, z1};
        auto outp = descramble(l, r);
        auto outs = descramble(u, d);
        outFIFO->push(Frag{outp.first, Intensity(invertedI)});
        outFIFO->push(Frag{outp.second, Intensity(invertedI)});
        outFIFO->push(Frag{outs.first, Intensity(intensity)});
        outFIFO->push(Frag{outs.second, Intensity(intensity)});
    }
}