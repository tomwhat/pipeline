#include <iostream>
#include "libbmp.h" // draw bmp images easily
#include "peachyMath.h"

//#include "peachyPipeline.cpp"

#include "peachyTypes.h"
#include "OBJ_Loader.h"

using namespace peachy;

int main(int argc, char *argv[]) {
    
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
    Pipeline *pipeline = new Pipeline();
    pipeline->setTransform(ci * tm);

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
                Triangle tri = Triangle{vu, vv, vw};
                pipeline->inputTriangles.push(tri);
            }
        }
    }

    while (!pipeline->tick(true)) {
        
    }
    
    std::cout<<"Finished\n";

    return 0;
}