import PipeLineTypes::*;
import FIFO::*;
import FixedPoint::*;


interface XiaoLinWu;
    method Bool busy;
    method ActionValue#(Bool) startLine(FragPos a, FragPos b);
    method ActionValue#(Frag) getFrag();
endinterface


module mkXiaoLinWu(XiaoLinWu);

    FIFO#(Frag) outFIFO <- mkFIFO;

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
    Reg#(Offset) D  <- mkRegU;

    method Bool busy = busy;
    
    // TB: I think this should be a function as you call it here (methods are not callable from within the module itself)
    function Tuple2#(FragPos, FragPos) descramble(FragPos a, FragPos b);
        // TB: the swaps register is never written anywhere, so swap always contains an undefined value
        PixCoord tx0 = (swaps) ? a.y : a.x;
        PixCoord ty0 = (swaps) ? a.x : a.y;
        PixCoord tx1 = (swaps) ? b.y : b.x;
        PixCoord ty1 = (swaps) ? b.x : b.y;
        PixCoord oy1 = (yflip) ? ty0 : ty1;
        PixCoord oy0 = (yflip) ? ty1 : ty0;
        PixCoord ox1 = (xflip) ? tx0 : tx1;
        PixCoord ox0 = (xflip) ? tx1 : tx0;
        // TB: See next rule comment about syntax for struct construction
        return {{ox0, oy0, a.z}, {ox1, oy1, b.z}};
    endfunction

    // This is one of my more expensive blocks...
    // pretty dang sure will have to be multiple
    // cycles, just not sure how many yet
    // TB: I would not worry to much about it for now
    // I wonder what is going to be the critical path. Either 
    //  1.0/(ydiff/xdiff) * maxVal + 0.5
    //  or  (z1 - z0) / (x1.val - x0.val) I would say
    method Action startLine(FragPos a, FragPos b) if (!busy);
        busy <= True;
        let xf = (a.x > b.x);
        xflip <= xf;
        let yf = (a.y > b.y);
        yflip <= yf;
        
        let tx0 = (xf) ? b.x : a.x;
        let tx1 = (xf) ? a.x : b.x;
        let ty0 = (yf) ? b.y : a.y;
        let ty1 = (yf) ? a.y : b.y;

        Fractional xdiff = fromInt(b.x - a.x);
        Fractional ydiff = fromInt(b.y - a.y);
        Fractional k = ydiff / xdiff;

        // TB: There is a register named swaps that is shadowed here, the register is actually never written
        // I think you may want to write it here? swaps <= k > 1.0;
        let swaps = (k > 1.0);
        let x0 = (swaps) ? ty0 : tx0;
        let x1 = (swaps) ? ty1 : tx1;
        let y0 = (swaps) ? tx0 : ty0;
        let y1 = (swaps) ? tx1 : ty1;
        // TB: ? missing in the next line?
        k = (swaps) 1.0 / k : k;

        // Does this work? Is there a better way?
        // TB: unpack(-1) does the job, or even cleaner maxBound/minBound two functions of the Bound typecass.
	// unpack(-1)
        Offset maxval = unpack(pack(signExtend(1b1)));

        // TB to myself: I am not familiar enough with FixedPoint package, how are floating literals defined
	// TB: zero extend or truncate is more explicit.
        ky <= unpack(pack((k * maxval + 0.5).i));

        z0 <= a.z;
        z1 <= b.z;

        // TB: z1 - z0 are the old z1 and z0 right?  Not the one you just wrote
        // and that are going to be visible only next cycle.
        kz <= (z1 - z0) / (x1.val - x0.val);

        D <= 0;

        // TB: I do not believe that this syntax is BSV compatible
        // I think you are looking for "FragPos { x: thisx0 , y: thisy0, z: z0}"
        // Same remark about z0,z1 that are the old value
        FragPos l = {x0, y0, z0};
        FragPos r = {x1, y1, z1};

        // Perhaps descrambling and queueing could
        // be done separately in a rule
        let outs = descramble(l, r);
        // TB: You cannot enqueue twice in the same fifo in one rule
        outFIFO.enq({tpl_1(outs), unpack(pack(signExtend(1b1)))});
        outFIFO.enq({tpl_2(outs), unpack(pack(signExtend(1b1)))});
    endmethod

    rule tick(busy);
        let thisBusy = True;

        let thisx0 = x0 + 1;
        let thisx1 = x1 - 1;
        let thisz0 = z0 + kz;
        let thisz1 = z1 - kz;
        x0 <= thisx0;
        x1 <= thisx1;
        z0 <= thisz0;
        z1 <= thisz1;
        if (thisx0 >= thisx1) begin
            // TB: That thisBusy does not seem to be used?
            // it looks equivalent to just busy <= False;
            thisBusy = False;
            busy <= thisBusy;
        end
	// TB maybe this should not be executed? Algorithm? else construct may be the solution
        let thisD = D + ky;
        D <= thisD;
        let thisy0 = y0;
        let thisy1 = y1;
        if (thisD < D || (thisD == prev && ky != 0)) begin
            thisy0 = thisy0 + 1;
            thisy1 = thisy1 - 1;
        end
        y0 <= thisy0;
        y1 <= thisy1;

        // TB: N_BITS is a numeric type, so you will need valueOf to make an
        // Integer out of it, and then fromInteger to make an Intensity out of
        // it : fromInteger(valueOf(N_BITS))
        Intensity intensity = thisD >> (N_BITS - M_BITS);
        Intensity invertedI = ~intensity;

        // TB: See comment in previous rule about the syntax for record
        FragPos l = {thisx0, thisy0, z0};
        FragPos r = {thisx1, thisy1, z1};
        FragPos u = {thisx0, thisy0+1, z0};
        FragPos d = {thisx1, thisy1-1, z1};

        // TB: Oops cpp syntax left there :)
        auto outp = descramble(l, r);
        auto outs = descramble(u, d);

        // Enque batch to be pushed through the
        // pipeline one at a time, or make four
        // streams?
        // TB: Either 4 streams, or 1 stream of Tuple4#(Frag) or of a custom struct carrying the 4frags
        outFIFO.enq({tpl_1(outp), invertedI});
        outFIFO.enq({tpl_2(outp), invertedI});
        outFIFO.enq({tpl_1(outs), intensity});
        outFIFO.enq({tpl_2(outs), intensity});
        
    endrule

    method ActionValue#(Frag) getFrag();
        let f <- outFIFO.first();
        outFIFO.deq();
        return f;
    endmethod

endmodule
