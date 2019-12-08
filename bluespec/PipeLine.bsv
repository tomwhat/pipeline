import FixedPoint::*;
import GetPut::*;
import FIFO::*;
import ClientServer::*;

import IfcPipeLine::*;
import PipeLineTypes::*;
import TransformAndDivide::*;
import XiaoLinWu::*;

interface PipeLine;
    interface TransformReq setTransform;
    interface TriangleReq inputTriangles;
    interface StopReq stopRunning;
endinterface

module mkPipeLine#(PipeLineIndication indication)(PipeLine);
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
            transf.doTransform.request.put(bufferA);
            bufferA <= bufferB;
            validA <= validB;
            validB <= False;
            //$display("HW: in_to_tr -", fshow(bufferA.x), fshow(bufferA.y), fshow(bufferA.z));
        end else begin
            let t = fifoTriIn.first();
            fifoTriIn.deq();
            transf.doTransform.request.put(t.a);
            bufferA <= t.b;
            bufferB <= t.c;
            validA <= True;
            validB <= True;
            //$display("HW: in_to_tr - new triangle -", fshow(t.a.x), fshow(t.a.y), fshow(t.a.z));
        end
    endrule

    // Some state for tr_to_tr
    Reg#(FragPos) aFragPos <- mkRegU;
    Reg#(Bool) validAFragPos <- mkReg(False);
    Reg#(FragPos) lastFragPos <- mkRegU;
    // If we want to draw multiple objects, this should be reset by some method
    Reg#(Bit#(3)) triIdx <- mkReg(1);
    // Takes transformed vertices (now as FragPos) and feeds them as lines
    // to the XiaoLinWu algorithm
    rule tr_to_xl;
        let fragPos <- transf.doTransform.response.get();
        if (triIdx[0] == 1) begin
        	if (validAFragPos) begin
        		if (lastFragPos.x != 0 && lastFragPos.y != 0 && aFragPos.x != 0 && aFragPos.y != 0)
        			xlw.request.put(tuple2(lastFragPos, aFragPos));
        	end
        	validAFragPos <= True;
        	aFragPos <= fragPos;
        end else begin
        	if (lastFragPos.x != 0 && lastFragPos.y != 0 && fragPos.x != 0 && fragPos.y != 0)
        		xlw.request.put(tuple2(lastFragPos, fragPos));
        end
        triIdx <= {triIdx[1], triIdx[0], triIdx[2]};
        lastFragPos <= fragPos;
    endrule
    
    // Runs if there is no new triangle vertices available, but we still
    // need to draw the third edge of the last triangle
    rule tr_to_xl_edge (validAFragPos && (triIdx[0] == 1));
    	xlw.request.put(tuple2(lastFragPos, aFragPos));
    	validAFragPos <= False;
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
            //$display("Frag: x:%d, y:%d", f.pos.x, f.pos.y);
        end else begin
            let fw <- xlw.response.get();
            let f = fw.a;
            indication.callbackFrag(pack(f.pos.x),pack(f.pos.y),pack(f.pos.z),pack(f.intensity));
            fragBufA <= fw.c;
            fragBufB <= fw.b;
            fragBufC <= fw.d;
            validFragA <= fw.vc; // first two in wave always valid
            validFragB <= fw.vb;
            validFragC <= fw.vd;
            //$display("HW: xlw_to_host - new FragWave");
            //$display("Frag: x:%d, y:%d", f.pos.x, f.pos.y);
        end
    endrule

    interface TransformReq setTransform;
        method Action set(Bit#(16) posx, Bit#(16) posy, Bit#(16) posz,
	                      Bit#(16) mxx , Bit#(16) mxy , Bit#(16) mxz ,
	                      Bit#(16) myx , Bit#(16) myy , Bit#(16) myz ,
	                      Bit#(16) mzx , Bit#(16) mzy , Bit#(16) mzz );
	        //indication.callbackFrag(truncate(posx), truncate(posy), truncate(posz), 0);
	        Mat3 m = Mat3 {
	        xx: unpack(mxx), xy: unpack(mxy), xz: unpack(mxz),
	        yx: unpack(myx), yy: unpack(myy), yz: unpack(myz),
	        zx: unpack(mzx), zy: unpack(mzy), zz: unpack(mzz)
	        };
	        Vec3 p = Vec3 {x:unpack(posx), y:unpack(posy), z:unpack(posz)};
	        Transform t = Transform {m: m, pos: p};
            transf.setTransform.put(t);
            //$display("HW: setting transform");
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
		    //$display("HW: recieved new triangle");
        endmethod
    endinterface
    
    interface StopReq stopRunning;
    	method Action stop;
    		$display("Stopping hardware");
    		$finish;
    	endmethod
    endinterface
endmodule
