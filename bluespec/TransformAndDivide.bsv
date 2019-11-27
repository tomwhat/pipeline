import FixedPoint::*;
import FIFO::*;
import PipeLineTypes::*;
import ClientServer::*;
import GetPut::*;

typedef Server#(
    Vec3,
    FragPos
) TransformAndDivide;

interface SettableTransformAndDivide;
    interface Put#(Transform) setTransform;
    interface TransformAndDivide doTransform;
endinterface


module mkFakeTransformDivide(SettableTransformAndDivide);
	FIFO#(Bool) dummy <- mkFIFO;
	
	interface Put setTransform;
		method Action put(Transform t);
			$display("Fake: Transform set");
		endmethod
	endinterface
	
	interface TransformAndDivide doTransform;
		interface Put request;
			method Action put(Vec3 v);
				$display("Fake doTransform.request.put");
				dummy.enq(?);
			endmethod
		endinterface
		
		interface Get response;
			method ActionValue#(FragPos) get();
				$display("Fake doTransform.reponse.get");
				dummy.deq();
				return FragPos{x:100, y:100, z:0.5};
			endmethod
		endinterface
	endinterface
endmodule

module mkTransformDivide(SettableTransformAndDivide);
    Reg#(Transform) transform <- mkRegU;

	Reg#(Bool) validTransform <- mkReg(False);

    FIFO#(Vec3) inFIFO <- mkFIFO;
    FIFO#(Vec3) midFIFO <- mkFIFO;
    FIFO#(FragPos) outFIFO <- mkFIFO;
    // This has more combinational logic than anything else so far
    // in the pipeline
    // Without going into making multi-cycle multipliers,
    // I could at least do three parallel multiplications
    // and additions per cycle, then three parallel divisions
    // in the fourth cycle.
    function Vec3 transformAndDivide(Vec3 v);
        Fractional x =   transform.m.xx * v.x
                        +transform.m.xy * v.y
                        +transform.m.xz * v.z
                        +transform.pos.x;
        Fractional y =   transform.m.yx * v.x
                        +transform.m.yy * v.y
                        +transform.m.yz * v.z
                        +transform.pos.y;
        Fractional z =   transform.m.zx * v.x
                        +transform.m.zy * v.y
                        +transform.m.zz * v.z
                        +transform.pos.z;
        // Divide by zero? I'm kind of stumped by this because
        // a vertex could very well have a z-value of zero and still
        // be a part of a line that makes it to the screen.
        // Maybe clipping should be done before perspective divide?
        // Just one more thing
        x = -x / z;
        y = -y / z;
        z = -1 / z;
        return Vec3{x:x, y:y, z:z};
    endfunction

    function FragPos mapToIntegers(Vec3 v);
    	Fractional half;
    	Bit#(16) numpix = fromInteger(valueOf(NUM_PIXELS));
    	Bit#(16) bit_half = numpix>>1;
    	half.i = bit_half[15:8];
    	half.f = bit_half[7:0];
    	Fractional halfx = v.x * half;
    	Fractional halfy = v.y * half;
    	Bit#(16) xi = pack(halfx);
    	Bit#(16) yi = pack(halfy);
    	Bit#(16) ix = bit_half + xi;
    	Bit#(16) iy = bit_half - yi;
    	
    	Bit#(10) bx = truncate(ix);
    	Bit#(10) by = truncate(iy);
        PixCoord x = unpack(bx);
        PixCoord y = unpack(by);
        
        if (ix[15:10] != 0 || iy[15:10] != 0) begin
    		x = 0;
    		y = 0;
    	end
        
        return FragPos{x:x, y:y, z:v.z};
    endfunction

    // Rules
    rule transformRule if (validTransform);
    	let t = transformAndDivide(inFIFO.first);
    	
    	//$write("HW: transformAndDivide before: ");
    	//fxptWrite(3,inFIFO.first.x); $write(" ");
    	//fxptWrite(3,inFIFO.first.y); $display(" ");
    	//$write("HW: transformAndDivide after: ");
    	//fxptWrite(3,t.x); $write(" ");
    	//fxptWrite(3,t.y); $display(" ");
    	
        midFIFO.enq(t);
        inFIFO.deq();
    endrule

    rule discretizeRule;
        outFIFO.enq(mapToIntegers(midFIFO.first));
        midFIFO.deq();
    endrule

    interface Put setTransform;
    	method Action put(Transform t);
    		validTransform <= True;
    		$display("Transform :");
    		$write("row 1: ");
    		fxptWrite(3,t.m.xx); $write(" ");
    		fxptWrite(3,t.m.xy); $write(" ");
    		fxptWrite(3,t.m.xz); $display(" ");
    		$write("row 2: ");
    		fxptWrite(3,t.m.yx); $write(" ");
    		fxptWrite(3,t.m.yy); $write(" ");
    		fxptWrite(3,t.m.yz); $display(" ");
    		$write("row 3: ");
    		fxptWrite(3,t.m.zx); $write(" ");
    		fxptWrite(3,t.m.zy); $write(" ");
    		fxptWrite(3,t.m.zz); $display(" ");
    		$write("pos: ");
    		fxptWrite(3,t.pos.x); $write(" ");
    		fxptWrite(3,t.pos.y); $write(" ");
    		fxptWrite(3,t.pos.z); $display(" ");
    		transform <= t;
    	endmethod
    endinterface
    interface TransformAndDivide doTransform;
        interface request = toPut(inFIFO);
        interface response = toGet(outFIFO);
    endinterface
endmodule
