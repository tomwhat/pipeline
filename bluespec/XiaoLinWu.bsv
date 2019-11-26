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
	FIFO#(Tuple2#(FragPos, FragPos)) dummy <- mkFIFO;

	interface Put request;
		method Action put(Tuple2#(FragPos, FragPos) tup);
			$display("xlw put");
			dummy.enq(tup);
		endmethod
	endinterface
	
	interface Get response;
		method ActionValue#(FragWave) get();
			dummy.deq();
			Frag a = Frag{pos: tpl_1(dummy.first), intensity: maxBound};
			Frag b = Frag{pos: tpl_2(dummy.first), intensity: maxBound};
			return FragWave{a:a, va:True, b:b, vb:True, c:?, vc:False, d:?, vd:False};
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
        if (thisx0 > thisx1) begin
            thisBusy = False;
            $display("HW: XiaoLinWu: line finished, not busy");
        end else begin
        	outFIFO.enq(outwave);
        	$display("HW: XiaoLinWu: outwave enqueued");
        	$display("x: %d, y: %d", x0, y0);
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

			Bit#(10) ixdiff = extend(pack(tx1)) - extend(pack(tx0));
			Bit#(10) iydiff = extend(pack(ty1)) - extend(pack(ty0));
			Bit#(8) xdiffi = {'0, ixdiff[9:5]};
			Bit#(8) xdifff = {ixdiff[4:0], '0};
			Bit#(8) ydiffi = {'0, iydiff[9:5]};
			Bit#(8) ydifff = {iydiff[4:0], '0};
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
			x0 <= thisx0;
			x1 <= thisx1;
			y0 <= thisy0;
			y1 <= thisy1;
			// Offset or Bit#(14) <= Fractional.i or Bit#(8)
			Fractional fractMaxVal = Fractional{i:{'0, pack(maxval)[13:8]}, f:pack(maxval)[7:0]};
			Fractional fractky = k * fractMaxVal + 0.5;
			Offset thisky = unpack({fractky.i[5:0], fractky.f});
			ky <= thisky;
			kz <= (thisz1 - thisz0) / xdiff;
			oD <= 0;
			$display("HW: XiaoLinWu: line started, outwave enqueued");
			/*
			$display("tx0: %d, ty0: %d, tx1: %d, ty1: %d", tx0, ty0, tx1, ty1);
			$display("ixdiff: %d", ixdiff);
			$write("xdiff: "); fxptWrite(3, xdiff*32); $display(" ");
			$write("ydiff: "); fxptWrite(3, ydiff*32); $display(" ");
			$write("k: "); fxptWrite(3, k); $display(" ");
			$write("fractky: "); fxptWrite(3, fractky); $display(" ");
			$write("fractMaxVal: "); fxptWrite(3, fractMaxVal); $display(" ");
			$display("fractky.i: %b", fractky.i);
			$display("fractky.i[5:0]: %b", fractky.i[5:0]);
			$display("ky: %d", thisky);
			$display("maxval: %d", maxval);
			*/
			outFIFO.enq(outwave);
	    endmethod
	endinterface
	
    interface response = toGet(outFIFO);

endmodule
