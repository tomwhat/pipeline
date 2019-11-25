import PipeLineTypes::*;
import FIFO::*;
import FixedPoint::*;
import ClientServer::*;
import GetPut::*;

typedef struct {
    Frag a;
    Bool va;
    Frag b;
    Bool vb;
    Frag c;
    Bool vc;
    Frag d;
    Bool vd;
} FragWave deriving(Bits);

typedef Server#(
    Tuple2#(FragPos, FragPos),
    FragWave
) XiaoLinWu;


module mkFakeXiaoLinWu(XiaoLinWu);
	FIFO#(Bool) dummy <- mkFIFO;

	interface Put request;
		method Action put(Tuple2#(FragPos, FragPos) tup);
			$display("xlw put");
			dummy.enq(?);
		endmethod
	endinterface
	
	interface Get response;
		method ActionValue#(FragWave) get();
			dummy.deq();
			FragPos fp = FragPos{x:100, y:100, z:fromInteger(0.5)};
			Frag f = Frag{pos: fp, intensity: maxBound};
			return FragWave{a:f, va:True, b:?, vb:False, c:?, vc:False, d:?, vd:False};
		endmethod
	endinterface
endmodule

module mkXiaoLinWu(XiaoLinWu);

    FIFO#(FragWave) outFIFO <- mkFIFO;

    Reg#(Bool) busy <- mkRegU;
    Reg#(Bool) xflip <- mkRegU;
    Reg#(Bool) yflip <- mkRegU;
    Reg#(Bool) swaps <- mkRegU;
    Reg#(PixCoord) x0 <- mkRegU;
    Reg#(PixCoord) y0 <- mkRegU;
    Reg#(PixCoord) x1 <- mkRegU;
    Reg#(PixCoord) y1 <- mkRegU;
    Reg#(Fractional) z0 <- mkRegU;
    Reg#(Fractional) z1 <- mkRegU;
    Reg#(Fractional) kz <- mkRegU;
    Reg#(Offset) ky <- mkRegU;
    Reg#(Offset) oD  <- mkRegU;
    
    function Tuple2#(FragPos, FragPos) descramble(FragPos a, FragPos b);
        PixCoord tx0 = (swaps) ? a.y : a.x;
        PixCoord ty0 = (swaps) ? a.x : a.y;
        PixCoord tx1 = (swaps) ? b.y : b.x;
        PixCoord ty1 = (swaps) ? b.x : b.y;
        PixCoord oy1 = (yflip) ? ty0 : ty1;
        PixCoord oy0 = (yflip) ? ty1 : ty0;
        PixCoord ox1 = (xflip) ? tx0 : tx1;
        PixCoord ox0 = (xflip) ? tx1 : tx0;
        return tuple2(FragPos{x:ox0, y:oy0, z:a.z},
                      FragPos{x:ox1, y:oy1, z:b.z});
    endfunction

    rule tick(busy);
        let thisBusy = True;

        let thisx0 = x0 + 1;
        let thisx1 = x1 - 1;
        let thisz0 = z0 + kz;
        let thisz1 = z1 - kz;
        let thisD = oD + ky;
         
        let thisy0 = y0;
        let thisy1 = y1;
        if (thisD < oD || (thisD == oD && ky != 0)) begin
            thisy0 = thisy0 + 1;
            thisy1 = thisy1 - 1;
        end
        // TB: N_BITS is a numeric type, so you will need valueOf to make an
        // Integer out of it, and then fromInteger to make an Intensity out of
        // it : fromInteger(valueOf(N_BITS))
        Intensity intensity = truncate(thisD >> (valueOf(N_BITS) - valueOf(M_BITS)));
        Intensity invertedI = ~intensity;

        // TB: See comment in previous rule about the syntax for record
        FragPos l = FragPos{x:thisx0, y:thisy0, z:z0};
        FragPos r = FragPos{x:thisx1, y:thisy1, z:z1};
        FragPos u = FragPos{x:thisx0, y:thisy0+1, z:z0};
        FragPos d = FragPos{x:thisx1, y:thisy1-1, z:z1};

        // TB: Oops cpp syntax left there :)
        let outp = descramble(l, r);
        let outs = descramble(u, d);

        // Enque batch to be pushed through the
        // pipeline one at a time, or make four
        // streams?
        // TB: Either 4 streams, or 1 stream of Tuple4#(Frag) or of a custom struct carrying the 4frags
        FragWave outwave;
        outwave.a = Frag{pos: tpl_1(outp), intensity: invertedI};
        outwave.va = True;
        outwave.b = Frag{pos: tpl_2(outp), intensity: invertedI};
        outwave.vb = True;
        outwave.c = Frag{pos: tpl_1(outs), intensity: intensity};
        outwave.vc = True;
        outwave.d = Frag{pos: tpl_2(outs), intensity: intensity};
        outwave.vd = True;
        
        //
        //
        // State change
        if (thisx0 >= thisx1) begin
            thisBusy = False;
        end else begin
        	outFIFO.enq(outwave);
      	end  
        x0 <= thisx0;
        x1 <= thisx1;
        z0 <= thisz0;
        z1 <= thisz1;
        busy <= thisBusy;
        oD <= thisD;
        y0 <= thisy0;
        y1 <= thisy1;
    endrule

	interface Put request;
	    method Action put(Tuple2#(FragPos, FragPos) tup) if(!busy);
	    	let a = tpl_1(tup);
	    	let b = tpl_2(tup);
			let xf = (a.x > b.x);
			let yf = (a.y > b.y);
			
			let tx0 = (xf) ? b.x : a.x;
			let tx1 = (xf) ? a.x : b.x;
			let ty0 = (yf) ? b.y : a.y;
			let ty1 = (yf) ? a.y : b.y;

			Bit#(10) ixdiff = pack(b.x - a.x);
			Bit#(10) iydiff = pack(b.y - a.y);
			Bit#(8) xdiffi = ixdiff[9:2];
			Bit#(8) xdifff = {ixdiff[1:0], '0};
			Bit#(8) ydiffi = iydiff[9:2];
			Bit#(8) ydifff = {iydiff[1:0], '0};
			Fractional xdiff = Fractional{i:xdiffi, f:xdifff};
			Fractional ydiff = Fractional{i:ydiffi, f:ydifff};
			Fractional k = ydiff / xdiff;
			Fractional inverseK = xdiff / ydiff;

			let thisSwaps = (k > 1.0);
			let thisx0 = (thisSwaps) ? ty0 : tx0;
			let thisx1 = (thisSwaps) ? ty1 : tx1;
			let thisy0 = (thisSwaps) ? tx0 : ty0;
			let thisy1 = (thisSwaps) ? tx1 : ty1;

			k = (thisSwaps) ? inverseK : k;

			// Alternative: unpack(-1);
			Offset maxval = maxBound;

			let thisz0 = a.z;
			let thisz1 = b.z;

			FragPos l = FragPos{x:thisx0, y:thisy0, z:thisz0};
			FragPos r = FragPos{x:thisx1, y:thisy1, z:thisz1};

			// Perhaps descrambling and queueing could
			// be done separately in a rule
			let outs = descramble(l, r);

			FragWave outwave;
			outwave.a = Frag{pos: tpl_1(outs), intensity: maxBound};
			outwave.va = True;
			outwave.b = Frag{pos: tpl_2(outs), intensity: maxBound};
			outwave.vb = True;
			outwave.c = ?;
			outwave.vc = False;
			outwave.d = ?;
			outwave.vd = False;
			//
			//
			// State change
			busy <= True;
			xflip <= xf;
			yflip <= yf;
			swaps <= thisSwaps;
			z0 <= thisz0;
			z1 <= thisz1;
			// Offset or Bit#(14) <= Fractional.i or Bit#(8)
			Fractional fractMaxVal = Fractional{i:pack(maxval)[9:2], f:{pack(maxval)[1:0],'0}};
			ky <= extend(unpack((k * fractMaxVal + 0.5).i));
			kz <= (thisz1 - thisz0) / xdiff;
			oD <= 0;
			outFIFO.enq(outwave);
	    endmethod
	endinterface
	
    interface response = toGet(outFIFO);

endmodule
