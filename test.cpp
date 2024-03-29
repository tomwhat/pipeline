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
#include "KillReq.h"

#include "PipeLineIndication.h"

using namespace peachy;

static TransformReqProxy *transformReq = 0;
static TriangleReqProxy *triangleReq = 0;
static StopReqProxy *stopReq = 0;
static KillReqProxy *killReq = 0;

static volatile bool allDone = false;


class PipeLineIndication: public PipeLineIndicationWrapper
{
    public:
    void callbackFrag(const uint16_t fposx,const uint16_t fposy,const uint16_t fposz,const uint8_t fintensity) {
        float f = (float) fintensity;
        f = (f+1)*16 - 0.0001;
        int i = (int) f;
        img->set_pixel(fposx, fposy, i, i / 2, i);
    }
    
    void confirmStop(const uint16_t x) {
    	std::cout<<"confirm stop\n";
		img->write("out.bmp");
		allDone = true;
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
    killReq = new KillReqProxy(IfcNames_StopReqS2H);
    PipeLineIndication pipelineIndication(IfcNames_PipeLineIndicationH2S);

    // Just create transform and camera
    Quat r = Quat::fromAxis(1.,0.,0.,0.);
    Transform<Quat> t = Transform<Quat>(r, Vec3::origin());
    t.pos = t.pos + Vec3{0, 0., -2.};
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
    				  
   	if (false) {
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
		            std::chrono::high_resolution_clock::time_point start = std::chrono::high_resolution_clock::now();
		            while (true) {
						std::chrono::duration<double> t = std::chrono::high_resolution_clock::now() - start;
						if (t.count() > 0.001) {
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
	  	float amt = 20.0;
	  	float jot = 0.02;
	  	for (int i = -amt; i < amt + 1.0; i++) {
	  		for (int j = -amt; j < amt + 1.0; j++) {
	  			float tx = 1.3*i / amt;
	  			float ty = 1.3*j / amt;
	  			Vec3 a = Vec3{tx-jot,ty-jot,0.0};
	  			Vec3 b = Vec3{tx+jot,ty-jot,0.0};
	  			Vec3 c = Vec3{tx,ty+jot,0.0};
	  			fpVec3 fpa = fpVec3(a);
	  			fpVec3 fpb = fpVec3(b);
	  			fpVec3 fpc = fpVec3(c);
	  			triangleReq->enq(fpa.x, fpa.y, fpa.z,
	  					 		 fpb.x, fpb.y, fpb.z,
	  					 		 fpc.x, fpc.y, fpc.z, true);
	  		}
	  	}
  	}
  	
  	if (true) {
  		float amt = 30.0;
  		for (int i = 0; i < amt + 1.0; i++) {
  			float tx = 3.0*i / amt - 1.5;
  			Vec3 a = Vec3{-1.5, -1.5, 0.0};
  			Vec3 b = Vec3{ 1.5, -1.5, 0.0};
  			Vec3 c = Vec3{ 1.5,   tx, 0.0};
  			fpVec3 fpa = fpVec3(a);
  			fpVec3 fpb = fpVec3(b);
  			fpVec3 fpc = fpVec3(c);
  			triangleReq->enq(fpa.x, fpa.y, fpa.z,
  					 		 fpb.x, fpb.y, fpb.z,
  					 		 fpc.x, fpc.y, fpc.z, true);
  		}
  	}
  	
  	if (false) {
		Vec3 a = Vec3{-1.5, -1.5, 0.0};
		Vec3 b = Vec3{ 1.5,  1.5, 0.0};
		Vec3 c = Vec3{ 1.5, -1.5, 0.0};
		fpVec3 fpa = fpVec3(a);
		fpVec3 fpb = fpVec3(b);
		fpVec3 fpc = fpVec3(c);
		triangleReq->enq(fpa.x, fpa.y, fpa.z,
				 		 fpb.x, fpb.y, fpb.z,
				 		 fpc.x, fpc.y, fpc.z, true);
  	}
  	

    triangleReq->enq(0,0,0,0,0,0,0,0,0,false);
    triangleReq->enq(0,0,0,0,0,0,0,0,0,false);
    stopReq->stop();

	while(!allDone) {
	
	}
	killReq->kill();
    return 0;
}
