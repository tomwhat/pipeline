// include stuff
#include <queue>
#include <utility>
#include <iostream>

#include "libbmp.h"

#include "peachyMath.h" //make header file
#include "peachyTypes.h" //make header file

#define PNG_WIDTH  512
#define PNG_HEIGHT 512

namespace peachy {
    Pipeline::Pipeline() {
        // Initialize
        img = new BmpImg(PNG_WIDTH, PNG_HEIGHT);
    }
    // Set parameters
    void Pipeline::setTransform(Transform<Mat3> t) {
        transform = t;
    }

    // step pipeline
    bool Pipeline::tick(bool end) {
        bool return_end = end;
        // Do initial transform and perspective divide
        if (!inputTriangles.empty()) {
            auto x = inputTriangles.front();
            auto a = transformAndDivide(x.a, transform);
            auto b = transformAndDivide(x.b, transform);
            auto c = transformAndDivide(x.c, transform);
            auto y = Triangle{a, b, c};
            transformedTriangles.push(y);
            inputTriangles.pop();
            end = false;
        }
        // Cull, clip, and convert x, y to pixel integer coordinates
        if (!transformedTriangles.empty()) {
            auto x = transformedTriangles.front();
            ClippedLines y = cullAndClip(x);
            if (y.ab.valid) clippedLines.push(y.ab);
            if (y.bc.valid) clippedLines.push(y.bc);
            if (y.ca.valid) clippedLines.push(y.ca);
            transformedTriangles.pop();
            end = false;
        }
        // Begin lines
        if (!clippedLines.empty()) {
            auto x = clippedLines.front();
            if (xlw.startLine(x.a, x.b)) clippedLines.pop();
            end = false;
        }
        // Continue lines
        if (xlw.busy) {
            xlw.tick();
            end = false;
        }
        // Get pixels from XiaoLinWu
        if (!xlw.outFIFO->empty()) {
            auto frag = xlw.outFIFO->front();
            int i = frag.intensity.byte();
            if (frag.pos.z > 0 && frag.pos.x.val < PNG_WIDTH && frag.pos.y.val < PNG_HEIGHT)
                img->set_pixel(frag.pos.x.val, frag.pos.y.val, i, i, i);
            xlw.outFIFO->pop();
            end = false;
        }
        if (end) {
            img->write("line.bmp");
        }
        return end;
    }
    // Functions
    Vec3 Pipeline::transformAndDivide(Vec3 v, Transform<Mat3> tm) {
        Vec3 stretched_view_space = tm.t*v + tm.pos;
        float x = -10000;
        float y = -10000;
        float z = -10000;
        if (stretched_view_space.z != 0) {
            x = stretched_view_space.x / -stretched_view_space.z;
            y = stretched_view_space.y / -stretched_view_space.z;
            // inverted z for correct interpolation
            z = 1.0 / -stretched_view_space.z;
        }
        return Vec3 {x, y, z};
    }

    ClippedLines Pipeline::cullAndClip(Triangle t) {
        bool axl = t.a.x < -1.0;
        bool axr = t.a.x >  1.0;
        bool ayb = t.a.y < -1.0;
        bool aya = t.a.y >  1.0;
        
        bool bxl = t.b.x < -1.0;
        bool bxr = t.b.x >  1.0;
        bool byb = t.b.y < -1.0;
        bool bya = t.b.y >  1.0;
        
        bool cxl = t.c.x < -1.0;
        bool cxr = t.c.x >  1.0;
        bool cyb = t.c.y < -1.0;
        bool cya = t.c.y >  1.0;

        bool up    = aya && bya && cya;
        bool down  = ayb && byb && cyb;
        bool left  = axl && bxl && cxl;
        bool right = axr && bxr && cxr;

        if (up || down || left || right) {
            // return 3 invalid lines (i.e. cull triangle)
            return {Line{0,0,0,false}, Line{0,0,0,false}, Line{0,0,0,false}};
        } else {
            // clip each line
            auto ab = clipLine(t.a, t.b, axl, axr, ayb, aya,
                                bxl, bxr, byb, bya);
            auto bc = clipLine(t.b, t.c, bxl, bxr, byb, bya,
                                cxl, cxr, cyb, cya);
            auto ca = clipLine(t.c, t.a, cxl, cxr, cyb, cya,
                                axl, axr, ayb, aya);
            ClippedLines out = {Line{0,0,0,false}, Line{0,0,0,false}, Line{0,0,0,false}};
            if (ab.valid){
                out.ab = {mapToIntegers(ab.a),
                            mapToIntegers(ab.b), true};
            }
            if (bc.valid){
                out.bc = {mapToIntegers(bc.a),
                            mapToIntegers(bc.b), true};
            }
            if (ca.valid){
                out.ca = {mapToIntegers(ca.a),
                            mapToIntegers(ca.b), true};
            }
            return out;
        }
    }

    ClipLine Pipeline::clipLine(
        Vec3 a, Vec3 b, bool axl, bool axr, bool ayb, bool aya,
        bool bxl, bool bxr, bool byb, bool bya
    ) {
        float kx = 0;
        float ky = 0;
        float kxz= 0;
        float kyz= 0;
        float xdiff = b.x-a.x;
        float ydiff = b.y-a.y;
        float zdiff = b.z-a.z;
        if (b.x != a.x) {
            kx = ydiff / xdiff;
            kxz= zdiff / xdiff;
        }
        if (b.y != a.y) {
            ky = xdiff / ydiff;
            kyz= zdiff / ydiff;
        }
        auto new_a = clip(a, kx, ky, kyz, kxz, axl, axr, ayb, aya);
        auto new_b = clip(b, kx, ky, kyz, kxz, bxl, bxr, byb, bya);
        ClipLine out = ClipLine{0, 0, false};
        if (new_a.valid && new_b.valid) {
            out = {new_a.a, new_b.a, true};
        }
        return out;
    }

    MaybeVec3 Pipeline::clip(Vec3 v, float kx, float ky, float kyz, float kxz,
                        bool xl, bool xr, bool yb, bool ya) {
        float xfactor = xl ? -1 : 1;
        float yfactor = yb ? -1 : 1;
        float x1 = v.x + ky * (-1+yfactor*v.y);
        float y1 = v.y + kx * (-1+xfactor*v.x);
        float yz1= v.z + kyz* (-1+yfactor*v.y);
        float xz1= v.z + kxz* (-1+xfactor*v.x);
        MaybeVec3 offy = MaybeVec3{0, false};
        if (yb || ya) { //y-above or y-below
            if ((-1 <= x1)&&(x1 <= 1))
                offy = {x1, yfactor, yz1, true};
        }
        MaybeVec3 offx = MaybeVec3{0,false};
        if (xl || xr) { //x-left or x-right
            if ((-1 <= y1)&&(y1 <= 1))
                offx = {xfactor, y1, xz1, true};
        }
        MaybeVec3 original = MaybeVec3{0,false};
        if (!(xl||xr||yb||ya)) {
            original = {v.x, v.y, v.z, true};
        }
        if (original.valid) {
            return original;
        } else if (offx.valid) {
            return offx;
        } else {
            return offy;
        }
    }

    FragPos Pipeline::mapToIntegers(Vec3 v) {

        PixCoord x((unsigned int)(v.x * PNG_WIDTH / 2 + PNG_WIDTH / 2));
        PixCoord y((unsigned int)(v.y * -PNG_HEIGHT/ 2 + PNG_HEIGHT/ 2));
        //float z = v.z*a + b;
        float z = v.z;
        return FragPos{x,y,z};
    }
}