#include <iostream>
#include "libbmp.h" // draw bmp images easily
#include "peachyMath.h"
//#include "peachyPerspective.cpp"
#include "peachyTypes.h"

using namespace peachy;

#define PNG_WIDTH  512
#define PNG_HEIGHT 512

bool valid_pos(FragPos fp) {
    return (fp.x.val < PNG_WIDTH && fp.x.val < PNG_HEIGHT);
}

void drawLine(BmpImg& img, XiaoLinWu& xlw, Vec3 a, Vec3 b, Vec3 c) {
    xlw.startLine(a, b);

    while (xlw.busy) {
        xlw.tick();
    }
    while (!xlw.outFIFO->empty()) {
        Frag f = xlw.outFIFO->front();
        xlw.outFIFO->pop();
        if(valid_pos(f.pos)) {
            unsigned int i = f.intensity.byte();
            img.set_pixel(f.pos.x.val, f.pos.y.val, i*c.x, i*c.y, i*c.z);
        }
    }
}

int main(int argc, char *argv[]) {
    Vec3 a = {0.5, 0.5, -1.5};
    
    float angle = .0;
    if (argc == 2) {
        angle = std::stof(argv[1]);
    }

    Quat r = Quat::fromAxis(0.,0.,1.,angle);
    Transform<Quat> t = Transform<Quat>(r, Vec3::origin());
    Camera c = Camera(1.1, 100, 90*PI/180);
    Vec3 b = transformAndDivide(a, t, c);

    std::cout << "a " << a;
    std::cout << "b " << b;

    BmpImg img (PNG_WIDTH, PNG_HEIGHT);

    XiaoLinWu xlw = XiaoLinWu();

    
    Vec3 pa = Vec3{20, 20, 10};
    Vec3 pb = Vec3{158, 481, 10};
    Vec3 pc = Vec3{358, 64, 10};
    Vec3 red = Vec3{1,0,0};
    Vec3 green = Vec3{0,1,0};
    Vec3 blue = Vec3{0,0,1};
    drawLine(img, xlw, pa, pb, red);
    drawLine(img, xlw, pb, pc, green);
    drawLine(img, xlw, pc, pa, blue);
    
    img.write("line.bmp");


    return 0;
}