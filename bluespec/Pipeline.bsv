import FixedPoint::*;
import GetPut::*;
import FIFO::*;

import IfcPipeLine::*;
import PipeLineTypes::*;


(* synthesize *)
module mkPipeline#(PipeLineIndication indication)(PipeLine);
    // TB: When you will want to send a triangle back to the cpp,
    // You do indication.callbackFrag(yourFrag)
    Reg#(Transform) transform <- mkRegU;
    FIFO#(Triangle) inputTriangles <- mkFIFO;
    FIFO#(Frag) outputFrags <- mkFIFO;

    SettableTransformAndDivide perspective <- mkTransformDivide;

    // TODO: implement interface

    // TODO: put in pipeline steps

    interface setTransform;
        method Action set(Transform t);
            perspective.setTransform.put(t);
        endmethod
    endinterface
endmodule
