#include <iostream>
#include <ctime>
#include <ratio>
#include <cmath>
#include <chrono>
#include "libbmp.h" // draw bmp images easily
#include "peachyMath.h"

//#include "peachyPipeline.cpp"

#include "peachyTypes.h"
#include "OBJ_Loader.h"

#include "TransformReq.h"
#include "TriangleReq.h"
#include "StopReq.h"

#include "PipeLineIndication.h"

using namespace peachy;

static TransformReqProxy *transformReq = 0;
static TriangleReqProxy *triangleReq = 0;
static StopReqProxy *stopReq = 0;


class PipeLineIndication: public PipeLineIndicationWrapper
{
    public:
    void callbackFrag(const uint16_t fposx,const uint16_t fposy,const uint16_t fposz,const uint8_t fintensity) {
        float f = (float) fintensity;
        f = (f+1)*16 - 0.0001;
        int i = (int) f;
        img->set_pixel(fposx, fposy, i, i / 2, i);
    }
    PipeLineIndication(unsigned int id) : PipeLineIndicationWrapper(id) {
        img = new BmpImg(1024, 1024);
    }
    
    void writeBmp() {
    	img->write("line.bmp");
    }

    private:
    BmpImg *img;
};

int main(int argc, char *argv[]) {

    transformReq = new TransformReqProxy(IfcNames_TransformReqS2H);
    triangleReq = new TriangleReqProxy(IfcNames_TriangleReqS2H);
    stopReq = new StopReqProxy(IfcNames_StopReqS2H);
    PipeLineIndication pipelineIndication(IfcNames_PipeLineIndicationH2S);

    // Just create transform and camera
    Quat r = Quat::fromAxis(1.,0.,0.,0.);
    Transform<Quat> t = Transform<Quat>(r, Vec3::origin());
    t.pos = t.pos + Vec3{0, 0., 0.};
    Camera c = Camera(1.1, 100, PI/3);
    Transform<Mat3> tm = toM(t);
    Transform<Mat3> ci = c.getFOVCam();

    // Create and set pipeline
    //Pipeline *pipeline = new Pipeline();
    //pipeline->setTransform(ci * tm);
    Transform<Mat3> ts = ci * tm;
    fpTrans fp = fpTrans(ts);
    transformReq->set(fp.x, fp.y, fp.z,
    				  fp.xx, fp.xy, fp.xz,
    				  fp.yx, fp.yy, fp.yz,
    				  fp.zx, fp.zy, fp.zz);
    				  
   	if (true) {
		objl::Loader Loader;
		bool loadout = Loader.LoadFile("path.obj");
		std::chrono::high_resolution_clock::time_point st = std::chrono::high_resolution_clock::now();
		if (loadout) {
			std::cout<<"Successfully loaded path\n";
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
		            while (true) {
		            	std::chrono::duration<double> t = std::chrono::high_resolution_clock::now() - st;
		            	if (t.count() > 0.001) {
		            		st = std::chrono::high_resolution_clock::now();
		            		break;
		            	}
		            }
		        }
		    }
		} else {
			std::cout<<"Failed to load path\n";
		}
    }
    
  	if (false) {
  		Vec3 a = Vec3{-0.8, -0.8, -2};
  		Vec3 b = Vec3{ 0.8, -0.8, -2};
  		Vec3 c = Vec3{ 0.0,  0.8, -2};
  		fpVec3 fpa = fpVec3(a);
  		fpVec3 fpb = fpVec3(b);
  		fpVec3 fpc = fpVec3(c);
  		triangleReq->enq(fpa.x, fpa.y, fpa.z,
  						 fpb.x, fpb.y, fpb.z,
  						 fpc.x, fpc.y, fpc.z, true);
  	}  
  	
    std::chrono::high_resolution_clock::time_point start = std::chrono::high_resolution_clock::now();
    bool didPrintOnce = false;
    while (true) {
        std::chrono::duration<double> t = std::chrono::high_resolution_clock::now() - start;
        if (t.count() > 5) {
        	std::cout<<"should stop\n";
        	stopReq->stop();
        	pipelineIndication.writeBmp();
            break;
        } else {
            if (!didPrintOnce) {
                std::cout<<"time: "<<t.count()<<"\n";
                didPrintOnce = true;
            }
        }
    }
    
    std::cout<<"Finished\n";

    return 0;
}
