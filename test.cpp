#include <iostream>
#include <ctime>
#include <ratio>
#include <chrono>
#include "libbmp.h" // draw bmp images easily
#include "peachyMath.h"

//#include "peachyPipeline.cpp"

#include "peachyTypes.h"
#include "OBJ_Loader.h"

#include "TransformReq.h"
#include "TriangleReq.h"

#include "PipeLineIndication.h"

using namespace peachy;

static TransformReqProxy *transformReq = 0;
static TriangleReqProxy *triangleReq = 0;

static volatile bool timeToFinish = false;

class PipeLineIndication: public PipeLineIndicationWrapper
{
    public:
    void callbackFrag(const uint16_t fposx,const uint16_t fposy,const uint16_t fposz,const uint8_t fintensity) {
        if (fposx == fposy == fposz == fintensity) {
            img->write("line.bmp");
            timeToFinish = true;
        }
        img->set_pixel(fposx, fposy, fintensity, fintensity, fintensity);
    }
    PipeLineIndication(unsigned int id) : PipeLineIndicationWrapper(id) {
        img = new BmpImg(1024, 1024);
    }

    private:
    BmpImg *img;
};


int main(int argc, char *argv[]) {

    transformReq = new TransformReqProxy(IfcNames_TransformReqS2H);
    triangleReq = new TriangleReqProxy(IfcNames_TriangleReqS2H);
    PipeLineIndication pipelineIndication(IfcNames_PipeLineIndicationH2S);
    transformReq->set( 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,1);

    // Just create transform and camera
    Quat r = Quat::fromAxis(0.,1.,0.,PI/2);
    Transform<Quat> t = Transform<Quat>(r, Vec3::origin());
    t.pos = t.pos + Vec3{0, 0, -4};
    Camera c = Camera(1.1, 100, 20*PI/180);
    Transform<Mat3> tm = toM(t);
    std::cout<<"tm: \n"<<tm.t;
    std::cout<<"c:\n"<<toM(c).t;
    std::cout<<"ci:\n";
    Transform<Mat3> ci = c.getFOVCam();
    std::cout<<ci.t;
    std::cout<<"ci * tm:\n"<<(ci * tm).t;

    // Create and set pipeline
    //Pipeline *pipeline = new Pipeline();
    //pipeline->setTransform(ci * tm);
    Transform<Mat3> ts = ci * tm;
    transformReq->set(ts.pos.x, ts.pos.y, ts.pos.z,
                    ts.t.xx, ts.t.xy, ts.t.xz,
                    ts.t.yx, ts.t.yy, ts.t.yz,
                    ts.t.zx, ts.t.zy, ts.t.zz);

    objl::Loader Loader;
    bool loadout = Loader.LoadFile("monkey.obj");
    if (loadout) {
        for (int i = 0; i < Loader.LoadedMeshes.size(); i++) {
            objl::Mesh curMesh = Loader.LoadedMeshes[i];
            for (int j = 0; j < curMesh.Indices.size(); j+=3) {
                int index = curMesh.Indices[j];
                objl::Vertex u = curMesh.Vertices[index];
                index = curMesh.Indices[j+1];
                objl::Vertex v = curMesh.Vertices[index];
                index = curMesh.Indices[j+2];
                objl::Vertex w = curMesh.Vertices[index];
                Vec3 vu = Vec3{u.Position.X, u.Position.Y, u.Position.Z};
                Vec3 vv = Vec3{v.Position.X, v.Position.Y, v.Position.Z};
                Vec3 vw = Vec3{w.Position.X, w.Position.Y, w.Position.Z};
                //Triangle tri = Triangle{vu, vv, vw};
                //pipeline->inputTriangles.push(tri);

                // convert to fixed point
                fpVec3 fpu = fpVec3(vu);
                fpVec3 fpv = fpVec3(vv);
                fpVec3 fpw = fpVec3(vw);
                triangleReq->enq(fpu.x, fpu.y, fpu.z,
                                 fpv.x, fpv.y, fpv.z,
                                 fpw.x, fpw.y, fpw.z,
                                 true);
            }
        }
    }
    std::chrono::high_resolution_clock::time_point start = std::chrono::high_resolution_clock::now();
    bool didPrintOnce = false;
    while (true) {
        std::chrono::duration<double> t = std::chrono::high_resolution_clock::now() - start;
        if (t.count() > 5000) {
            if (timeToFinish) {
                break;
            }
        } else {
            if (timeToFinish && !didPrintOnce) {
                std::cout<<"time: "<<t.count()<<"\n";
                didPrintOnce = true;
            }
        }
    }
    
    std::cout<<"Finished\n";

    return 0;
}
