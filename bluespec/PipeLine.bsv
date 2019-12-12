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
    interface KillReq killProgram;
endinterface

module mkPipeLine#(PipeLineIndication indication)(PipeLine);
    FIFO#(Triangle) fifoTriIn <- mkFIFO;
    FIFO#(Frag) fifoFragOut <- mkFIFO;
    SettableTransformAndDivide transf <- mkTransformDivide;
    XiaoLinWu xlw <- mkXiaoLinWu;
    
    Reg#(Bool) pleaseStop <- mkReg(False);
    Reg#(UInt#(16)) numTriangles <- mkReg(0);
    Reg#(UInt#(16)) numTrianglesFinished <- mkReg(0);
    Reg#(UInt#(32)) numCycles <- mkReg(0);
    Reg#(Bool) countingCycles <- mkReg(False);
    Reg#(UInt#(32)) numFragments <- mkReg(0);
    
    rule count_cycle (countingCycles);
    	numCycles <= numCycles + 1;
    endrule
    
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
            //$display("HW: in_to_tr - new triangle: ");
            //fxptWrite(3,t.a.x); $write(" "); fxptWrite(3,t.a.y); $write(" "); fxptWrite(3,t.a.z); $write("\n");
            //fxptWrite(3,t.b.x); $write(" "); fxptWrite(3,t.b.y); $write(" "); fxptWrite(3,t.b.z); $write("\n");
            //fxptWrite(3,t.c.x); $write(" "); fxptWrite(3,t.c.y); $write(" "); fxptWrite(3,t.c.z); $write("\n");
        end
    endrule
    
    // Some state for tr_to_tr
    Reg#(FragPos) lastFragPos <- mkRegU;
    Reg#(FragPos) prevFragPos <- mkRegU;
    Reg#(Bool) prevValid <- mkReg(False);
    Reg#(Bit#(3)) triIdx <- mkReg(1);
    rule tr_to_xl;
    	let fragPos <- transf.doTransform.response.get();
    	if (triIdx[0] == 1) begin
    		if (prevValid) begin
    			xlw.request.put(tuple2(lastFragPos, prevFragPos));
    			numTrianglesFinished <= numTrianglesFinished + 1;
    		end
    		prevFragPos <= fragPos;
    		prevValid <= True;
    	end else begin
    		xlw.request.put(tuple2(lastFragPos, fragPos));
    	end
    	triIdx <= {triIdx[1], triIdx[0], triIdx[2]};
    	lastFragPos <= fragPos;
    endrule
    
    rule tr_to_xl_edge (prevValid && (triIdx[0] == 1));
    	xlw.request.put(tuple2(lastFragPos, prevFragPos));
    	numTrianglesFinished <= numTrianglesFinished + 1;
    	prevValid <= False;
    endrule
    
    /*
    rule just_points;
    	let fragPos <- transf.doTransform.response.get();
    	FragPos ofp = FragPos{x:fragPos.x+1,y:fragPos.y+1,z:fragPos.z};
    	xlw.request.put(tuple2(fragPos, ofp));
    	//$display("Point at %d, %d", fragPos.x, fragPos.y);
    	if (fragPos.x == 0)
    		$display("no good's afoot");
    endrule
    */
    
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
            let fw <- xlw.response.get();
            let f = fw.a;
            indication.callbackFrag(pack(f.pos.x),pack(f.pos.y),pack(f.pos.z),pack(f.intensity));
            fragBufA <= fw.b;
            fragBufB <= fw.c;
            fragBufC <= fw.d;
            validFragA <= fw.vb; // first two in wave always valid
            validFragB <= fw.vc;
            validFragC <= fw.vd;
        end
        numFragments <= numFragments + 1;
    endrule

    Reg#(Bool) stopped <- mkReg(False);
    rule do_exit (!stopped && pleaseStop && (numTrianglesFinished >= numTriangles));
    	indication.confirmStop(0);
    	$display("HW: ready to stop");
    	$display("Num cycles: %d", numCycles);
    	$display("Num triangles: %d", numTriangles);
    	$display("Num fragments: %d", numFragments);
    	stopped <= True;
    endrule

    interface TransformReq setTransform;
        method Action set(Bit#(16) posx, Bit#(16) posy, Bit#(16) posz,
	                      Bit#(16) mxx , Bit#(16) mxy , Bit#(16) mxz ,
	                      Bit#(16) myx , Bit#(16) myy , Bit#(16) myz ,
	                      Bit#(16) mzx , Bit#(16) mzy , Bit#(16) mzz );
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
		    countingCycles <= True;
		    numTriangles <= numTriangles + 1;
		    //$display("HW: recieved new triangle");
        endmethod
    endinterface
    
    interface StopReq stopRunning;
    	method Action stop;
    		$display("HW: Will stop when finished");
    		pleaseStop <= True;
    	endmethod
    endinterface
    
    interface KillReq killProgram;
    	method Action kill;
    		$display("HW: $finish");
    		$finish;
    	endmethod
    endinterface
endmodule
