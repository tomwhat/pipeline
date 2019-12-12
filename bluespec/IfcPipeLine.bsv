// import PipeLineTypes::*;

// TB: I hardcoded the bit width for connectal, otherwise it confuses the parser

interface TransformReq;
    method Action set(
	Bit#(16) posx, Bit#(16) posy, Bit#(16) posz,
	Bit#(16) mxx , Bit#(16) mxy , Bit#(16) mxz ,
	Bit#(16) myx , Bit#(16) myy , Bit#(16) myz ,
	Bit#(16) mzx , Bit#(16) mzy , Bit#(16) mzz );
endinterface

interface TriangleReq;
    method Action enq(
	Bit#(16) ax, Bit#(16) ay, Bit#(16) az,
	Bit#(16) bx, Bit#(16) by, Bit#(16) bz,
	Bit#(16) cx, Bit#(16) cy, Bit#(16) cz,
	Bool valid);
endinterface

interface StopReq;
	method Action stop;
endinterface

interface KillReq;
	method Action kill;
endinterface

// HW to Sw
interface PipeLineIndication;
    method Action callbackFrag(
	Bit#(10) fposx,
	Bit#(10) fposy,
	Bit#(16) fposz,
	Bit#(4) fintensity);
	
	method Action confirmStop(Bit#(16) x);
endinterface
