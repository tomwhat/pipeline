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


module mkTransformDivide(SettableTransformAndDivide);
    Reg#(Transform) transform <- mkRegU;

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
    	Bit#(12) numpix = fromInteger(valueOf(NUM_PIXELS));
    	Bit#(16) bit_half = {numpix>>1,'0};
    	half.i = bit_half[15:8];
    	half.f = bit_half[7:0];
    	Fractional halfx = v.x * half;
    	Fractional halfy = v.y * half;
    	Bit#(12) ix = extend(half.i) + extend(halfx.i);
    	Bit#(12) iy = extend(half.i) - extend(halfy.i);
    	//Bit#(10) tx = truncate(pack(ix));
    	//Bit#(10) ty = truncate(pack(iy));
        PixCoord x = truncate(unpack(ix));
        PixCoord y = truncate(unpack(iy));
        return FragPos{x:x, y:y, z:v.z};
    endfunction

    // Rules
    rule transformRule;
        midFIFO.enq(transformAndDivide(inFIFO.first));
        inFIFO.deq();
    endrule

    rule discretizeRule;
        outFIFO.enq(mapToIntegers(midFIFO.first));
        midFIFO.deq();
    endrule

    interface setTransform = toPut(asReg(transform));
    interface TransformAndDivide doTransform;
        interface request = toPut(inFIFO);
        interface response = toGet(outFIFO);
    endinterface
endmodule
