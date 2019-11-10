// include stuff
#include "peachyLines.cpp"
#include "peachyMath.h" //make header file
#include "peachyTypes.h" //make header file
#include <optional>

using namespace peachy;

class PipeLine {
    public:
    XiaoLinWu xlw;
    PipeLine() {
        // Initialize
    }
    // Set parameters
    void setMatrix(Mat3 m) {

    }
    // etc.

    // enqueue vertex 
    bool pushVertex(Vec3 v) {

    }
    // dequeue pixel/fragment
    std::optional<Frag> popPixel() {

    }

    // step pipeline
    void tick() {
        // enqueue, dequeue, tick inner parts of pipeline.

        // vertexQueue
    }
};