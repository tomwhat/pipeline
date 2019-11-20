import FixedPoint::*;
import GetPut::*;
import FIFO::*;

import IfcPipeLine::*;
import PipeLineTypes::*;
import TransformAndDivide::*;
import XiaoLinWu::*;

interface PipeLine;
    interface TransformReq setTransform;
    interface TriangleReq inputTriangles;
endinterface

module mkPipeLine#(PipeLineIndication indication)(PipeLine);
    // TB: When you will want to send a triangle back to the cpp,
    // You do indication.callbackFrag(yourFrag)

    FIFO#(Triangle) fifoTriIn <- mkFIFO;
    FIFO#(Frag) fifoFragOut <- mkFIFO;
    SettableTransformAndDivide transf <- mkTransformDivide;
    XiaoLinWu xlw <- mkXiaoLinWu;

    // Some state for in_to_tr
    Reg#(Vec3) bufferA <- mkRegU;
    Reg#(Vec3) bufferB <- mkRegU;
    Reg#(Bool) validA  <- mkReg(False);
    Reg#(Bool) validB  <- mkReg(False);
    // Breaks triangles into vertices and sends them to be transformed
    rule in_to_tr;
        if (validA) begin
            transf.doTransform.put(bufferA);
            bufferA <= bufferB;
            validA <= validB;
            validB <= False;
        end else begin
            let t = fifoTriIn.first();
            fifoTriIn.deq();
            transf.doTransform.put(t.a);
            bufferA <= t.b;
            bufferB <= t.c;
            validA <= True;
            validB <= True;
        end
    endrule

    // Some state for tr_to_tr
    Reg#(FragPos) lastFragPos <- mkRegU;
    Reg#(Bool) validLastFragPos <- mkReg(False);
    // Takes transformed vertices (now as FragPos) and feeds them as lines
    // to the XiaoLinWu algorithm
    rule tr_to_xl;
        let fragPos <- transf.doTransform.get();
        if (validLastFragPos) begin
            xlw.line.put(tuple2(lastFragPOs, fragPos);
        end
        lastFragPos <= fragPos;
        validLastFragPos <= True;
    endrule

    // Some state for xlw_to_host
    Reg#(Frag) fragBufA <- mkRegU;
    Reg#(Frag) fragBufB <- mkRegU;
    Reg#(Frag) fragBufC <- mkRegU;
    Reg#(Bool) validFragA <- mkReg(False);
    Reg#(Bool) validFragB <- mkReg(False);
    Reg#(Bool) validFragC <- mkReg(False);
    // Take stream of fragments and just send them to the host for processing
    rule xlw_to_host;
        if (validFragA) begin
            let f =  fragBufA;
            indication.callbackFrag(pack(f.pos.x),pack(f.pos.y),pack(f.pos.z),pack(f.intensity));
            fragBufA <= fragBufB;
            fragBufB <= fragBufC;
            validFragA <= validFragB;
            validFragB <= validFragC;
            validFragC <= False;
        end else begin
            let fw <- xlw.line.get();
            let f = fw.a;
            indication.callbackFrag(pack(f.pos.x),pack(f.pos.y),pack(f.pos.z),pack(f.intensity));
            fragBufA <= fw.b;
            fragBufB <= fw.c;
            fragBufC <= fw.d;
            validFragA <= True; // first two in wave always valid
            validFragB <= fw.vc;
            validFragC <= fw.vd;
        end
    endrule

    interface TransformReq setTransform;
        method Action set(Bit#(16) posx, Bit#(16) posy, Bit#(16) posz,
	                      Bit#(16) mxx , Bit#(16) mxy , Bit#(16) mxz ,
	                      Bit#(16) myx , Bit#(16) myy , Bit#(16) myz ,
	                      Bit#(16) mzx , Bit#(16) mzy , Bit#(16) mzz );
	        //indication.callbackFrag(truncate(posx), truncate(posy), truncate(posz), 0);
            perspective.setTransform.put(t);
        endmethod
    endinterface

    interface TriangleReq inputTriangles;
        method Action enq(Bit#(16) ax, Bit#(16) ay, Bit#(16) az,
                          Bit#(16) bx, Bit#(16) by, Bit#(16) bz,
                          Bit#(16) cx, Bit#(16) cy, Bit#(16) cz,
                          Bool valid);
        Triangle t;
        t.a = Vec3{x:unpack(ax), y:unpack(ay), z:unpack(az)};
        t.b = Vec3{x:unpack(bx), y:unpack(by), z:unpack(bz)};
        t.c = Vec3{x:unpack(cx), y:unpack(cy), z:unpack(cz)};
        t.valid = valid;
        fifoTriIn.enq(t);
        endmethod
    endinterface
endmodule
