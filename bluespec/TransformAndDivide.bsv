import FixedPoint::*;
import FIFO::*;
import PipeLineTypes::*;
import ClientServer::*;
import GetPut::*;
import Divide::*;

typedef Server#(
    Vec3,
    FragPos
) TransformAndDivide;

interface SettableTransformAndDivide;
    interface Put#(Transform) setTransform;
    interface TransformAndDivide doTransform;
endinterface

/*
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
*/

module mkTransformDivide(SettableTransformAndDivide);
    Reg#(Transform) transform <- mkRegU;

	Reg#(Bool) validTransform <- mkReg(False);

    FIFO#(Vec3) inFIFO <- mkFIFO;
    FIFO#(Vec3) a_x <- mkFIFO;
    FIFO#(Vec3) a_y <- mkFIFO;
    FIFO#(Vec3) a_z <- mkFIFO;
    FIFO#(Tuple2#(Fractional, Fractional)) b_x <- mkFIFO;
    FIFO#(Tuple2#(Fractional, Fractional)) b_y <- mkFIFO;
    FIFO#(Tuple2#(Fractional, Fractional)) b_z <- mkFIFO;
    FIFO#(Fractional) c_x <- mkFIFO;
    FIFO#(Fractional) c_y <- mkFIFO;
    FIFO#(Fractional) c_z <- mkFIFO;
    FIFO#(Vec3) midFIFO <- mkFIFO;
    FIFO#(FragPos) outFIFO <- mkFIFO;
    
    Server#(Tuple2#(Int#(32),Int#(16)), Tuple2#(Int#(16),Int#(16))) d1 <- mkSignedDivider(1);
    Server#(Tuple2#(Int#(32),Int#(16)), Tuple2#(Int#(16),Int#(16))) d2 <- mkSignedDivider(1);
    Server#(Tuple2#(Int#(32),Int#(16)), Tuple2#(Int#(16),Int#(16))) d3 <- mkSignedDivider(1);
    
    // This has more combinational logic than anything else so far
    // in the pipeline
    // Without going into making multi-cycle multipliers,
    // I could at least do three parallel multiplications
    // and additions per cycle, then three parallel divisions
    // in the fourth cycle.
    function Vec3 transformAndDivide(Vec3 v);
    	/*
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
        */
        // Divide by zero? I'm kind of stumped by this because
        // a vertex could very well have a z-value of zero and still
        // be a part of a line that makes it to the screen.
        // Maybe clipping should be done before perspective divide?
        // Just one more thing to consider
        //x = -x / z;
        //y = -y / z;
        //z = -1 / z;
        return Vec3{x:v.y, y:v.y, z:v.z};
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
    rule in_to_a if (validTransform);
    	let v = inFIFO.first();
    	let xx = transform.m.xx * v.x;
    	let xy = transform.m.xy * v.y;
    	let xz = transform.m.xz * v.z;
    	let yx = transform.m.yx * v.x;
    	let yy = transform.m.yy * v.y;
    	let yz = transform.m.yz * v.z;
    	let zx = transform.m.zx * v.x;
    	let zy = transform.m.zy * v.y;
    	let zz = transform.m.zz * v.z;
    	a_x.enq(Vec3{x:xx, y:xy, z:xz});
    	a_y.enq(Vec3{x:yx, y:yy, z:yz});
    	a_z.enq(Vec3{x:zx, y:zy, z:zz});
    	
        inFIFO.deq();
    endrule
    
    rule a_to_b;
    	let x = a_x.first();
    	let y = a_y.first();
    	let z = a_z.first();
    	let x_1 = x.x + x.y;
    	let x_2 = x.z + transform.pos.x;
    	let y_1 = y.x + y.y;
    	let y_2 = y.z + transform.pos.y;
    	let z_1 = z.x + z.y;
    	let z_2 = z.z + transform.pos.z;
    	b_x.enq(tuple2(x_1, x_2));
    	b_y.enq(tuple2(y_1, y_2));
    	b_z.enq(tuple2(z_1, z_2));
    	a_x.deq();
    	a_y.deq();
    	a_z.deq();
    endrule

	rule b_to_c;
		let x = b_x.first();
		let y = b_y.first();
		let z = b_z.first();
		let xc = tpl_1(x) + tpl_2(x);
		let yc = tpl_1(y) + tpl_2(y);
		let zc = tpl_1(z) + tpl_2(z);
		c_x.enq(xc);
		c_y.enq(yc);
		c_z.enq(zc);
		b_x.deq();
		b_y.deq();
		b_z.deq();
	endrule
	
	rule c_to_div;
		let x = c_x.first();
		let y = c_y.first();
		let z = c_z.first();
		Int#(24) x_small = unpack({x.i,x.f,0});
		Int#(24) y_small = unpack({y.i,y.f,0});
		Int#(16) z_small = unpack({z.i,z.f});
		Int#(32) x_big = extend(x_small);
		Int#(32) y_big = extend(y_small);
		Int#(32) one_big = 1 << 16;
		d1.request.put(tuple2(-x_big,z_small));
		d2.request.put(tuple2(-y_big,z_small));
		d3.request.put(tuple2(-one_big,z_small));
		//$write("in: "); fxptWrite(3, x); $write(", "); fxptWrite(3, y); $write(", "); fxptWrite(3, z); $display(" ");
		//$display("x_big: %b \ny_big: %b \nzsmall: %b",x_big,y_big,z_small);
		c_x.deq();
		c_y.deq();
		c_z.deq();
	endrule
	
	rule div_to_mid;
		let x <- d1.response.get();
		let y <- d2.response.get();
		let z <- d3.response.get();
		//$display("xback: %b \nyback: %b \nzback: %b",x,y,z);
		let xp = pack(tpl_1(x));
		let yp = pack(tpl_1(y));
		let zp = pack(tpl_1(z));
		let xf = Fractional{i:xp[15:8],f:xp[7:0]};
		let yf = Fractional{i:yp[15:8],f:yp[7:0]};
		let zf = Fractional{i:zp[15:8],f:zp[7:0]};
		//$write("out: "); fxptWrite(3, xf); $write(", "); fxptWrite(3, yf); $write(", "); fxptWrite(3, zf); $display(" ");
		midFIFO.enq(Vec3{x:xf,y:yf,z:zf});
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
