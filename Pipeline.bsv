import FixedPoint::*;
import GetPut::*;
import FIFO::*;

import Types::*;

// This is the only interface I should need
// for connectal in the end.
// For development/testing, should I just add
// get___() methods for each stage?
interface PipeLine;
    interface Put#(Transform) setTransform;
    interface Put#(Triangle) pushTriangle;
    interface Get#(Frag) getFrag;
endinterface
// Stretch goal: getFrameBuffer() instead
// of getFrag() :)

(* synthesize *)
module mkPipeline(PipeLine);
    Reg#(Transform) transform <- mkRegU;
    FIFO#(Triangle) inputTriangles <- mkFIFO;
    FIFO#(Frag) outputFrags <- mkFIFO;

    SettableTransformAndDivide perspective <- mkTransformDivide;

    // TODO: implement interface

    // TODO: put in pipeline steps

    interface setTransform;
        method Action put(Transform t);
            perspective.setTransform.put(t);
        endmethod
    endinterface
endmodule