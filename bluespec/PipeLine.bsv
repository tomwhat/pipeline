import FixedPoint::*;
import GetPut::*;
import FIFO::*;

import IfcPipeLine::*;
import PipeLineTypes::*;

interface PipeLine;
    interface TransformReq setTransform;
    interface TriangleReq inputTriangles;
endinterface

module mkPipeLine#(PipeLineIndication indication)(PipeLine);
    // TB: When you will want to send a triangle back to the cpp,
    // You do indication.callbackFrag(yourFrag)
    Reg#(Transform) transform <- mkRegU;
    FIFO#(Triangle) inputTriangles <- mkFIFO;
    FIFO#(Frag) outputFrags <- mkFIFO;

    // SettableTransformAndDivide perspective <- mkTransformDivide;

    // TODO: implement interface

    // TODO: put in pipeline steps

    interface TransformReq setTransform;
        method Action set(Bit#(16) posx, Bit#(16) posy, Bit#(16) posz,
	   Bit#(16) mxx , Bit#(16) mxy , Bit#(16) mxz ,
	   Bit#(16) myx , Bit#(16) myy , Bit#(16) myz ,
	    Bit#(16) mzx , Bit#(16) mzy , Bit#(16) mzz );
	    indication.callbackFrag(truncate(posx), truncate(posy), truncate(posz), 0);
//            perspective.setTransform.put(t);
        endmethod
    endinterface
endmodule
